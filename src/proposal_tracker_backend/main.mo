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
import TT "./Tracker/TrackerTypes";
import PM "./Proposal/ProposalMappings";
import Fuzz "mo:fuzz";
import Nat64 "mo:base/Nat64";
import Nat "mo:base/Nat";
import Debug "mo:base/Debug";
import NS "./Notifier/ProposalNotifierService";
actor class ProposalTrackerBackend() = {

  //TODO: reset timer after upgrade


  stable let trackerData = TR.init();
  let trackerRepository = TR.TrackerRepository(trackerData);
  let governanceService = GS.GovernanceService();
  let trackerService = TS.TrackerService(trackerRepository, governanceService, {
    cleanupStrategy = #DeleteAfterTime(#Days(7));
  });

  public func start() : async Result.Result<(), Text> {
    await* trackerService.initTimer(?300, func(governanceId, new, updated) : () {
      Debug.print("Tick");
      Debug.print("new proposals: " # debug_show(new));
      Debug.print("updated proposals: " # debug_show(updated));
      Debug.print("governanceId: " # governanceId);
     //ProposalNotifierService.notify(governanceId, new, executed);
    });
  };

  public func getProposals(canisterId: Text, after : ?PT.ProposalId, topics : [Int32]) : async Result.Result<TT.GetProposalResponse, TT.GetProposalError> {
    trackerService.getProposals(canisterId, after, topics);
  };

  public func testAddService() : async Result.Result<(), Text> {
    await* trackerService.addGovernance("rrkah-fqaaa-aaaaa-aaaaq-cai", #All);
  };

  public func testSetLowestActiveId(canisterId: Text, id : ?Nat) : async Result.Result<(), Text> {
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

  public func testGetLowestActiveId(canisterId: Text,) : async Result.Result<?Nat, Text>{
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


  public func testRunUpdate() : async (){
    await trackerService.update(func (i, j, k) : (){});
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
