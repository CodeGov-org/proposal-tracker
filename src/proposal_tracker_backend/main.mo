import TS "./Tracker/TrackerService";
import TR "./Tracker/TrackerRepository";
import Map "mo:map/Map";
import { nhash; thash } "mo:map/Map";
import Option "mo:base/Option";
import Time "mo:base/Time";
import Array "mo:base/Array";
import Result "mo:base/Result";
import Timer "mo:base/Timer";
import NNSTypes "./External_Canisters/NNS/NNSTypes";
import G "./guards";
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
import List "mo:base/List";
import LogService "./Log/LogService";
import LT "./Log/LogTypes";
import TallyService "./Tally/TallyService";
import TallyTypes "./Tally/TallyTypes";

shared ({ caller }) actor class ProposalTrackerBackend() = {

  stable let logs = LogService.initLogModel();
  stable var custodians = List.make<Principal>(caller);

  let logService = LogService.LogServiceImpl(logs, 100, true);
  stable let trackerData = TR.init();
  let trackerRepository = TR.TrackerRepository(trackerData, logService);
  //TEST ONLY
  let fakeGovernanceService = FakeGovernance.FakeGovernanceService(logService);
  let governanceService = GS.GovernanceService();
  let trackerService = TS.TrackerService(trackerRepository, governanceService, logService, {
    cleanupStrategy = #DeleteAfterTime(#Days(7));
  });

  stable let tallyModel = TallyService.initTallyModel();
  let tallyService = TallyService.TallyService(tallyModel, logService, governanceService, trackerService);

  system func postupgrade() {
    if(Option.isSome(tallyModel.timerId)){
        tallyModel.timerId := ?Timer.recurringTimer<system>(#seconds(5* 60), func() : async () {
        await* tallyService.fetchProposalsAndUpdate()
      });
    }
  };

  public shared ({ caller }) func initTimer(tickrateInSeconds : ?Nat) : async Result.Result<(), Text>{
    if (not G.isCustodian(caller, custodians)) {
        return #err("Not authorized");
    };

    await tallyService.init(tickrateInSeconds);
  };

   public shared ({ caller }) func addTally(args : TallyService.AddTallyArgs) : async Result.Result<TallyTypes.TallyId, Text>{
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized");
    };
    await* tallyService.addTally(args)
   };

   public shared ({ caller }) func getTally(tallyId : TallyTypes.TallyId) : async Result.Result<TallyTypes.TallyInfo, Text> {
       switch(tallyService.getTally(tallyId)){
        case(?t){
          let neuronBuffer = Buffer.Buffer<TallyTypes.NeuronId>(0);
          let topicBufer = Buffer.Buffer<Int32>(0);
          for(topic in Map.keys(t.topics)){
            topicBufer.add(topic);
          };

          for(neuron in Map.keys(t.neurons)){
            neuronBuffer.add(neuron);
          };

          #ok({
              tallyId = t.id;
              alias = t.alias;
              topics = Buffer.toArray(topicBufer);
              neurons= Buffer.toArray(neuronBuffer);
          })
        };
        case(_){
          #err("Tally not found")
        };
       }
    };

    public shared ({ caller }) func deleteTally(tallyId : TallyTypes.TallyId) : async Result.Result<(), Text> {
      if (not G.isCustodian(caller, custodians)) {
        return #err("Not authorized");
      };

      tallyService.deleteTally(tallyId)
    };

  public shared ({ caller }) func updateTally(tallyId : TallyTypes.TallyId, newTally : {topics : [TallyTypes.TopicId]; neurons : [TallyTypes.NeuronId] }) : async Result.Result<(), Text> {
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized");
    };

    tallyService.updateTally(tallyId, newTally)
  };

  public shared ({ caller }) func getSubscribersByTallyId(tallyId : TallyTypes.TallyId) : async [Principal] {
    tallyService.getSubscribersByTallyId(tallyId)
  };

  public shared ({ caller }) func getTalliesByPrincipal(principal : Principal) : async Result.Result<[{id : Text; alias : ?Text}], Text> {
    tallyService.getTalliesByPrincipal(principal)
  };
  
   public shared ({ caller }) func addSubscriber(subscriber : Principal, tallyId : TallyTypes.TallyId) : async Result.Result<(), Text> {
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized");
    };

    tallyService.addSubscriber(subscriber, tallyId)
   };

   public shared ({ caller }) func deleteSubscriber(subscriber : Principal, tallyId : TallyTypes.TallyId) : async Result.Result<(), Text>{
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized");
    };

    tallyService.deleteSubscriber(subscriber, tallyId)
   };

  
  // TEST ENDPOINTS

  // public func testApproveProposal() : async (){
  //   let proposalId = fakeGovernanceService.addProposal(13, #Open);
  //   let neurons = Buffer.Buffer<TallyTypes.NeuronId>(10);
  //   neurons.add(Nat64.toText(fakeGovernanceService.addNeuron()));
  //   neurons.add(Nat64.toText(fakeGovernanceService.addNeuron()));
  //   neurons.add(Nat64.toText(fakeGovernanceService.addNeuron()));
  //   neurons.add(Nat64.toText(fakeGovernanceService.addNeuron()));

  //   ignore await* tallyService.addTally({
  //     governanceId = "7g2oq-raaaa-aaaap-qb7sq-cai";
  //     alias = ?"Test Tally";
  //     topics = [13];
  //     neurons = Buffer.toArray(neurons);
  //     subscriber = Principal.fromText("7g2oq-raaaa-aaaap-qb7sq-cai");
  //   });


  //   await* tallyService.fetchProposalsAndUpdate();


  //   for(neuron in neurons.vals()){
  //     ignore fakeGovernanceService.voteWithNeuronOnProposal(neuron, proposalId, #Yes);
  //   };

  //   await* tallyService.fetchProposalsAndUpdate();

  // };

  // public func testAddMockTally() : async Result.Result<TallyTypes.TallyId, Text>{
  //   let neurons = Buffer.Buffer<TallyTypes.NeuronId>(10);
  //   neurons.add(fakeGovernanceService.addNeuron());
  //   neurons.add(fakeGovernanceService.addNeuron());
  //   neurons.add(fakeGovernanceService.addNeuron());
  //   neurons.add(fakeGovernanceService.addNeuron());

  //   await* tallyService.addTally({
  //     governanceId = "7g2oq-raaaa-aaaap-qb7sq-cai";
  //     alias = ?"Test Tally";
  //     topics = [13];
  //     neurons = Buffer.toArray(neurons);
  //     subscriber = Principal.fromText("7g2oq-raaaa-aaaap-qb7sq-cai");
  //   });
  // };

  // public func testAddCodegovTally() : async Result.Result<TallyTypes.TallyId, Text>{
  //   let codegovNeurons : [TallyTypes.NeuronId] = [118900764328536345, 12979846186887799326, 2692859404205778191, 16405079610149095765, 16459595263909468577, 6542438359604605534, 14998600334911702241, 739503821726316206];

  //   for(neuron in codegovNeurons.vals()){
  //     ignore fakeGovernanceService.addNeuronWithId(neuron);
  //   }; 

  //   await* tallyService.addTally({
  //     governanceId = "rrkah-fqaaa-aaaaa-aaaaq-cai";
  //     alias = ?"Codegov";
  //     topics = [1,2,3,4,5,6,7,8,9,10,11,12,13];
  //     neurons = codegovNeurons;
  //     subscriber = Principal.fromText("7g2oq-raaaa-aaaap-qb7sq-cai");
  //   });
  // };

  // public func testVoteWithTallyOnProposal(tallyId : Text, proposalId : Nat64, vote : {#No; #Unspecified; #Yes}) : async Result.Result<(), Text>{
  //   let t = tallyService.getTally(tallyId);
  //   switch(t){
  //     case(?tally){
  //       for(neuronId in Map.keys(tally.neurons)){
  //         ignore fakeGovernanceService.voteWithNeuronOnProposal(neuronId, proposalId, vote);
  //       };
  //       #ok()
  //     };
  //     case(_){
  //       #err("Tally not found")
  //     };
  //   };
  // };

  public func testRunUpdate() : async (){
   await* tallyService.fetchProposalsAndUpdate()
  };

  public func testTerminateProposal(proposalId : Nat64) : async Result.Result<(), Text>{
    fakeGovernanceService.terminateProposal(proposalId);
  };

  public func testFetchProposalsAndUpdate() : async (){
    await* tallyService.fetchProposalsAndUpdate();
  };

  public func testAddMockPendingProposal(id : ?Nat64) : async Nat64{
    switch(id){
      case(?unwrapId){
        fakeGovernanceService.addProposalWithId(unwrapId, 13, #Open);
      };
      case(_){
        fakeGovernanceService.addProposal(13, #Open);
      };
    };
  };

  public func testGetMockPendingProposals() : async Result.Result<[NNSTypes.ProposalInfo], Text>{
   await* fakeGovernanceService.getPendingProposals("asa");
  };

  // public func getNeuronWithId(id : TallyTypes.NeuronId) : async Result.Result<Nat64, Text>{
  //   switch(fakeGovernanceService.getNeuronWithId(id)){
  //     case(?neuron){
  //       #ok(neuron.0)
  //     };
  //     case(_){
  //       #err("Neuron not found")
  //     };
  //   };
  // };

  //// TRACKER SERVICE TESTING ENDPOINTS
  public func getProposals(canisterId: Text, after : ?PT.ProposalId, topics : TT.TopicStrategy) : async Result.Result<TT.GetProposalResponse, TT.GetProposalError> {
    trackerService.getProposals(canisterId, after, topics);
  };

  public func testGetMockProposal(id : Nat64) : async Bool{
     switch(fakeGovernanceService.getProposalWithId(id)){
      case(?e){
        true
      };
      case(_){
        false
      };
     }
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

  public func testGetLowestActiveId(canisterId: Text) : async Result.Result<?Nat64, Text>{
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
  ////////////////// ADMIN
  //////////////////////////
  public shared ({ caller }) func addCustodian(new_custodian : Principal) : async Result.Result<Text, Text> {
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized");
    };

    custodians := List.push(new_custodian, custodians);

    return #ok("Custodian Added");
  };

  public shared ({ caller }) func getCustodians() : async List.List<Principal> {
    custodians;
  };

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
