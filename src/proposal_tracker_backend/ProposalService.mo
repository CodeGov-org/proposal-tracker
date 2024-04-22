import Map "mo:map/Map";
import Option "mo:base/Option";
import Time "mo:base/Time";
import Array "mo:base/Array";
import Result "mo:base/Result";
import Timer "mo:base/Timer";
import G "./GovernanceTypes";
import PT "./ProposalTypes";
import Prng "mo:prng";
import Nat64 "mo:base/Nat64";

let DEFAULT_TICKRATE : Nat = 10_000; // 10 secs 
let NNS_GOVERNANCE_ID = "rrkah-fqaaa-aaaaa-aaaaq-cai";

module {

     public func init() : PT.ProposalService {
        {
            services = Map.new< PT.TextPrincipal, PT.ServiceData>();
            var tickrate = DEFAULT_TICKRATE;
            var timerId = null;
            var jobs = [];
        }
     };

     public func initTimer(self : PT.ProposalService, job : ?PT.ProposalJob) : async* () {

        switch(self.timerId){
          case(?t){ return};
          case(_){};
        };

        switch(job){
          case(?j){ addJob(self, j);};
          case(_){
          };
        };

        self.timerId := await Timer.setTimer(#seconds(self.tickrate), func() : async (){
            for ((canisterId, serviceData) in Map.entries(self.services)) {
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

     public func addJob(self : PT.ProposalService, job : { description : ?Text; f : (PT.ServiceData, [PT.Proposal]) -> ()}) : () {
        let rng = Prng.Seiran128();
       //rng.init(Nat64.fromNat(Time.now()));
        rng.init(0);
        self.jobs := Array.append(self.jobs, {id = rng.next(); description = job.description; f = job.f});
     };

     public func addService(self: PT.ProposalService, servicePrincipal : PT.TextPrincipal, topics : ?[Nat]) : async* Result.Result<(), Text> {
        var name = "NNS";
        if(servicePrincipal != NNS_GOVERNANCE_ID){
            //verify canister exists and is a governance canister
            let gc : G.GovernanceCanister = actor(servicePrincipal);
            try {
                name := Option.get(await gc.get_metadata().name, "");
            } catch(e){
                return #err("Not a governance canister");
            };   
        };


        //TODO Validate topics?
        Map.put(self.services, servicePrincipal, {
            topics = Option.get(topics, []);
            name = ?name;
            proposals = [];
            lastId = 0;
        });

        #ok()
     };
}