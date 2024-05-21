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
import Debug "mo:base/Debug";
import Int32 "mo:base/Int32";
import LinkedList "mo:linked-list";
import Utils "../utils";

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

        public func addGovernance (servicePrincipal : Text, _name : ?Text, _description : ?Text, _topics : TT.Topics) : Result.Result<(), Text> {
            if(hasGovernance(servicePrincipal)){
                return #err("Service already exists");
            };

            ignore Map.put(trackerModel.trackedCanisters, thash, servicePrincipal, {
                topics = _topics;
                name = _name;
                description = _description;
                proposals = LinkedList.LinkedList<PT.Proposal>();
                activeProposalsSet = Map.new<PT.ProposalId, ()>();
                proposalsById = Map.new<PT.ProposalId, LinkedList.Node<PT.Proposal>>();

                var lastProposalId : ?Nat = null;
                var lowestProposalId : ?Nat = null;
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

        //TODO: limit to 100 to prevent hitting message limit
        public func getProposals(canisterId: Text, _after : ?PT.ProposalId, topics : [Int32], limit : ?Nat) : Result.Result<TT.GetProposalResponse, TT.GetProposalError> {
            switch (Map.get(trackerModel.trackedCanisters, thash, canisterId)) {
                case (?canister) {
                    let #ok(after) = Utils.optToRes(_after)
                    else{
                        return #err(#InvalidProposalId{start = Option.get(canister.lowestProposalId, 0); end = Option.get(canister.lastProposalId, 0)});
                    };
                    if (Option.isNull(canister.lowestProposalId) or Option.isNull(canister.lastProposalId) or after < Option.get(canister.lowestProposalId, 0) or after > Option.get(canister.lastProposalId, after + 1)) {
                        return #err(#InvalidProposalId{start = Option.get(canister.lowestProposalId, 0); end = Option.get(canister.lastProposalId, 0)});
                    };

                    if(after == Option.get(canister.lastProposalId, after + 1)){
                        return #ok(#Success([]));
                    };

                    let buf = Buffer.Buffer<PT.ProposalAPI>(100);

                    //verify at least one topic is valid and create a set for more efficient checks later
                    let topicSet = Map.new<Int32,()>();
                    label it for(topicId in Array.vals(topics)){
                        if(not Map.has(canister.topics, i32hash, topicId)){
                            continue it;
                        };

                        Map.set(topicSet, i32hash, topicId, ());
                    };

                    if (Map.size(topicSet) == 0){
                        return #err(#InvalidTopic);
                    };
                    
                    switch(Map.get(canister.proposalsById, nhash, after)){
                        case (?node) {
                            var current = ?node;
                            var count = 0;
                            //Iterate linked list directly starting from element instead of head
                            label it while(not Option.isNull(current)){
                                switch(current){
                                    case (?e) {
                                        // only add if the proposal topic is in the list of topics
                                        if(Map.has(topicSet, i32hash, e.data.topicId)){
                                            buf.add({
                                                e.data with
                                                status = e.data.status;                           
                                            });
                                        };
                                        current := e._next;
                                        count := count + 1;
                                        //this is only true is the limit isn't null and equal to count
                                        if(count == Option.get(limit, count + 1)){
                                            return #ok(#LimitReached(Buffer.toArray<PT.ProposalAPI>(buf)));
                                        };
                                    };
                                    case(_){};
                                }
                            };
                            return #ok(#Success(Buffer.toArray<PT.ProposalAPI>(buf)));
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
                    //Logger.log(#Warning, "Proposal not found");
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

            //occasionally a proposal may get here already executed, if so dont add to active list
            switch(proposal.status){
                case(#Executed(v)){};
                case(_){
                    ignore Map.add(governanceData.activeProposalsSet, nhash, proposal.id, ());
                };
            };

            if (proposal.id > Option.get(governanceData.lastProposalId, 0)){
                governanceData.lastProposalId := ?proposal.id;
            };

            //init during first run
            if(Option.isNull(governanceData.lowestProposalId)){
                governanceData.lowestProposalId := ?proposal.id;
            };
        };

        public func deleteProposal(governanceData : TT.GovernanceData, id : PT.ProposalId) : Result.Result<(), Text> {
            let #ok(p) = Utils.optToRes(Map.remove(governanceData.proposalsById, nhash, id))
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
                    governanceData.lowestProposalId := null;
                    governanceData.lastProposalId := null;
                };
            };


            #ok();
        };

        public func processAndUpdateProposals(governanceData : TT.GovernanceData, _proposals: [PT.Proposal]) : Result.Result<([PT.ProposalAPI], [PT.ProposalAPI]), Text> {
            let newProposal = Buffer.Buffer<PT.ProposalAPI>(50);
            let executedProposals = Buffer.Buffer<PT.ProposalAPI>(50);
            let sortedProposals = Array.sort(_proposals, compareIds);
            Debug.print(debug_show(sortedProposals));
            label processDelta for (pa in Array.vals(sortedProposals)){
                switch(Map.get(governanceData.proposalsById, nhash, pa.id)){
                    case (?v) {
                        //existing proposal, check if state changed
                        if(pa.status != v.data.status){
                            switch(pa.status){
                                case(#Executed(e)){
                                    //update proposal
                                    updateProposal(governanceData, pa);
                                    executedProposals.add({v.data with status = v.data.status});
                                };
                                case(_){};
                            };
                        };
                    };
                    case (_) {
                        //doesnt exist, add it
                        addProposal(governanceData, pa);
                        newProposal.add({pa with status = pa.status});
                    }
                }
              };
            //Debug.print(debug_show(governanceData.proposalsById));
            #ok(Buffer.toArray<PT.ProposalAPI>(newProposal), Buffer.toArray<PT.ProposalAPI>(executedProposals));
         };
    };
    
};
