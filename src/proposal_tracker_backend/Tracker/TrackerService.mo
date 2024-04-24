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
import GS "../Governance/GovernanceService";
import TR "TrackerRepository";

module {

    // public func init<system>() :  TT.TrackerModel {
    //     ignore Timer.recurringTimer<system>(#seconds(10), func() : async () {
    //         Debug.print("Test")
    //     });
    //     TR.init();
    // };

    public class TrackerService(repository: TR.TrackerRepository, governanceService : GS.GovernanceService) {
        let DEFAULT_TICKRATE : Nat = 10; // 10 secs 
        //let NNS_GOVERNANCE_ID = "rrkah-fqaaa-aaaaa-aaaaq-cai";
        // let repository: TR.TrackerRepository = repo;
        // let governanceService = governance;

        public func initTimer<system>(_tickrate : ?Nat, job : TT.TrackerServiceJob) : async* Result.Result<(), Text> {
            
            let tickrate : Nat = Option.get(_tickrate, DEFAULT_TICKRATE);
            switch(repository.getTimerId()){
                case(?t){ return #err("Timer already created")};
                case(_){};
            };

            let timerId =  ?Timer.recurringTimer<system>(#seconds(tickrate), func() : async () {
                Debug.print("Tick");
                label timerUpdate for ((canisterId, serviceData) in Map.entries(repository.getAllGovernance())) {
                    let res = await* governanceService.listProposals(canisterId,
                    {
                        include_reward_status = [];
                        omit_large_fields = ?true;
                        before_proposal = null;
                        limit = 50;
                        exclude_topic = [];
                        include_all_manage_neuron_proposals = null;
                        include_status = [];
                    });

                    let #ok(data) = res
                    else{
                        Debug.print("Error fetching proposals: " # canisterId);
                        continue timerUpdate;
                        //TODO: mainnet logging
                    };

                    //process delta
                    let newProposals = PM.mapGetProposals(data.proposal_info) |>
                        Array.filter(_, func(proposal: PT.Proposal ) : Bool{
                            for (p in Map.vals(serviceData.proposals)){
                                //filter proposal already in the list which have not changed
                                if(p.id == proposal.id and p.status == proposal.status){
                                    return false;
                                };
                                return true;
                            };
                            return true;
                        });

                    //update service data. 
                    for (proposal in Array.vals(newProposals)){
                        Map.set(serviceData.proposals, nhash, proposal.id, proposal);
                    };

                    //TODO: remove old proposals

                    //run job callback
                    job(serviceData, newProposals);

                }
            });
            ignore repository.setTimerId(timerId);

            return #ok()
     };
     
     public func addService(governancePrincipal : Text, topics : ?[Nat]) : async* Result.Result<(), Text> {
        if(repository.hasGovernance(governancePrincipal)){
            return #err("Service already exists");
        };

        var name = ?"NNS";

        let res = await* governanceService.getSNSMetadata(governancePrincipal);
        switch(res){
            case(#ok(metadata)){name := metadata.name;};
            case(#err(err)){ return #err("Error fetching SNS metadata:" #err); }
        };

        repository.addGovernance(governancePrincipal, name, topics);
     };

    }
}