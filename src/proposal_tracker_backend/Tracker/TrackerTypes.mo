
import Map "mo:map/Map";
import Result "mo:base/Result";
import PT "../Proposal/ProposalTypes";

module {

    public type TextPrincipal = Text;

    public type TrackerModel = {
        trackedCanisters : Map.Map<Text, GovernanceData>;
        var timerId : ?Nat;
    };


    public type GovernanceData = {
        topics : [Nat]; //store valid topics for the governance canister
        name : ?Text;
        proposals : Map.Map<PT.ProposalId, PT.Proposal>;
        lastProposalId : Nat;
    };

    public type TrackerServiceJob = (GovernanceData, [PT.Proposal]) -> (); //task is provided with updated data for each governance service and the delta of the last update
    
}