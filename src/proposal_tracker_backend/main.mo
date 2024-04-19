actor class ProposalTrackerBackend() = {
  public query func greet(name : Text) : async Text {
    return "Hello, " # name # "!";
  };
};
