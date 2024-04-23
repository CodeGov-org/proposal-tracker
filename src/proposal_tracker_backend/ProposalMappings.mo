import Option "mo:base/Option";
import Array "mo:base/Array";
import Result "mo:base/Result";
import Nat64 "mo:base/Nat64";
import Buffer "mo:base/Buffer";
import G "./GovernanceTypes";
import PT "./ProposalTypes";


module{

    func mapStatus(nnsStatus : Int32) : Result.Result<PT.ProposalStatus, Text>{
        switch(nnsStatus){
            case(0){#ok(#Pending)};
            case(1){#ok(#Approved)};
            case(2){#ok(#Rejected)};
            case(_){#err("Unknown proposal status")}
        }
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
            description = null;
            proposer = proposer.id;
            timestamp = nnsProposal.proposal_timestamp_seconds;
            status = status
        })
     };

     public func mapGetProposals(nnsProposals : [G.ProposalInfo]) : [PT.Proposal] {
        var proposals = Buffer.Buffer<PT.Proposal>(50);
        for (nnsProposal in Array.vals(nnsProposals)) {
            switch (mapProposal(nnsProposal)) {
                case (#ok(proposal)) { proposals.add(proposal)};
                case (#err(err)) {
                    //TODO: log
                };
            };
        };
        Buffer.toArray(proposals)
    };
}