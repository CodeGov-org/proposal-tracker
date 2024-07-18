import Result "mo:base/Result";

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

    public type GovernanceId = Text;
    public type NeuronId = Nat64;
    public type TallyId = Text;
    public type ProposalId = Nat64;

public type Vote = {
    #Yes;
    #No;
    #Abstained;
    #Pending;
  };

  public type VoteRecord = {
    neuronId : NeuronId;
    displayName : ?Text;
    vote : Vote;
  };

  public type Ballot = {
    proposalId : Nat64;
    tallyVote : Vote;
    neuronVotes : [VoteRecord];
  };

  public type TallyFeed = {
    tallyId : TallyId;
    alias : ?Text;
    ballots : [Ballot];
    governanceCanister : Text;
  };

  public type AddTallyArgs = {
      governanceId : Text;
      alias : ?Text;
      topics : [Int32];
      neurons : [NeuronId];
      subscriber : Principal;
  };

  public type Subscriber = actor {
    tallyUpdate : shared ([TallyFeed]) -> async ();
  };

  public type TallyCanister = actor {
    addTally(args : AddTallyArgs) : async Result.Result<TallyId, Text> 
  };

}