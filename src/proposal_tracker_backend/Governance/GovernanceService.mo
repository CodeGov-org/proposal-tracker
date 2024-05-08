import GT "./GovernanceTypes";
import Result "mo:base/Result";
import Buffer "mo:base/Buffer";
import Array "mo:base/Array";
import Iter "mo:base/Iter";

module {
    public class GovernanceService() {
        let BATCH_SIZE_LIMIT = 50;
        let NNS_GOVERNANCE_ID = "rrkah-fqaaa-aaaaa-aaaaq-cai";
        
        public func listProposals(governanceId : Text, info :  GT.ListProposalInfo) : async* Result.Result<GT.ListProposalInfoResponse, Text>{
            let gc : GT.GovernanceCanister = actor(governanceId);
            try{
                let res = await gc.list_proposals(info);
                #ok(res)
            } catch(e){
                return #err("Protocol excpetion");
            }
        };

        public func getMetadata(governanceId : Text) : async* Result.Result<( {name:?Text; description:?Text}), Text>{
            //verify canister exists and is a governance canister
            let gc : GT.GovernanceCanister = actor(governanceId);
            if (governanceId == NNS_GOVERNANCE_ID){
               return #ok({name = ?"NNS"; description = ?"Network Nervous System"})
            };

            try {
                let res = await gc.get_metadata();
                #ok(res)
            } catch(e){
                return #err("Not a governance canister");
            };   
        };

        public func listProposalsAfterId(governanceId : Text, until : ?Nat, info :  GT.ListProposalInfo) : async* Result.Result<GT.ListProposalInfoResponse, Text>{
            switch(until){
                case(?until){
                    let proposalBuffer = Buffer.Buffer<GT.ProposalInfo>(BATCH_SIZE_LIMIT);
                    
                    label sync loop {
                        let res = await* listProposals(governanceId, info);
                        switch(res){
                            case(#ok(res)){
                                if(Array.size(res.proposal_info) < BATCH_SIZE_LIMIT){
                                    break sync;
                                };
                                for (proposal in Array.vals(res.proposal_info)){
                                    proposalBuffer.add(proposal);
                                };
                            };
                            case(#err(err)){
                                return #err(err);
                            };
                    };
                };
                #ok({proposal_info = Buffer.toArray(proposalBuffer)}); 
                };

                case(_){
                    let res = await* listProposals(governanceId, info);
                    return res
                };
            };
        };
    }

}