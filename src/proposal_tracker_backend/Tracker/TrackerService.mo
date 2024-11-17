import Map "mo:map/Map";
import { nhash; n64hash; thash; i32hash } "mo:map/Map";
import Option "mo:base/Option";
import Time "mo:base/Time";
import Array "mo:base/Array";
import Result "mo:base/Result";
import Timer "mo:base/Timer";
import G "../External_Canisters/NNS/NNSTypes";
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
import LT "../Log/LogTypes";
import PS "../Proposal/ProposalService";
module {
    public class TrackerService(repository: TR.TrackerRepository, governanceService : GS.GovernanceService, logService : LT.LogService, args : TT.TrackerServiceArgs) {
        let DEFAULT_TICKRATE : Nat = 5 * 60 ; //5 mins 
        let proposalService = PS.ProposalService(governanceService, logService);

        public func update(cb : TT.TrackerServiceJob) : async* () {
            label timerUpdate for ((canisterId, governanceData) in Map.entries(repository.getAllGovernance())) {
                //if lowestActiveProposalId is null, call pending proposal method and sync up until lowest active proposal id
                if (Option.isNull(governanceData.lowestActiveProposalId)){
                    logService.logInfo("lowestActiveProposalId is null, initializing with pending proposals", ?"[TrackerService::update]");
                    let #ok(res) = await* governanceService.getPendingProposals(canisterId)
                    else {
                        logService.logError("Error getting active proposals", ?"[TrackerService::update]");
                        return;
                    };

                     //if no active proposals at init skip until there are
                    if(Array.size(res)==0){
                        logService.logInfo("no active proposals to initialize", ?"[TrackerService::update]");
                        continue timerUpdate;
                    };

                    label fmin for(p in Array.vals(res)){
                        let #ok(id) = Utils.optToRes(p.id)
                        else {
                            continue fmin;
                        };
                        if (Option.isNull(governanceData.lowestActiveProposalId) or id.id < Option.get(governanceData.lowestActiveProposalId, id.id + 1)){
                            governanceData.lowestActiveProposalId := ?id.id;
                            logService.logInfo("lowestActiveProposalId set to: " # Nat64.toText(id.id), ?"[TrackerService::update]");
                        };
                    };
                };

                let res = await* proposalService.listProposalsFromId(canisterId, governanceData.lowestActiveProposalId, {
                    includeRewardStatus = [];
                    omitLargeFields = ?true;
                    excludeTopic = [];
                    includeAllManageNeuronProposals = null;
                    includeStatus = [];
                });

                let #ok(newData) = res
                else {
                    logService.logError("Error getting proposals", ?"[TrackerService::update]");
                    continue timerUpdate;
                };

                //Cleanup proposals if required, expired proposals are purged on the following tick to ensure they have been notified.
                performCleanupStrategy(governanceData);

                let #ok(newProposals, updatedProposals) = repository.processAndUpdateProposals(governanceData, PM.mapGetProposals(newData.proposal_info))
                else{
                    logService.logError("Error getting proposals processAndUpdateProposals", ?"[TrackerService::update]");
                    continue timerUpdate;
                };

                //run job callback
                await* cb(canisterId, newProposals, updatedProposals);
                return;
            };

        };

        public func initTimer<system>(_tickrate : ?Nat, job : TT.TrackerServiceJob) : async* Result.Result<(), Text> {
                
            let tickrate : Nat = Option.get(_tickrate, DEFAULT_TICKRATE);
            switch(repository.getTimerId()){
                case(?t){ return #err("Timer already created")};
                case(_){};
            };

            let timerId =  ?Timer.recurringTimer<system>(#seconds(tickrate), func() : async () {
                await* update(job);
            });
            ignore repository.setTimerId(timerId);

            return #ok()
        };

        public func cancelTimer() : Result.Result<(), Text> {
            let #ok(timerId) = Utils.optToRes(repository.getTimerId())
            else {
                return #err("No Timer to delete");
            };

            Timer.cancelTimer(timerId);
            return #ok();
        };

        public func updateTimer(newTickrate : Nat, job : TT.TrackerServiceJob) : async Result.Result<(), Text> {
            let #ok(_) = cancelTimer()
            else {
                return #err("No Timer to update");
            };

            return await* initTimer(?newTickrate, job);
        };
        
        public func addGovernance(governancePrincipal : Text, topicStrategy : TT.TopicStrategy) : async* Result.Result<(), Text> {
            if(repository.hasGovernance(governancePrincipal)){
                return #ok();
            };

            let res = await* governanceService.getMetadata(governancePrincipal);
            switch(res){
                case(#ok(metadata)){
                    switch(await* governanceService.getGovernanceFunctions(governancePrincipal)){
                        case(#ok(validTopics)){
                            repository.addGovernance(governancePrincipal, metadata.name, metadata.description, filterValidTopics(validTopics, topicStrategy));
                        };
                        case(#err(err)){ return #err("[addGovernance] Error fetching valid topics:" #err); }
                    };
                    
                };
                case(#err(err)){ return #err("[addGovernance] Error fetching metadata:" #err); }
            };
        };

        public func getProposals(canisterId: Text, after : ?PT.ProposalId, topics : TT.TopicStrategy) : Result.Result<TT.GetProposalResponse, TT.GetProposalError> {
            repository.getProposals(canisterId, after, topics, ?100);
        };

        func performCleanupStrategy(governanceData : TT.GovernanceData) : () {
            switch(args.cleanupStrategy){
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
                // case(#DeleteAfterExecution){
                //     for(p in LinkedList.vals(governanceData.proposals)){
                //         if(not Map.has(governanceData.activeProposalsSet, n64hash, p.id)){
                //             // proposal has executed, so it can be removed
                //             ignore repository.deleteProposal(governanceData, p.id);
                //         }
                //     }
                // };
                // case(#DeleteAfterVotingPeriodEnds){
                //     for(p in LinkedList.vals(governanceData.proposals)){
                //         if(p.rewardStatus ==  #Settled){
                //             ignore repository.deleteProposal(governanceData, p.id);
                //         }
                //     }
                // };
            }
        };

        
        func filterValidTopics(topics : [{id : Nat64; name : Text;description : ?Text;}], topicStrategy : TT.TopicStrategy) : TT.Topics {
            let topicMap : TT.Topics = Map.new();
            switch(topicStrategy){
                case(#All){
                    for(t in Array.vals(topics)){
                        Map.set(topicMap, i32hash, Int32.fromNat32(Nat64.toNat32(t.id)), {name = t.name; description = t.description});
                    }
                };
                case(#Include(ids)){
                    for(t in Array.vals(topics)){
                        if(Option.isSome(Array.find(ids, func (x : Int32) : Bool {
                            x == Int32.fromNat32(Nat64.toNat32(t.id))
                        }))){
                            Map.set(topicMap, i32hash, Int32.fromNat32(Nat64.toNat32(t.id)), {name = t.name; description = t.description});
                        };
                    };
                };
                case(#Exclude(ids)){
                    for(t in Array.vals(topics)){
                        if(Option.isNull(Array.find(ids, func (x : Int32) : Bool {
                            x == Int32.fromNat32(Nat64.toNat32(t.id))
                        }))){
                        Map.set(topicMap, i32hash, Int32.fromNat32(Nat64.toNat32(t.id)), {name = t.name; description = t.description});
                        };
                    };
                };
            };
            return topicMap;
        };

    };
}