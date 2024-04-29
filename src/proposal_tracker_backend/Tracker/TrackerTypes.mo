
import Map "mo:map/Map";
import Result "mo:base/Result";
import PT "../Proposal/ProposalTypes";

module {

    public type TextPrincipal = Text;

    public type TrackerServiceArgs = {
        lifetime : {
            #None : ();
            #DeleteAfterExecution : ();
            #DeleteAfterTime : Nat;
        };
    };

    public type TrackerModel = {
        trackedCanisters : Map.Map<Text, GovernanceData>;
        var timerId : ?Nat;
    };

    type ProposalMapByTopic = Map.Map<Int32, [PT.Proposal]>; //sorted array of proposals indexed by topic id

    public type GovernanceData = {
        topics : [Int32]; //store valid topics for the governance canister
        name : ?Text; //Name of the DAO
        activeProposals : ProposalMapByTopic;
        executedProposals : ProposalMapByTopic;
        proposalsLookup : Map.Map<PT.ProposalId, {topicId : Int32; status : PT.ProposalStatus}>;
        var proposalsRangeLastId : ?Nat;
        var proposalsRangeLowestId : ?Nat;
        var lowestActiveProposalId : ?Nat;
    };

    public type TrackerServiceJob = (newProposals : [PT.Proposal], executedProposals : [PT.Proposal]) -> (); //task is provided with new and executedProposals proposals
    
}