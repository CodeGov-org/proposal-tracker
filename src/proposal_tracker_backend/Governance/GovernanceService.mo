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

        public func getSNSMetadata(governanceId : Text) : async* Result.Result<( {url: ?Text; logo:?Text; name:?Text; description:?Text}), Text>{

            //NNS has no get_metadata method, plus its id never changes 
            if(governanceId == NNS_GOVERNANCE_ID){
                return #err("NNS does not have a get_metadata method");
            };

            //verify canister exists and is a governance canister
            let gc : GT.GovernanceCanister = actor(governanceId);
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