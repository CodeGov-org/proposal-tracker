import PT "../Proposal/ProposalTypes";
import Map "mo:map/Map";
import { nhash; n64hash; thash; i32hash } "mo:map/Map";
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
import Nat64 "mo:base/Nat64";
import LinkedList "mo:linked-list";
import Utils "../utils";
import LT "../Log/LogTypes";

//TODO: asserts for lowest <= lowestActive <= highest ids or lowest has some value but highest has none
module {

    public func init() : TT.TrackerModel {
        {
            trackedCanisters = Map.new<Text, TT.GovernanceData>();
            var timerId = null;
        }
     };

    public class TrackerRepository(trackerModel: TT.TrackerModel, logService : LT.LogService) {

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

                var lastProposalId : ?PT.ProposalId = null;
                var lowestProposalId : ?PT.ProposalId = null;
                var lowestActiveProposalId : ?PT.ProposalId = null;
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

        func filterValidTopics(validTopics : TT.Topics, topicStrategy : TT.TopicStrategy) : Map.Map<Int32,()> {
            let topicSet : Map.Map<Int32,()> = Map.new();
            switch(topicStrategy){
                case(#All){
                    for(k in Map.keys(validTopics)){
                        Map.set(topicSet, i32hash, k, ());
                    }
                };
                case(#Include(ids)){
                    if(Array.size(ids) == 0){
                        for(k in Map.keys(validTopics)){
                            Map.set(topicSet, i32hash, k, ());
                        };
                    };
                    for(id in Array.vals(ids)){
                        if(Map.has(validTopics, i32hash, id)){
                            Map.set(topicSet, i32hash, id, ());
                        }
                    }
                };
                case(#Exclude(ids)){
                    if(Array.size(ids) == 0){
                        for(k in Map.keys(validTopics)){
                            Map.set(topicSet, i32hash, k, ());
                        };
                    };
                    for(id in Array.vals(ids)){
                        if(not Map.has(validTopics, i32hash, id)){
                            Map.set(topicSet, i32hash, id, ());
                        }
                    }
                };
            };
            return topicSet;
        };

        //TODO: handle manage neuron proposals causing blank spots in the list
        // TODO: fix all variant
        // if no topics are provided then all proposals are returned
        public func getProposals(canisterId: Text, _after : ?PT.ProposalId, topics : TT.TopicStrategy, limit : ?Nat) : Result.Result<TT.GetProposalResponse, TT.GetProposalError> {
            switch (Map.get(trackerModel.trackedCanisters, thash, canisterId)) {
                case (?canister) {
                    let #ok(after) = Utils.optToRes(_after)
                    else{
                        return #err(#InvalidProposalId{start = canister.lowestProposalId; lowestActive = canister.lowestActiveProposalId; end = canister.lastProposalId});
                    };

                    let #ok(lowestProposalId) = Utils.optToRes(canister.lowestProposalId)
                    else {
                        return #err(#InvalidProposalId{start = canister.lowestProposalId; lowestActive = canister.lowestActiveProposalId; end =canister.lastProposalId});
                    };

                    let #ok(lastProposalId) = Utils.optToRes(canister.lastProposalId)
                    else{
                        return #err(#InvalidProposalId{start = canister.lowestProposalId; lowestActive = canister.lowestActiveProposalId; end =canister.lastProposalId});
                    };

                    if (after < lowestProposalId or after > lastProposalId) {
                        return #err(#InvalidProposalId{start = canister.lowestProposalId; lowestActive = canister.lowestActiveProposalId; end =canister.lastProposalId});
                    };

                    if(after == lastProposalId){
                        return #ok(#Success({proposals = []; lastId = canister.lastProposalId}));
                    };

                    let buf = Buffer.Buffer<PT.ProposalAPI>(100);

                    //verify at least one topic is valid and create a set for more efficient checks later
                    let topicSet = filterValidTopics(canister.topics, topics);

                    if (Map.size(topicSet) == 0){
                        return #err(#InvalidTopic);
                    };
                    
                    switch(Map.get(canister.proposalsById, n64hash, after)){
                        case (?node) {
                            var current = ?node;
                            var count = 0;
                            //Iterate linked list directly starting from element instead of head
                            label it while(not Option.isNull(current)){
                                switch(current){
                                    case (?e) {
                                        // only add if the proposal topic is in the list of topics
                                        if(Map.has(topicSet, i32hash, e.data.topicId)){
                                            buf.add(PM.proposalToAPI(e.data));
                                        };
                                        current := e._next;
                                        count := count + 1;
                                        //this is only true if the limit isn't null and equal to count
                                        if(count == Option.get(limit, count + 1)){
                                            return #ok(#LimitReached(Buffer.toArray<PT.ProposalAPI>(buf)));
                                        };
                                    };
                                    case(_){};
                                }
                            };
                            return #ok(#Success({proposals = Buffer.toArray<PT.ProposalAPI>(buf); lastId = canister.lastProposalId}));
                        };
                        case (_) {
                            return #err(#InternalError);
                        };
                    };

                 };
                case (_) { #err(#CanisterNotTracked)}
            }
        };

        func addProposal(governanceData : TT.GovernanceData, proposal : PT.Proposal) {
            let node = LinkedList.Node<PT.Proposal>(proposal);
            Map.set(governanceData.proposalsById, n64hash, proposal.id, node);
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
            if(not isProposalSettled(proposal)){
                ignore Map.add(governanceData.activeProposalsSet, n64hash, proposal.id, ());
            };
            // switch(proposal.status){
            //     case(#Executed(v)){};
            //     case(_){
            //         ignore Map.add(governanceData.activeProposalsSet, n64hash, proposal.id, ());
            //     };
            // };


            switch(governanceData.lastProposalId){
                case(?lastProposalId){
                    if (proposal.id > lastProposalId){
                        governanceData.lastProposalId := ?proposal.id;
                    };
                };
                case(_){
                    governanceData.lastProposalId := ?proposal.id;
                };

            };

            //init lowestProposalId when it is null on first run or update it in case we are syncing backwards
            switch(governanceData.lowestProposalId){
                case(?lowestId){
                    if(proposal.id < lowestId ){
                        governanceData.lowestProposalId := ?proposal.id;
                    };
                };
                case(_){
                    governanceData.lowestProposalId := ?proposal.id;
                }
            };
        };

        func updateProposal(governanceData : TT.GovernanceData, proposal : PT.Proposal) : () {
            switch(Map.get(governanceData.proposalsById, n64hash, proposal.id)){
                case (?p) {
                    p.data.status := proposal.status;
                    p.data.deadlineTimestampSeconds := proposal.deadlineTimestampSeconds;
                    p.data.rewardStatus := proposal.rewardStatus;
                };
                case(_) {
                    logService.logError("Proposal not found", ?"[TrackerRepository::updateProposal]");
                }
            };

            //once the proposal no longer accepts vptes, remove it from active list and update the lowest active proposal id
            if(isProposalSettled(proposal)){
                ignore Map.remove(governanceData.activeProposalsSet, n64hash, proposal.id);

                var lowestId : ?PT.ProposalId = null;
                for (id in Map.keys(governanceData.proposalsById)) {
                    //on first iter lowestId is null, so if the proposal is still in active set this will always be true
                    if(id < Option.get(lowestId, id + 1) and Map.has(governanceData.activeProposalsSet, n64hash, id)){
                        lowestId := ?id;
                    };
                };
                governanceData.lowestActiveProposalId := lowestId;
            };
            // switch(proposal.status){
            //     case(#Executed(e)){
            //         ignore Map.remove(governanceData.activeProposalsSet, n64hash, proposal.id);

            //         var lowestId : ?PT.ProposalId = null;
            //         for (id in Map.keys(governanceData.proposalsById)) {
            //             //on first iter lowestId is null, so this will always be true
            //             if(id < Option.get(lowestId, id + 1)){
            //                 lowestId := ?id;
            //             };
            //         };
            //         governanceData.lowestActiveProposalId := lowestId;
            //     };
            //     case(#Failed){
            //         ignore Map.remove(governanceData.activeProposalsSet, n64hash, proposal.id);

            //         var lowestId : ?PT.ProposalId = null;
            //         for (id in Map.keys(governanceData.proposalsById)) {
            //             //on first iter lowestId is null, so this will always be true
            //             if(id < Option.get(lowestId, id + 1)){
            //                 lowestId := ?id;
            //             };
            //         };
            //         governanceData.lowestActiveProposalId := lowestId;
            //     };
            //     case(_){};
            // };
        };

        public func deleteProposal(governanceData : TT.GovernanceData, id : PT.ProposalId) : Result.Result<(), Text> {
            let #ok(p) = Utils.optToRes(Map.remove(governanceData.proposalsById, n64hash, id))
            else {
                return #err("Proposal id not found");
            };

            LinkedList.remove_node(governanceData.proposals, p);

            // let #ok(t) = optToRes(Map.remove(governanceData.proposalsByTopic, i32hash, p.topicId))
            // else {
            //     return #err("Proposal topic not found");
            // };
            // LinkedList.remove_node(t, LinkedList.Node<PT.Proposal>(p));

            //TODO: it assumes list is ordered but it isnt guaranteed
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
            let updatedProposals = Buffer.Buffer<PT.ProposalAPI>(50);
            let sortedProposals = Array.sort(_proposals, compareIds);

            label processDelta for (pa in Array.vals(sortedProposals)){
                switch(Map.get(governanceData.proposalsById, n64hash, pa.id)){
                    case (?v) {
                        //existing proposal, check if state changed
                        if(isDifferentState(pa, v.data)){
                            updatedProposals.add(PM.proposalToAPI(v.data));
                            updateProposal(governanceData, pa);
                        };
                    };
                    case (_) {
                        //doesnt exist, add it
                        addProposal(governanceData, pa);
                        newProposal.add(PM.proposalToAPI(pa));
                    }
                }
              };

            #ok(Buffer.toArray<PT.ProposalAPI>(newProposal), Buffer.toArray<PT.ProposalAPI>(updatedProposals));
         };

        func isDifferentState(p1 : PT.Proposal, p2 : PT.Proposal) : Bool {
            return p1.status != p2.status or p1.deadlineTimestampSeconds != p2.deadlineTimestampSeconds or p1.rewardStatus != p2.rewardStatus;
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

        func isProposalSettled(proposal : PT.Proposal) : Bool {
            logService.logInfo("Proposal settled: " # Nat64.toText(proposal.id), ?"[TrackerRepository:isProposalSettled]");
            switch(proposal.rewardStatus) {
                case(#ReadyToSettle or #Settled){
                    return true;
                };
                case(_){
                    return false;
                };
            }
        };

    };
    
};
