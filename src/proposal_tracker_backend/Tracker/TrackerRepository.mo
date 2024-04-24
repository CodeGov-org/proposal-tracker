import PT "../Proposal/ProposalTypes";
import Map "mo:map/Map";
import { nhash; thash } "mo:map/Map";
import Result "mo:base/Result";
import Option "mo:base/Option";
import TT "./TrackerTypes";

module {

    public type GovernanceData = {
        topics : [Nat]; //store valid topics for the governance canister
        name : ?Text;
        proposals : Map.Map<PT.ProposalId, PT.Proposal>;
        lastProposalId : Nat;
    };


    public func init() : TT.TrackerModel {
        {
            trackedCanisters = Map.new<Text, GovernanceData>();
            var timerId = null;
        }
     };

    public class TrackerRepository(trackerModel: TT.TrackerModel) {
        let model = trackerModel;

        public func getProposalById(canisterId: Text, proposalId: Nat) : Result.Result<PT.Proposal, Text> {
            switch (Map.get(model.trackedCanisters, thash, canisterId)) {
                case (?canister) {
                    switch (Map.get(canister.proposals, nhash, proposalId)) {
                        case (?proposal) { #ok(proposal) };
                        case (_) { #err("Proposal not found") };
                 };
                };
                case (_) { #err("Canister not tracked")}
            }
        };

        public func getProposals(canisterId: Text) : Result.Result<[(Nat, PT.Proposal)], Text> {
            switch (Map.get(model.trackedCanisters, thash, canisterId)) {
                case (?canister) {
                   #ok(Map.toArray(canister.proposals));
                 };
                case (_) { #err("Canister not tracked")}
            }
        };

        public func hasGovernance(canisterId: Text) : Bool {
            Map.has(model.trackedCanisters, thash, canisterId)
        };

        public func addGovernance (servicePrincipal : Text, name : ?Text, topics : ?[Nat]) : Result.Result<(), Text> {
            if(hasGovernance(servicePrincipal)){
                return #err("Service already exists");
            };

            //TODO Validate topics?
            ignore Map.put(model.trackedCanisters, thash, servicePrincipal, {
                topics = Option.get(topics, []);
                name = name;
                proposals = Map.new<PT.ProposalId, PT.Proposal>();
                lastProposalId = 0;
            });  
            #ok()
        };

        public func getGovernance(canisterId: Text) : Result.Result<GovernanceData, Text> {
            switch (Map.get(model.trackedCanisters, thash,canisterId)) {
                case (?data) { #ok(data) };
                case (_) { #err("Service not found") };
            };
        };

        public func getAllGovernance() : Map.Map<Text, GovernanceData> {
            model.trackedCanisters
        };

        public func setTimerId(timerId: ?Nat) : Result.Result<(), Text> {
            switch (model.timerId) {
                case (?id) {
                    #err("Timer already exists");
                };
                case (null) {
                    model.timerId := timerId;
                    #ok();
                };
            }
        };

        public func getTimerId() : ?Nat {
            model.timerId
        }
    }
}