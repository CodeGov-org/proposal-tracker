import ProposalService "./ProposalService";
import PT "./ProposalTypes";
import Map "mo:map/Map";
import Result "mo:base/Result";
actor class ProposalTrackerBackend() = {

  let proposalService = ProposalService.init();

  public func start() : async () {
    await* ProposalService.initTimer(proposalService, null);
  };

  public func testGet() : async PT.ProposalService {

    return proposalService;
  };

  public func testAddService() : async Result.Result<(), Text> {

    await* ProposalService.addService(proposalService, "rrkah-fqaaa-aaaaa-aaaaq-cai", null);
  };
  
  public query func greet(name : Text) : async Text {
    return "Hello, " # name # "!";
  };
};
