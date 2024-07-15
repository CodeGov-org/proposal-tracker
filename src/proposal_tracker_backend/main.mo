import TS "./Tracker/TrackerService";
import TR "./Tracker/TrackerRepository";
import Map "mo:map/Map";
import { nhash; thash } "mo:map/Map";
import Option "mo:base/Option";
import Time "mo:base/Time";
import Array "mo:base/Array";
import Result "mo:base/Result";
import Timer "mo:base/Timer";
import G "./Governance/GovernanceTypes";
import GS "./Governance/GovernanceService";
import FakeGovernance "./Governance/FakeGovernanceService";
import PT "./Proposal/ProposalTypes";
import TT "./Tracker/TrackerTypes";
import PM "./Proposal/ProposalMappings";
import Fuzz "mo:fuzz";
import Nat64 "mo:base/Nat64";
import Nat "mo:base/Nat";
import Debug "mo:base/Debug";
import Buffer "mo:base/Buffer";
import Principal "mo:base/Principal";
import LogService "./Log/LogService";
import LT "./Log/LogTypes";
import TallyService "./Tally/TallyService";

actor class ProposalTrackerBackend() = {

  stable let logs = LogService.initLogModel();
  let logService = LogService.LogServiceImpl(logs, 100, true);
  stable let trackerData = TR.init();
  let trackerRepository = TR.TrackerRepository(trackerData, logService);
  //TEST ONLY
  let governanceService = FakeGovernance.FakeGovernanceService();
  //let governanceService = GS.GovernanceService();
  let trackerService = TS.TrackerService(trackerRepository, governanceService, logService, {
    cleanupStrategy = #DeleteAfterTime(#Days(7));
  });

  stable let tallyModel = TallyService.initTallyModel();
  let tallyService = TallyService.TallyService(tallyModel, logService, governanceService, trackerService);

  // public func start() : async Result.Result<(), Text> {
  //   await* trackerService.initTimer(?300, func(governanceId, new, updated) : () {
  //     Debug.print("Tick");
  //     Debug.print("new proposals: " # debug_show(new));
  //     Debug.print("updated proposals: " # debug_show(updated));
  //     Debug.print("governanceId: " # governanceId);
  //   });
  // };

  system func postupgrade() {
    if(Option.isSome(tallyModel.timerId)){
        tallyModel.timerId := ?Timer.recurringTimer<system>(#seconds(5* 60), func() : async () {
        await* tallyService.fetchProposalsAndUpdate()
      });
    }
  };

   public func addTally(args : TallyService.AddTallyArgs) : async Result.Result<(), Text>{
    #ok();
   };

  // TEST ENDPOINTS

  public func testApproveProposal() : async (){
    let proposalId = governanceService.addProposal(13, #Open);
    let neurons = Buffer.Buffer<Nat64>(10);
    neurons.add(governanceService.addNeuron());
    neurons.add(governanceService.addNeuron());
    neurons.add(governanceService.addNeuron());
    neurons.add(governanceService.addNeuron());

    ignore await* tallyService.addTally({
      governanceId = "test";
      topics = [13];
      neurons = Buffer.toArray(neurons);
      subscriber =?Principal.fromText("7g2oq-raaaa-aaaap-qb7sq-cai");
    });


    await* tallyService.fetchProposalsAndUpdate();


    for(neuron in neurons.vals()){
      ignore governanceService.voteWithNeuronOnProposal(neuron, proposalId, #Yes);
    };

    await* tallyService.fetchProposalsAndUpdate();

  };

  

  public func testRunUpdate() : async (){
   await* tallyService.fetchProposalsAndUpdate()
  };

  public func getProposals(canisterId: Text, after : ?PT.ProposalId, topics : TT.TopicStrategy) : async Result.Result<TT.GetProposalResponse, TT.GetProposalError> {
    trackerService.getProposals(canisterId, after, topics);
  };

  public func testSetLowestActiveId(canisterId: Text, id : ?Nat64) : async Result.Result<(), Text> {
    let tc = Map.get(trackerData.trackedCanisters, thash, canisterId);
    switch(tc) {
      case(?e){
        e.lowestActiveProposalId := id;
        #ok()
      };
      case(_){
        #err("Canister not found")
      }
    }
    
  };

  public func testGetLowestActiveId(canisterId: Text,) : async Result.Result<?Nat64, Text>{
    let tc = Map.get(trackerData.trackedCanisters, thash, canisterId);
    switch(tc) {
      case(?e){
        #ok(e.lowestActiveProposalId)
      };
      case(_){
        #err("Canister not found")
      }
    }
  };

  // public func testAddService() : async Result.Result<(), Text> {
  //   await* trackerService.addGovernance("rrkah-fqaaa-aaaaa-aaaaq-cai", #All);
  // };

  //////////////////////////
  ////////////////// LOGS
  //////////////////////////
  public func getLogs(filter : ?LT.LogFilter) : async [LT.Log] {
    logService.getLogs(filter);
  };

  public func clearLogs() : async Result.Result<(), Text> {
    // if (not G.isCustodian(caller, custodians)) {
    //   return #err("Not authorized");
    // };
    logService.clearLogs();
    #ok()
  };

  // public func testGetProposals() : async [ PT.Proposal] {

  //     let gc : G.GovernanceCanister = actor ("rrkah-fqaaa-aaaaa-aaaaq-cai");
  //     let res = await gc.list_proposals({
  //         include_reward_status = [];
  //         omit_large_fields = ?true;
  //         before_proposal = null;
  //         limit = 50;
  //         exclude_topic = [];
  //         include_all_manage_neuron_proposals = null;
  //         include_status = [];
  //     });

  //     //process delta
  //     let newProposals = PM.mapGetProposals(res.proposal_info);
  //     newProposals
  // };
  
};
