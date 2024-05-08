import Map "mo:map/Map";
import { nhash; thash } "mo:map/Map";
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
                    //TODO: Cleanup proposals if required

                    let #ok(newProposals, changedProposals) = repository.processAndUpdateProposals(governanceData, PM.mapGetProposals(newData.proposal_info))
                    else{
                        //TODO: log;
                        continue timerUpdate;
                    };

                    //run job callback
                    job(newProposals, changedProposals);

                }
            });
            ignore repository.setTimerId(timerId);

            return #ok()
     };
     
     public func addGovernance(governancePrincipal : Text, topics : ?[Int32]) : async* Result.Result<(), Text> {
        if(repository.hasGovernance(governancePrincipal)){
            return #err("Canister has already been added");
        };

        let res = await* governanceService.getMetadata(governancePrincipal);
        switch(res){
            case(#ok(metadata)){ repository.addGovernance(governancePrincipal, metadata.name, topics);};
            case(#err(err)){ return #err("Error fetching metadata:" #err); }
        };
     };

    public func getProposals(canisterId: Text, after : PT.ProposalId, topics : [Int32]) : Result.Result<[PT.ProposalAPI], TT.GetProposalError> {
        repository.getProposals(canisterId, after : PT.ProposalId, topics : [Int32]);
    }

    };
}