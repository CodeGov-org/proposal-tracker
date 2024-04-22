import Map "mo:map/Map";
import Time "mo:base/Time";
import Result "mo:base/Result";
import Timer "mo:base/Timer";
import ProposalService "ProposalService";
import G "./GovernanceTypes";
import PT "./ProposalTypes";

let DEFAULT_TICKRATE : Nat = 60 * 60 * 1000; // 1 hour 

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
                let newProposals = gc.list_proposals({
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
                        if(p.id == proposal.id and p.status == proposal.status){
                            return false;
                        };
                        return true;
                    };
                });
                //update service data. TODO: Move to repo
                for (oldProposal in serviceData.proposals.vals()){
                    let found = Array.find(newProposals, func(p) : Bool{
                        p.id == oldProposal.id
                    });

                    switch(found){
                        //invariant
                        case(?p){
                            oldProposal.status := p.status;
                        };
                        case(null){}
                    }
                };

                //run jobs
                for (job in self.jobs.vals()){
                    job(serviceData, newProposals);
                };
            }
        });
     };

     public func addJob(self : PT.ProposalService, job : PT.ProposalJob) : async* () {
        self.jobs := Array.append(jobs, job);
     };

    //  public func addService(servicePrincipal : Principal, topics : ?[Nat]) : async* Result.Result<(), Text> {

    //  };
}