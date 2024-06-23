import Option "mo:base/Option";
import Array "mo:base/Array";
import Result "mo:base/Result";
import Nat64 "mo:base/Nat64";
import Buffer "mo:base/Buffer";
import Time "mo:base/Time";
import Int "mo:base/Int";
import Int64 "mo:base/Int64";
import G "../Governance/GovernanceTypes";
import PT "./ProposalTypes";


module{

    func mapStatus(nnsStatus : Int32) : Result.Result<PT.ProposalStatus, Text>{
        //TODO: find these
        switch(nnsStatus){
            case(1){#ok(#Pending)};
            case(4){#ok(#Executed(#Approved))};
            case(2){#ok(#Executed(#Rejected))};
            case(_){#err("Unknown proposal status")}
        }
    };

    public func proposalToAPI(p : PT.Proposal) : PT.ProposalAPI {
        {
            p with
            status = p.status;
            deadlineTimestampSeconds = p.deadlineTimestampSeconds;
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

        let #ok(status) = mapStatus(nnsProposal.status)
        else {
            return #err("Failed to map proposal status")
        };

        #ok({
            id = Nat64.toNat(id);
            title = title;
            topicId = nnsProposal.topic;
            description = null;
            proposer = proposer.id;
            timestamp = Int64.toNat64(Int64.fromInt(Time.now()));
            var deadlineTimestampSeconds = nnsProposal.deadline_timestamp_seconds;
            proposalTimestampSeconds = nnsProposal.proposal_timestamp_seconds;
            var status = status
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