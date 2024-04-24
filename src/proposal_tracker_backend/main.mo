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
import PT "./Proposal/ProposalTypes";
import PM "./Proposal/ProposalMappings";
import Fuzz "mo:fuzz";
import Nat64 "mo:base/Nat64";
import Nat "mo:base/Nat";
import Debug "mo:base/Debug";
actor class ProposalTrackerBackend() = {


  stable let trackerData = TR.init();
  let trackerRepository = TR.TrackerRepository(trackerData);
  let governanceService = GS.GovernanceService();
  let trackerService = TS.TrackerService(trackerRepository, governanceService);

  public func start() : async Result.Result<(), Text> {
    await* trackerService.initTimer(null, func(data, delta) :() {
      Debug.print("Tick");
    });
  };

  // public func testGet() : async [(PT.ProposalId, PT.Proposal)] {

  //   switch(Map.get(proposalService.services, thash, "rrkah-fqaaa-aaaaa-aaaaq-cai")){
  //     case(?serviceData){
  //       return Map.toArray(serviceData.proposals);
  //       };
  //       case(_){
  //         return [];
  //       };
  //   };
  // };

  // public func testAddService() : async Result.Result<(), Text> {

  //   await* ProposalService.addService(proposalService, "rrkah-fqaaa-aaaaa-aaaaq-cai", null);
  // };

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
