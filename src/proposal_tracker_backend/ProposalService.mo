import Map "mo:map/Map";
import Time "mo:base/Time";
import Result "mo:base/Result";
import Timer "mo:base/Timer";
import ProposalService "ProposalService";
import G "./GovernanceTypes";
import PT "./ProposalTypes";
import Prng "mo:prng";

let DEFAULT_TICKRATE : Nat = 60 * 60 * 1000; // 1 hour 
let NNS_GOVERNANCE_ID = "rrkah-fqaaa-aaaaa-aaaaq-cai";

module {

     public func init() : PT.ProposalService {
        {
            services = Map.new<Principal, PT.ServiceData>();
            tickrate = DEFAULT_TICKRATE;
        }
     };

     public func initTimer(self : PT.ProposalService, job : ?PT.ProposalJob) : async* () {

        switch(timerId){
          case(?t){ return};
          case(_){};
        };

        switch(job){
          case(?j){ addJob(self, j);};
          case(_){
          };
        };

        self.timerId := await Timer.setTimer(tickrate, func() : async(){
            for ((canisterId, serviceData) in self.services.entries()) {
                let gc : G.GovernanceCanister = actor (canisterId);
                var newProposals = await gc.list_proposals({
                    include_reward_status = [];
                    omit_large_fields = ?true;
                    before_proposal = null;
                    limit = 50;
                    exclude_topic = [];
                    include_all_manage_neuron_proposals = null;
                    include_status = [];
                })
                //process delta
                newProposals := Array.filter(newProposals, func(proposal) : Bool{
                    for (p in serviceData.proposals.vals()){
                        //filter proposal already in the list which have not changed
                        if(p.id == proposal.id and p.status == proposal.status){
                            return false;
                        };
                        return true;
                    };
                });

                //update service data. TODO: Move to repo
                for (proposal in newProposals){
                    let found = Array.find(serviceData.proposals.vals(), func(p) : Bool{
                        p.id == proposal.id
                    });

                    switch(found){
                        case(?p){
                            p.status := proposal.status;
                        };
                        case(null){
                            serviceData.proposals := Array.append(serviceData.proposals, proposal);
                        }
                    }
                };

                //run jobs
                for (job in self.jobs){
                    job.f(serviceData, newProposals);
                };
            }
        });
     };

     public func addJob(self : PT.ProposalService, job : { description : ?Text; f : (ServiceData, [Proposal]) -> ()}) : () {
        let rng = Prng.Seiran128();
        rng.init(Time.now());
        self.jobs := Array.append(jobs, {id = rng.next(); description = job.description; f = job.f});
     };

     public func addService(self: PT.ProposalService, servicePrincipal : Principal, topics : ?[Nat]) : async* Result.Result<(), Text> {
        var name = "NNS";
        if(servicePrincipal != NNS_GOVERNANCE_ID){
            //verify canister exists and is a governance canister
            let gc : G.GovernanceCanister = actor(servicePrincipal);
            try {
                name := await gc.get_metadata();
            } catch(e){
                return #err("Not a governance canister");
            };   
        };


        //TODO Validate topics?
        self.services.put(servicePrincipal, {
            topics = Option.get(topics, []);
            name = ?name;
            proposals = [];
            lastId = 0;
        });

     };
}