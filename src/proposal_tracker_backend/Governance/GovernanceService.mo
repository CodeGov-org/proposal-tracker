import GT "./GovernanceTypes";
import Result "mo:base/Result";

module {
    public class GovernanceService() {
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
        }
    }

}