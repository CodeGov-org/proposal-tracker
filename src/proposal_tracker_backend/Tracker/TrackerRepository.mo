import PT "../Proposal/ProposalTypes";
import Map "mo:map/Map";
import { nhash; thash;i32hash } "mo:map/Map";
import Result "mo:base/Result";
import Option "mo:base/Option";
import Buffer "mo:base/Buffer";
import Array "mo:base/Array";
import TT "./TrackerTypes";
import PM "../Proposal/ProposalMappings";
import Time "mo:base/Time";
import Order "mo:base/Order";
import LinkedList "mo:linked-list";

module {

    public func init() : TT.TrackerModel {
        {
            trackedCanisters = Map.new<Text, TT.GovernanceData>();
            var timerId = null;
        }
     };

    public class TrackerRepository(trackerModel: TT.TrackerModel) {

        public func hasGovernance(canisterId: Text) : Bool {
            Map.has(trackerModel.trackedCanisters, thash, canisterId)
        };

        public func addGovernance (servicePrincipal : Text, _name : ?Text, topics : ?[Int32]) : Result.Result<(), Text> {
            if(hasGovernance(servicePrincipal)){
                return #err("Service already exists");
            };

            ignore Map.put(trackerModel.trackedCanisters, thash, servicePrincipal, {
                topics = Option.get(topics, []);
                name = _name;
                proposals = LinkedList.LinkedList<PT.Proposal>();
                activeProposalsSet = Map.new<PT.ProposalId, ()>();
                proposalsById = Map.new<PT.ProposalId, LinkedList.Node<PT.Proposal>>();
                //proposalsByTopic = Map.new<Int32, LinkedList.LinkedList<PT.Proposal>>();

                var lastProposalId : ?Nat = ?0;
                var lowestProposalId : ?Nat = ?0;
                var lowestActiveProposalId : ?Nat = null;
            });  
            #ok()
        };

        public func getGovernance(canisterId: Text) : Result.Result<TT.GovernanceData, Text> {
            switch (Map.get(trackerModel.trackedCanisters, thash,canisterId)) {
                case (?data) { #ok(data) };
                case (_) { #err("Service not found") };
            };
        };

        public func getAllGovernance() : Map.Map<Text, TT.GovernanceData> {
            trackerModel.trackedCanisters
        };

        public func setTimerId(timerId: ?Nat) : Result.Result<(), Text> {
            switch (trackerModel.timerId) {
                case (?id) {
                    #err("Timer already exists");
                };
                case (null) {
                    trackerModel.timerId := timerId;
                    #ok();
                };
            }
        };

        public func getTimerId() : ?Nat {
            trackerModel.timerId
        };

        //TODO: limit and pagination
        public func getProposals(canisterId: Text, after : PT.ProposalId, topics : [Int32]) : Result.Result<[PT.ProposalAPI], TT.GetProposalError> {
            switch (Map.get(trackerModel.trackedCanisters, thash, canisterId)) {
                case (?canister) {
                   //#ok(LinkedList.toArray(canister.proposals));
                   let buf = Buffer.Buffer<PT.ProposalAPI>(100);
                    if (after < Option.get(canister.lowestProposalId, 0) or after > Option.get(canister.lastProposalId, after + 1)) {
                        return #err(#InvalidProposalId{start = Option.get(canister.lowestActiveProposalId, 0); end = Option.get(canister.lastProposalId, 0)});
                    };

                    //TODO: verify at least one topic is valid;
                    
                    switch(Map.get(canister.proposalsById, nhash, after)){
                        case (?node) {
                            var current = ?node;
                            while(not Option.isNull(current)){
                                // if(Array.contains(topics, current.data.topic)){
                                //     buf.push({
                                //         current.data with
                                //         status = current.data.status;                           
                                //     });
                                // };

                                switch(current){
                                    case (?e) {
                                        buf.add({
                                        e.data with
                                        status = e.data.status;                           
                                    });
                                    current := e._next;
                                    };
                                    case(_){};
                                }
                            };
                            return #ok(Buffer.toArray<PT.ProposalAPI>(buf));
                        };
                        case (_) {
                            return #err(#InternalError);
                        };
                    };

                 };
                case (_) { #err(#CanisterNotTracked)}
            }
        };


        func compareIds(a : PT.Proposal, b : PT.Proposal) : Order.Order {
            if(a.id > b.id){
                return #greater;
            }else if(a.id < b.id){
                return #less;
            }else{
                return #equal;
            };
        };

        func updateProposal(governanceData : TT.GovernanceData, proposal : PT.Proposal) : () {
            switch(Map.get(governanceData.proposalsById, nhash, proposal.id)){
                case (?p) {
                    p.data.status := proposal.status;
                };
                case(_) {
                    //ERROR TODO: Log
                }
            };
            ignore Map.remove(governanceData.activeProposalsSet, nhash, proposal.id);

            var lowestId : ?PT.ProposalId = null;
            for (id in Map.keys(governanceData.proposalsById)) {
                //on first iter lowestId is null, so this will always be true
                if(id < Option.get(lowestId, id + 1)){
                    lowestId := ?id;
                };
            };
            governanceData.lowestActiveProposalId := lowestId;
        };

        func addProposal(governanceData : TT.GovernanceData, proposal : PT.Proposal) {
            let node = LinkedList.Node<PT.Proposal>(proposal);
            Map.set(governanceData.proposalsById, nhash, proposal.id, node);
            LinkedList.append_node(governanceData.proposals, node);
            // switch(Map.get(governanceData.proposalsByTopic, i32hash, proposal.topicId)){
            //     case(?v){
            //         LinkedList.append_node(v, LinkedList.Node<PT.Proposal>(proposal));
            //     };
            //     case (_) {
            //         let list = LinkedList.LinkedList<PT.Proposal>();
            //         LinkedList.append_node(list, LinkedList.Node<PT.Proposal>(proposal));
            //         Map.set(governanceData.proposalsByTopic, i32hash, proposal.topicId, list);
            //     }
            // };

            ignore Map.add(governanceData.activeProposalsSet, nhash, proposal.id, ());

            if (proposal.id > Option.get(governanceData.lastProposalId, 0)){
                governanceData.lastProposalId := ?proposal.id;
            }
        };

        func optToRes<T>(opt : ?T) : Result.Result<T, ()> {
            switch(opt){
                case (?t) {
                    return #ok(t);
                };
                case (_) {
                    return #err();
                };
            };
        };

        func removeProposal(governanceData : TT.GovernanceData, id : PT.ProposalId) : Result.Result<(), Text> {
            let #ok(p) = optToRes(Map.remove(governanceData.proposalsById, nhash, id))
            else {
                return #err("Proposal id not found");
            };

            LinkedList.remove_node(governanceData.proposals, p);

            // let #ok(t) = optToRes(Map.remove(governanceData.proposalsByTopic, i32hash, p.topicId))
            // else {
            //     return #err("Proposal topic not found");
            // };
            // LinkedList.remove_node(t, LinkedList.Node<PT.Proposal>(p));

            switch((governanceData.proposals._head, governanceData.proposals._tail)){
                case((?h,?t)) {
                    governanceData.lowestProposalId := ?h.data.id;
                    governanceData.lastProposalId := ?t.data.id;
                };
                case(_) {
                    governanceData.lowestProposalId := ?0;
                    governanceData.lastProposalId := ?0;
                };
            };


            #ok();
        };

         public func processAndUpdateProposals(governanceData : TT.GovernanceData, _proposals: [PT.Proposal]) : Result.Result<([PT.Proposal], [PT.Proposal]), Text> {
            let newProposal = Buffer.Buffer<PT.Proposal>(50);
            let executedProposals = Buffer.Buffer<PT.Proposal>(50);
            let proposals = Array.sort(_proposals, compareIds);

            label processDelta for (pa in Array.vals(proposals)){
                switch(Map.get(governanceData.proposalsById, nhash, pa.id)){
                    case (?v) {
                        //existing proposals, check if state changed
                        if(pa.status != v.data.status){
                            //state changed, update proposal
                            executedProposals.add(v.data);
                            updateProposal(governanceData, pa);
                        };
                    };
                    case (_) {
                        //doesnt exist, add it
                        newProposal.add(pa);
                        addProposal(governanceData, pa);
                    }
                }
              };
            #ok(Buffer.toArray(newProposal), Buffer.toArray(executedProposals));
         };
    };
    
};
