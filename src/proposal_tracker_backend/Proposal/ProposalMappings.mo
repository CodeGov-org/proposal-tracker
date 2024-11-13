import Option "mo:base/Option";
import Array "mo:base/Array";
import Result "mo:base/Result";
import Nat64 "mo:base/Nat64";
import Buffer "mo:base/Buffer";
import Time "mo:base/Time";
import Int "mo:base/Int";
import Int64 "mo:base/Int64";
import G "../External_Canisters/NNS/NNSTypes";
import PT "./ProposalTypes";


module{

    public func tryMapStatus(nnsStatus : Int32) : Result.Result<PT.ProposalStatus, Text>{
        switch(nnsStatus){
            case(0){#ok(#Unknown)};
            case(1){#ok(#Open)};
            case(2){#ok(#Rejected)};
            case(3){#ok(#Accepted)};
            case(4){#ok(#Executed)};
            case(5){#ok(#Failed)};
            case(_){#err("Unknown proposal status")}
        }
    };


    public func tryMapRewardStatus(nnsStatus : Int32) : Result.Result<PT.ProposalRewardStatus, Text>{
        switch(nnsStatus){
            case(0){#ok(#Unknown)};
            case(1){#ok(#AcceptVotes)};
            case(2){#ok(#ReadyToSettle)};
            case(3){#ok(#Settled)};
            case(4){#ok(#Ineligible)};
            case(_){#err("Unknown proposal status")}
        }
    };


    public func proposalToAPI(p : PT.Proposal) : PT.ProposalAPI {
        {
            p with
            status = p.status;
            deadlineTimestampSeconds = p.deadlineTimestampSeconds;
            rewardStatus = p.rewardStatus;
        };
    };

    public func mapProposal(nnsProposal : G.ProposalInfo) :  Result.Result<PT.Proposal, Text> {

        let id = switch(nnsProposal.id){
          case(?_id){_id.id};
          case(_){
            return #err("Proposal has no id")
          };
        };

        let proposer = switch(nnsProposal.proposer){
            case(?_proposer){_proposer};
            case(_){
                return #err("Proposal has no proposer")
            };
        };

        let title = switch(nnsProposal.proposal){
            case(?p){Option.get(p.title, "")};
            case(_){ "" };
        };

        let #ok(status) = tryMapStatus(nnsProposal.status)
        else {
            return #err("Failed to map proposal status")
        };

        let #ok(rewardStatus) = tryMapRewardStatus(nnsProposal.reward_status)
        else {
            return #err("Failed to map proposal status")
        };

        #ok({
            id = id;
            title = title;
            topicId = nnsProposal.topic;
            description = null;
            proposer = proposer.id;
            timestamp = Int64.toNat64(Int64.fromInt(Time.now()));
            var deadlineTimestampSeconds = nnsProposal.deadline_timestamp_seconds;
            proposalTimestampSeconds = nnsProposal.proposal_timestamp_seconds;
            var rewardStatus = rewardStatus;
            var status = status;
        })
     };

    //TODO: return result
     public func mapGetProposals(nnsProposals : [G.ProposalInfo]) : [PT.Proposal] {
        var proposals = Buffer.Buffer<PT.Proposal>(50);
        for (nnsProposal in Array.vals(nnsProposals)) {
            switch (mapProposal(nnsProposal)) {
                case (#ok(proposal)) { proposals.add(proposal)};
                case (#err(err)) {};
            };
        };
        Buffer.toArray(proposals)
    };
}