
module {
    public type ProposalId = Nat64;

//     public type ProposalInfo = {
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

    public type ProposalRewardStatus = {
        #Unknown; //0

        // The proposal still accept votes, for the purpose of
        // vote rewards. This implies nothing on the ProposalStatus.
        #AcceptVotes; //1

        // The proposal no longer accepts votes. It is due to settle
        // at the next reward event.
        #ReadyToSettle; //2

        // The proposal has been taken into account in a reward event.
        #Settled; //3

        // The proposal is not eligible to be taken into account in a reward event.
        #Ineligible; //4
    };

    public type ProposalStatus = {
        #Unknown; //0

        // A decision (accept/reject) has yet to be made.
        #Open; //1

        // The proposal has been rejected.
        #Rejected;

        // The proposal has been accepted. At this time, either execution
        // as not yet started, or it has but the outcome is not yet known.
        #Accepted;

        // The proposal was accepted and successfully executed.
        #Executed;

        // The proposal was accepted, but execution failed.
        #Failed;
    };

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
        var rewardStatus : ProposalRewardStatus;
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
        rewardStatus : ProposalRewardStatus;
        deadlineTimestampSeconds : ?Nat64;
        proposalTimestampSeconds : Nat64;
    };

    // public type ProposalStatus = {
    //     #Pending; 
    //     #Executed : {#Approved; #Rejected}
    // };
}