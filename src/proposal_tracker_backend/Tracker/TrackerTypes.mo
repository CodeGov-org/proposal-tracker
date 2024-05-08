
import Map "mo:map/Map";
import Result "mo:base/Result";
import PT "../Proposal/ProposalTypes";
import LinkedList "mo:linked-list";

module {

    public type TextPrincipal = Text;

    // public type ProposalFilter = {topics : ?[Nat]; states : ?[PT.ProposalStatus]; height: ?Nat};

    public type GetProposalError = {
        #InvalidProposalId : {
            start : PT.ProposalId;
            end : PT.ProposalId;
        };
        #InternalError;
        #CanisterNotTracked;
        #InvalidTopic;
    };

    public type TrackerServiceArgs = {
        lifetime : {
            #DeleteImmediately : ();
            #DeleteAfterExecution : ();
            #DeleteAfterTime : Nat;
        };
    };

    public type TrackerModel = {
        trackedCanisters : Map.Map<Text, GovernanceData>;
        var timerId : ?Nat;
    };

    type ProposalMapByTopic = Map.Map<Int32, LinkedList.LinkedList<PT.Proposal>>; //sorted list of proposals indexed by topic id

    public type GovernanceData = {
        topics : [Int32]; //store valid topics for the governance canister
        name : ?Text; //Name of the DAO
        var lastProposalId : ?Nat;
        var lowestProposalId : ?Nat;
        var lowestActiveProposalId : ?Nat;
        proposals :  LinkedList.LinkedList<PT.Proposal>; //sorted list of proposals
        proposalsById : Map.Map<PT.ProposalId, LinkedList.Node<PT.Proposal>>;
        //proposalsByTopic : Map.Map<Int32, LinkedList.LinkedList<PT.Proposal>>; //sorted list of proposals indexed by topic id;
        activeProposalsSet : Map.Map<PT.ProposalId, ()>;
    };

    public type TrackerServiceJob = (newProposals : [PT.Proposal], executedProposals : [PT.Proposal]) -> (); //task is provided with new and executedProposals proposals
    
}