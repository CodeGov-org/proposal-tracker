import GT "./GovernanceTypes";
import GU "./GovernanceUtils";
import Result "mo:base/Result";
import Buffer "mo:base/Buffer";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Int32 "mo:base/Int32";
import Int64 "mo:base/Int64";
import Option "mo:base/Option";
import Nat64 "mo:base/Nat64";
import Error "mo:base/Error";
import Utils "../utils";

module {
    public class GovernanceService() {
        // let BATCH_SIZE_LIMIT = 50;
        let NNS_GOVERNANCE_ID = "rrkah-fqaaa-aaaaa-aaaaq-cai";
        
        public func listProposals(governanceId : Text, info :  GT.ListProposalInfo) : async* Result.Result<GT.ListProposalInfoResponse, Text>{
            let gc : GT.GovernanceCanister = actor(governanceId);
            try{
                let res = await gc.list_proposals(info);
                #ok(res)
            } catch(e){
                return #err(Error.message(e))
            }
        };

        //todo: change for sns
        public func getPendingProposals(governanceId : Text) : async* Result.Result<[GT.ProposalInfo], Text>{
            let gc : GT.GovernanceCanister = actor(governanceId);
            try{
                let res = await gc.get_pending_proposals();
                #ok(res)
            } catch(e){
               return #err(Error.message(e))
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
                return #err(Error.message(e))
            };   
        };

        public func getGovernanceFunctions(governanceId : Text) : async* Result.Result<GT.ListNervousSystemFunctionsResponse, Text>{
            let gc : GT.GovernanceCanister = actor(governanceId);
            try{
                let res = await gc.list_nervous_system_functions();
                #ok(res)
            } catch(e){
                return #err(Error.message(e))
            }
        };

        public func listNeurons(governanceId : Text, args :  GT.ListNeurons) : async* Result.Result<GT.ListNeuronsResponse, Text>{
            let gc : GT.GovernanceCanister = actor(governanceId);
            try{
                let res = await gc.list_neurons(args);
                #ok(res)
            } catch(e){
                return #err(Error.message(e))
            }
        };
    }

}