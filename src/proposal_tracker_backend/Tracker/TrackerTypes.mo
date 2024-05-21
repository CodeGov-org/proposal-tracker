
import Map "mo:map/Map";
import Result "mo:base/Result";
import PT "../Proposal/ProposalTypes";
import LinkedList "mo:linked-list";

module {

    public type TextPrincipal = Text;

    // public type ProposalFilter = {topics : ?[Nat]; states : ?[PT.ProposalStatus]; height: ?Nat};

    public type GetProposalResponse = {
        #Success : [PT.ProposalAPI];
        #LimitReached : [PT.ProposalAPI]
    };

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
        cleanupStrategy : {
            //Using this if you want a fetch first model makes no sense, only use if you want to go pub/sub
            #DeleteImmediately;
            #DeleteAfterTime : {
                #Days : Nat;
                #Hours : Nat;
                #Weeks : Nat;
            };
        };
    };

    public type TrackerModel = {
        trackedCanisters : Map.Map<Text, GovernanceData>;
        var timerId : ?Nat;
    };

    type ProposalMapByTopic = Map.Map<Int32, LinkedList.LinkedList<PT.Proposal>>; //sorted list of proposals indexed by topic id

    //internal representation of topics, optimized for lookups
    public type Topics = Map.Map<Int32, {
            name : Text;
            description : ?Text;
        }>;

    public type TopicsStrategy = {
            #All;
            #Include : [Int32];
            #Exclude : [Int32];
    };

    public type GovernanceData = {
        name : ?Text; //Name of the DAO
        description : ?Text; //Description of the DAO
        topics : Topics; //a set to store valid topic Ids to track for the governance canister
        var lastProposalId : ?Nat;
        var lowestProposalId : ?Nat;
        var lowestActiveProposalId : ?Nat;
        proposals :  LinkedList.LinkedList<PT.Proposal>; //sorted list of proposals
        proposalsById : Map.Map<PT.ProposalId, LinkedList.Node<PT.Proposal>>; // map of proposals indexed by proposal id linking to the node in the proposals list for faster iterations
        activeProposalsSet : Map.Map<PT.ProposalId, ()>;
        //proposalsByTopic : Map.Map<Int32, LinkedList.LinkedList<PT.Proposal>>; //sorted list of proposals indexed by topic id;
    };

    //task is provided with: governance id, new and executedProposals proposals
    public type TrackerServiceJob = (governanceId : Text, newProposals : [PT.ProposalAPI], executedProposals : [PT.ProposalAPI]) -> ();
    
}