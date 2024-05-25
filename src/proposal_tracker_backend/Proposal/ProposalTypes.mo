
module {
    public type ProposalId = Nat;

//       public type ProposalInfo = {
//     id : ?NeuronId;
//     status : Int32;
//     topic : Int32;
//     failure_reason : ?GovernanceError;
//     ballots : [(Nat64, Ballot)];
//     proposal_timestamp_seconds : Nat64;
//     reward_event_round : Nat64;
//     deadline_timestamp_seconds : ?Nat64;
//     failed_timestamp_seconds : Nat64;
//     reject_cost_e8s : Nat64;
//     derived_proposal_information : ?DerivedProposalInformation;
//     latest_tally : ?Tally;
//     reward_status : Int32;
//     decided_timestamp_seconds : Nat64;
//     proposal : ?Proposal;
//     proposer : ?NeuronId;
//     executed_timestamp_seconds : Nat64;
//   };

    public type ListProposalArgs = {
        includeRewardStatus :  [Int32];
        omitLargeFields : ?Bool;
        excludeTopic: [Int32];
        includeAllManageNeuronProposals : ?Bool;
        includeStatus : [Int32];
    };
    public type Proposal = {
        id : ProposalId;
        topicId : Int32;
        title : Text;
        description : ?Text;
        proposer : Nat64;
        timestamp : Nat64;
        var status : ProposalStatus;
        var deadlineTimestampSeconds : ?Nat64;
        proposalTimestampSeconds : Nat64;
    };

    //add type
    public type ProposalAPI = {
        id : ProposalId;
        topicId : Int32;
        title : Text;
        description : ?Text;
        proposer : Nat64;
        timestamp : Nat64;
        status : ProposalStatus;
        deadlineTimestampSeconds : ?Nat64;
        proposalTimestampSeconds : Nat64;
    };

    public type ProposalStatus = {
        #Pending; 
        #Executed : {#Approved; #Rejected}
    };
}