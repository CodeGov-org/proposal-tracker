import Map "mo:map/Map";
import { nhash; thash } "mo:map/Map";
import Option "mo:base/Option";
import Time "mo:base/Time";
import Array "mo:base/Array";
import Result "mo:base/Result";
import Timer "mo:base/Timer";
import G "./GovernanceTypes";
import PT "./ProposalTypes";
import PM "./ProposalMappings";
import Fuzz "mo:fuzz";
import Nat64 "mo:base/Nat64";
import Nat "mo:base/Nat";

module {

    let DEFAULT_TICKRATE : Nat = 10_000; // 10 secs 
    let NNS_GOVERNANCE_ID = "rrkah-fqaaa-aaaaa-aaaaq-cai";

     public func init() : PT.ProposalService {
        {
            services = Map.new< PT.TextPrincipal, PT.ServiceData>();
            var tickrate = DEFAULT_TICKRATE;
            var timerId = null;
            var jobs = [];
        }
     };

     public func initTimer<system>(self : PT.ProposalService, job : ?PT.ProposalServiceJob) : async* () {

        switch(self.timerId){
          case(?t){ return};
          case(_){};
        };

        switch(job){
          case(?j){ addJob(self, j);};
          case(_){
          };
        };

        self.timerId :=  ?Timer.setTimer<system>(#seconds(self.tickrate), func() : async () {
            for ((canisterId, serviceData) in Map.entries(self.services)) {
                let gc : G.GovernanceCanister = actor (canisterId);
                let res = await gc.list_proposals({
                    include_reward_status = [];
                    omit_large_fields = ?true;
                    before_proposal = null;
                    limit = 50;
                    exclude_topic = [];
                    include_all_manage_neuron_proposals = null;
                    include_status = [];
                });

                //process delta
                let newProposals = PM.mapGetProposals(res.proposal_info) |>
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

                //update service data. TODO: Move to repo
                for (proposal in Array.vals(newProposals)){
                    Map.set(serviceData.proposals, nhash, proposal.id, proposal);
                };

                //run jobs
                for (job in Array.vals(self.jobs)){
                    job.task(serviceData, newProposals);
                };
            }
        });
     };

     public func addJob(self : PT.ProposalService, job : PT.ProposalServiceJob) : () {
        let fuzz = Fuzz.fromSeed(0);
        self.jobs := Array.append(self.jobs, [{id = fuzz.nat.random(); description = job.description; task = job.task}]);
     };

     public func addService(self: PT.ProposalService, servicePrincipal : PT.TextPrincipal, topics : ?[Nat]) : async* Result.Result<(), Text> {
        var name = "NNS";
        //NNS has no get_metadata method, plus its id never changes 
        if(servicePrincipal != NNS_GOVERNANCE_ID){
            //verify canister exists and is a governance canister
            let gc : G.GovernanceCanister = actor(servicePrincipal);
            try {
                let res = await gc.get_metadata();
                name := Option.get(res.name, "");
            } catch(e){
                return #err("Not a governance canister");
            };   
        };

        if(Map.has(self.services, thash, servicePrincipal)){
            return #err("Service already exists");
        };

        //TODO Validate topics?
        ignore Map.put(self.services, thash, servicePrincipal, {
            topics = Option.get(topics, []);
            name = ?name;
            proposals = Map.new<PT.ProposalId, PT.Proposal>();
            lastProposalId = 0;
        });

        #ok()
     };
}