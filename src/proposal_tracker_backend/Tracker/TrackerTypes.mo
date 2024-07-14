
import Map "mo:map/Map";
import Result "mo:base/Result";
import PT "../Proposal/ProposalTypes";
import LinkedList "mo:linked-list";

module {

    public type TextPrincipal = Text;
    public type GetProposalResponse = {
        #Success : {proposals : [PT.ProposalAPI]; lastId :?PT.ProposalId} ;
        #LimitReached : [PT.ProposalAPI]
    };

    public type GetProposalError = {
        #InvalidProposalId : {
            start : ?PT.ProposalId;
            lowestActive : ?PT.ProposalId;
            end : ?PT.ProposalId;
        };
        #InternalError;
        #CanisterNotTracked;
        #InvalidTopic;
    };

    public type TrackerServiceArgs = {
        cleanupStrategy : {
            //Using this if you want a fetch first model makes no sense, only use if you want to go pub/sub
           // #DeleteAfterExecution;
            #DeleteAfterTime : {
                #Days : Nat;
                #Hours : Nat;
                #Weeks : Nat;
            };
           // #DeleteAfterVotingPeriodEnds;
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

    public type TopicStrategy = {
            #All;
            #Include : [Int32];
            #Exclude : [Int32];
    };

    public type GovernanceSettings = {
        var includeRewardStatus :  [Int32];
        var omitLargeFields : ?Bool;
        var topicStrategy : TopicStrategy;
        var includeAllManageNeuronProposals : ?Bool;
        var includeStatus : [Int32];
    };

    public type GovernanceData = {
        name : ?Text; //Name of the DAO
        description : ?Text; //Description of the DAO
        topics : Topics; //a set to store valid topic Ids to track for the governance canister
        var lastProposalId : ?PT.ProposalId;
        var lowestProposalId : ?PT.ProposalId;
        var lowestActiveProposalId : ?PT.ProposalId;
        proposals :  LinkedList.LinkedList<PT.Proposal>; //sorted list of proposals
        proposalsById : Map.Map<PT.ProposalId, LinkedList.Node<PT.Proposal>>; // map of proposals indexed by proposal id linking to the node in the proposals list for faster iterations
        activeProposalsSet : Map.Map<PT.ProposalId, ()>;
        //proposalsByTopic : Map.Map<Int32, LinkedList.LinkedList<PT.Proposal>>; //sorted list of proposals indexed by topic id;
    };

    //task is provided with: governance id, new and updated proposals
    public type TrackerServiceJob = (governanceId : Text, newProposals : [PT.ProposalAPI], updatedProposals : [PT.ProposalAPI]) -> async* ();

    public type TrackerService = {
        update : (cb : TrackerServiceJob) -> async ();
        initTimer : (tickrate : ?Nat, job : TrackerServiceJob) -> async* Result.Result<(), Text>;
        cancelTimer : () -> Result.Result<(), Text>;
        updateTimer : (newTickrate : Nat, job : TrackerServiceJob) -> async Result.Result<(), Text>;
        addGovernance : (governancePrincipal : Text, topicStrategy : TopicStrategy) -> async* Result.Result<(), Text>;
        getProposals : (canisterId: Text, after : ?PT.ProposalId, topics : TopicStrategy) -> Result.Result<GetProposalResponse, GetProposalError>;
    };
    
}