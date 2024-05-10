import Map "mo:map/Map";
import { nhash; thash; i32hash } "mo:map/Map";
import Option "mo:base/Option";
import Time "mo:base/Time";
import Array "mo:base/Array";
import Result "mo:base/Result";
import Timer "mo:base/Timer";
import G "../Governance/GovernanceTypes";
import PT "../Proposal/ProposalTypes";
import PM "../Proposal/ProposalMappings";
import TT "./TrackerTypes";
import Fuzz "mo:fuzz";
import Nat64 "mo:base/Nat64";
import Nat "mo:base/Nat";
import Debug "mo:base/Debug";
import Int32 "mo:base/Int32";
import GS "../Governance/GovernanceService";
import TR "TrackerRepository";
import Utils "../utils";
import {DAY; HOUR; WEEK} "mo:time-consts";
import LinkedList "mo:linked-list";

//TODO: Implement logging library
module {

    public class TrackerService(repository: TR.TrackerRepository, governanceService : GS.GovernanceService, args : TT.TrackerServiceArgs) {
        let DEFAULT_TICKRATE : Nat = 10; // 10 secs 

        public func initTimer<system>(_tickrate : ?Nat, job : TT.TrackerServiceJob) : async* Result.Result<(), Text> {
            
            let tickrate : Nat = Option.get(_tickrate, DEFAULT_TICKRATE);
            switch(repository.getTimerId()){
                case(?t){ return #err("Timer already created")};
                case(_){};
            };

            let timerId =  ?Timer.recurringTimer<system>(#seconds(tickrate), func() : async () {
                Debug.print("Tick");
                label timerUpdate for ((canisterId, governanceData) in Map.entries(repository.getAllGovernance())) {
                    //if lowestActiveProposalId is null, call pending proposal method and sync up until lowest active proposal id
                     if (Option.isNull(governanceData.lowestActiveProposalId)){
                        Debug.print("lowestActiveProposalId is null, initializing with pending proposals");
                        let #ok(res) = await* governanceService.getPendingProposals(canisterId)
                        else {
                            Debug.print("Error getting active proposals");
                            return;
                        };

                        label fmin for(p in Array.vals(res)){
                            let #ok(id) = Utils.optToRes(p.id)
                            else {
                                continue fmin;
                            };
                            if (Option.isNull(governanceData.lowestActiveProposalId) or Nat64.toNat(id.id) < Option.get(governanceData.lowestActiveProposalId, Nat64.toNat(id.id + 1))){
                                governanceData.lowestActiveProposalId := ?Nat64.toNat(id.id);
                                Debug.print("lowestActiveProposalId set to: " # debug_show(id.id));
                            };
                        };
                    };
                    
                    //if no active proposals at init skip until there are
                    if (Option.isNull(governanceData.lowestActiveProposalId)){
                        Debug.print("no active proposals to initialize");
                        continue timerUpdate;
                    };

                    let res = await* governanceService.listProposalsAfterId(canisterId, governanceData.lowestActiveProposalId, {
                        include_reward_status = [];
                        omit_large_fields = ?true;
                        before_proposal = null;
                        limit = 50;
                        exclude_topic = [];
                        include_all_manage_neuron_proposals = null;
                        include_status = [];
                    });

                    let #ok(newData) = res
                    else {
                        Debug.print("Error getting proposals");
                        continue timerUpdate;
                    };

                    //Cleanup proposals if required, expired proposals are purged on the following tick to ensure they have been notified.
                    //performCleanupStrategy(governanceData);

                    let #ok(newProposals, executedProposals) = repository.processAndUpdateProposals(governanceData, PM.mapGetProposals(newData.proposal_info))
                    else{
                        //TODO: log;
                        Debug.print("Error in processAndUpdateProposals");
                        continue timerUpdate;
                    };

                    //run job callback
                    job(canisterId, newProposals, executedProposals);

                }
            });
            ignore repository.setTimerId(timerId);

            return #ok()
    };

    func performCleanupStrategy(governanceData : TT.GovernanceData) : () {
        switch(args.cleanupStrategy){
            case(#DeleteImmediately){
                for(p in LinkedList.vals(governanceData.proposals)){
                    if(not Map.has(governanceData.activeProposalsSet, nhash, p.id)){
                      // proposal has executed, so it can be removed
                      ignore repository.deleteProposal(governanceData, p.id);
                    }
                }
            };
            case(#DeleteAfterTime(timeframe)){
                let currentTime = Time.now();
                for(p in LinkedList.vals(governanceData.proposals)){
                    var check = false;
                    switch(timeframe){
                        case(#Days(time)){
                            check := currentTime > (time * DAY) + Nat64.toNat(p.timestamp);
                        };
                        case(#Weeks(time)){
                            check := currentTime > (time * WEEK) + Nat64.toNat(p.timestamp);
                        };
                        case(#Hours(time)){
                             check := currentTime > (time * HOUR) + Nat64.toNat(p.timestamp);
                        };
                    };

                    if(check){
                      ignore repository.deleteProposal(governanceData, p.id);
                    }
                }
            };
        }
    };


    func filterValidTopics(topics : [(Int32, Text, ?Text)], topicStrategy : TT.TopicsStrategy) : TT.Topics {
        let topicMap : TT.Topics = Map.new();
        switch(topicStrategy){
            case(#All){
                for(t in Array.vals(topics)){
                    Map.set(topicMap, i32hash, t.0, {name = t.1; description = t.2});
                }
            };
            case(#Include(ids)){
                for(t in Array.vals(topics)){
                    if(Option.isSome(Array.find(ids, func (x : Int32) : Bool {
                        x == t.0
                    }))){
                        Map.set(topicMap, i32hash, t.0, {name = t.1; description = t.2});
                    };
                };
            };
            case(#Exclude(ids)){
                for(t in Array.vals(topics)){
                    if(Option.isNull(Array.find(ids, func (x : Int32) : Bool {
                        x == t.0
                    }))){
                       Map.set(topicMap, i32hash, t.0, {name = t.1; description = t.2});
                    };
                };
            };
        };
        return topicMap;
    };
    
     
     public func addGovernance(governancePrincipal : Text, topicStrategy : TT.TopicsStrategy) : async* Result.Result<(), Text> {
        if(repository.hasGovernance(governancePrincipal)){
            return #err("Canister has already been added");
        };

        let res = await* governanceService.getMetadata(governancePrincipal);
        switch(res){
            case(#ok(metadata)){
                switch(await* governanceService.getValidTopicIds(governancePrincipal)){
                    case(#ok(validTopics)){
                        repository.addGovernance(governancePrincipal, metadata.name, metadata.description, filterValidTopics(validTopics, topicStrategy));
                    };
                    case(#err(err)){ return #err("Error fetching valid topics:" #err); }
                };
                
            };
            case(#err(err)){ return #err("Error fetching metadata:" #err); }
        };
     };

    public func getProposals(canisterId: Text, after : PT.ProposalId, topics : [Int32]) : Result.Result<[PT.ProposalAPI], TT.GetProposalError> {
        repository.getProposals(canisterId, after : PT.ProposalId, topics : [Int32]);
    }

    };
}