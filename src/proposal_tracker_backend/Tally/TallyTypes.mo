
module {

   type ProposalStatus = {
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


public type Vote = {
    #Approved;
    #Rejected;
    #Abstained;
    #Pending;
  };

  public type VoteRecord = {
    neuronId : Nat;
    displayName : ?Text;
    vote : Vote;
  };

  public type Ballot = {
    proposalId : Nat64;
    tallyVote : Vote;
    neuronVotes : [VoteRecord];
  };
  type TallyId = Nat;

  public type TallyFeed = {
    tallyId : TallyId;
    ballots : [Ballot];
    governanceCanister : Text;
    //tallyStatus : Vote;
    //timestamp : Nat;
  };

  public type Subscriber = actor {
    tallyUpdate : shared ([TallyFeed]) -> async ();
  }
}