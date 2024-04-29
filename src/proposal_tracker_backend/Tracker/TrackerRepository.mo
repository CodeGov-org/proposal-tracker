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

            //TODO Validate topics?
            ignore Map.put(trackerModel.trackedCanisters, thash, servicePrincipal, {
                topics = Option.get(topics, []);
                name = _name;
                activeProposals = Map.new<Int32, [PT.Proposal]>();
                executedProposals = Map.new<Int32, [PT.Proposal]>();
                proposalsLookup = Map.new<PT.ProposalId, {topicId : Int32; status : PT.ProposalStatus}>();
                var proposalsRangeLastId : ?Nat = ?0;
                var proposalsRangeLowestId : ?Nat = ?0;
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

        // public func getProposalById(canisterId: Text, proposalId: Nat) : Result.Result<PT.Proposal, Text> {
        //     switch (Map.get(trackerModel.trackedCanisters, thash, canisterId)) {
        //         case (?canister) {
        //             switch (Map.get(canister.proposalsLookup, nhash, proposalId)) {
        //                 case (?proposal) { 
        //                     var pMap = canister.activeProposals;
        //                     switch(proposal.status){
        //                         case (#Executed(v)) {
        //                             pMap := canister.executedProposals;
        //                         };
        //                         case (_) {};
        //                     };
                            
        //                     switch(Map.get(pMap, i32hash, proposal.topicId)){
        //                         case (?pArray) {
        //                             let res = Array.find(pArray, func(p : PT.Proposal) : Bool {
        //                                 return p.id == proposalId;
        //                             });

        //                             switch(res){
        //                                 case (?proposal) {
        //                                     return #ok(proposal);
        //                                 };
        //                                 case (_) {
        //                                     return #err("Proposal not found, no proposal with this topic id")
        //                                 }
        //                             };
        //                         };
        //                         case (_) {
        //                             return #err("Proposal not found, no proposal with this topic id")
        //                         };
        //                     };
        //                  };
        //                  case (_) { return #err("Proposal not found, ID doesnt exist in lookup") };
        //             };
        //         };
        //         case (_) { #err("Canister not tracked")}
        //     }
        // };

        type ProposalFilter = {topics : ?[Nat]; states : ?[PT.ProposalStatus]; height: ?Nat};

        // public func getProposals(canisterId: Text, filters : [ProposalFilter]) : Result.Result<[(Nat, PT.Proposal)], Text> {
        //     switch (Map.get(trackerModel.trackedCanisters, thash, canisterId)) {
        //         case (?canister) {
        //            #ok(Map.toArray(canister.proposals));
        //          };
        //         case (_) { #err("Canister not tracked")}
        //     }
        // };

        // public func getProposalsFromHeightByTopics(canisterId: Text, startHeight: Nat, topics: [Nat]) : Result.Result<[PT.Proposal], Text> {
        //     switch (Map.get(trackerModel.trackedCanisters, thash, canisterId)) {
        //         case (?canister) {
        //             let proposalBuffer = Buffer.Buffer<PT.Proposal>(50);
        //             for ((id, proposal) in Map.entries(canister.proposals)) {
        //                 if (proposal.id >= startHeight and Array.find(topics, func(t : Nat) : Bool{
        //                     t == proposal.id}) != null) {
        //                     proposalBuffer.add(proposal);
        //                 };
        //          };
        //          #ok(Buffer.toArray(proposalBuffer));
        //         };
        //         case (_) { #err("Canister not tracked")}
        //         }
        // };

        // func addProposal(governanceData : TT.GovernanceData, proposal : PT.Proposal) : () {
        //     // if(proposal.id > governanceData.lastProposalId){
        //     //     governanceData.lastProposalId := proposal.id;
        //     // };

        //     //Map.set(governanceData.proposalsLookup, nhash, proposalId, {state: proposal.state; topic = proposal.topic;});
        //     switch(Map.get(governanceData.activeProposals, ihash, proposal.topicId)){
        //         case (?pArray) {
        //             Map.set(governanceData.activeProposals, nhash, proposal.topicId, Array.push(pArray, proposal));
        //         };
        //         case (_) {
        //             Map.set(governanceData.activeProposals, nhash, proposal.topicId, [proposal]);
        //         };
        //     }
        // };

        func compareIds(a : PT.Proposal, b : PT.Proposal) : Order.Order {
            if(a.id > b.id){
                return #greater;
            }else if(a.id < b.id){
                return #less;
            }else{
                return #equal;
            };
        };

        func addProposals(governanceData : TT.GovernanceData, map : Map.Map<Int32, Buffer.Buffer<PT.Proposal>>) : (){
            for ((topic, proposalBuffer) in Map.entries(map)) {
                switch(Map.get(governanceData.activeProposals, i32hash, topic)){
                    case (?pArray) {
                        Map.set(governanceData.activeProposals, i32hash, topic, Array.append(pArray, Array.sort(Buffer.toArray(proposalBuffer), compareIds)));
                    };
                    case (_) {
                        Map.set(governanceData.activeProposals, i32hash, topic, Array.sort(Buffer.toArray(proposalBuffer), compareIds));
                    }
                };
            };
        };

        func updateProposals(governanceData : TT.GovernanceData, map : Map.Map<Int32, Buffer.Buffer<PT.Proposal>>) : () {

        };

        //TODO: cleanup after validation
        public func processAndUpdateProposals(governanceData : TT.GovernanceData, proposals: [PT.Proposal]) : Result.Result<([PT.Proposal], [PT.Proposal]), Text> {
            let newProposal = Buffer.Buffer<PT.Proposal>(50);
            let executedProposals = Buffer.Buffer<PT.Proposal>(50);

            let newProposalsByTopic = Map.new<Int32, Buffer.Buffer<PT.Proposal>>();
            let executedProposalsByTopic = Map.new<Int32, Buffer.Buffer<PT.Proposal>>();

            label processDelta for (pa in Array.vals(proposals)){
                switch (Map.get(governanceData.proposalsLookup, nhash, pa.id)) {
                    case (?proposal) { 
                        //if the proposal has already been moved to the executed set, then we can skip it
                        let #Pending(v) = proposal.status
                        else { continue processDelta;};
                
                        switch(Map.get(governanceData.activeProposals, i32hash, proposal.topicId)){
                            case (?pArray) {
                                //TODO: use binary search
                                let res = Array.find(pArray, func(p : PT.Proposal) : Bool {
                                    return p.id == pa.id;
                                });

                                switch(res){
                                    case (?existingProposal) {
                                        if(pa.status != existingProposal.status){
                                            executedProposals.add(existingProposal);
                                            //update lookup
                                            Map.set(governanceData.proposalsLookup, nhash, pa.id, {status= pa.status; topicId = pa.topicId;});
                                            //insert into executed proposals by topic
                                            switch (Map.get(executedProposalsByTopic, i32hash, pa.topicId)){
                                                case(?buf){
                                                    buf.add(pa);
                                                };
                                                case (_) {
                                                    let b = Buffer.Buffer<PT.Proposal>(50);
                                                    b.add(pa);
                                                    Map.set(executedProposalsByTopic, i32hash, pa.topicId, b);
                                                };
                                            };
                                            //remove from active proposals
                                            
                                        }
                                    };
                                    case (_) {
                                        return #err("Proposal not found, no proposal with this topic id")
                                    }
                                };
                            };
                            case (_) {
                                return #err("Proposal not found, no proposal with this topic id")
                            };
                        };
                        };
                        //doesnt exist, add it
                        case (_) { 
                            //check if the proposal should be in the executed set
                            //needed in case at first try the proposal is already settled
                            switch(pa.status){
                                case (#Pending){
                                    newProposal.add(pa);
                                    switch (Map.get(newProposalsByTopic, i32hash, pa.topicId)){
                                        case(?buf){
                                            buf.add(pa);
                                        };
                                        case (_) {
                                            let b = Buffer.Buffer<PT.Proposal>(50);
                                            b.add(pa);
                                            Map.set(newProposalsByTopic, i32hash, pa.topicId, b);
                                        }
                                    };
                                };
                                case (#Executed(v)) {
                                    executedProposals.add(pa);
                                    switch (Map.get(executedProposalsByTopic, i32hash, pa.topicId)){
                                        case(?buf){
                                            buf.add(pa);
                                        };
                                        case (_) {
                                            let b = Buffer.Buffer<PT.Proposal>(50);
                                            b.add(pa);
                                            Map.set(executedProposalsByTopic, i32hash, pa.topicId, b);
                                        };
                                    };
                                };
                            };

                            if(pa.id > Option.get(governanceData.proposalsRangeLastId, 0)){
                                governanceData.proposalsRangeLastId := ?pa.id;
                            };
                            Map.set(governanceData.proposalsLookup, nhash, pa.id, {status= pa.status; topicId = pa.topicId;});
                            //addProposal(governanceData, proposal);
                         };
                };
            };

            addProposals(governanceData, newProposalsByTopic);
            updateProposals(governanceData, executedProposalsByTopic);

            #ok(Buffer.toArray(newProposal), Buffer.toArray(executedProposals));
        };
    };
    
};
