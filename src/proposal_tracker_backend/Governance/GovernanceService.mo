
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
import NNSTypes "../External_Canisters/NNS/NNSTypes";
import NNSMappings "../External_Canisters/NNS/NNSMappings";
import SNSTypes "../External_Canisters/SNS/SNSTypes";

    // TODO: separate functions and topics
    // Reconciciliate NNS and SNS differences: (no active_proposals endpoint and topics instead of types)
module {
    public class GovernanceService() {
        // let BATCH_SIZE_LIMIT = 50;
        let NNS_GOVERNANCE_ID = "rrkah-fqaaa-aaaaa-aaaaq-cai";
        
        public func listProposals(governanceId : Text, info :  NNSTypes.ListProposalInfo) : async* Result.Result<NNSTypes.ListProposalInfoResponse, Text>{
            let gc : NNSTypes.NNSCanister = actor(governanceId);
            try{
                let res = await gc.list_proposals(info);
                #ok(res)
            } catch(e){
                return #err(Error.message(e))
            }
        };

        //todo: change for sns
        public func getPendingProposals(governanceId : Text) : async* Result.Result<[NNSTypes.ProposalInfo], Text>{
            let gc : NNSTypes.NNSCanister = actor(governanceId);
            try{
                let res = await gc.get_pending_proposals();
                #ok(res)
            } catch(e){
               return #err(Error.message(e))
            }
        };

        public func getMetadata(governanceId : Text) : async* Result.Result<( {name:?Text; description:?Text}), Text>{
            //verify canister exists and is a governance canister
            if (governanceId == NNS_GOVERNANCE_ID){
               return #ok({name = ?"NNS"; description = ?"Network Nervous System"})
            };

            let gc : SNSTypes.SNSCanister = actor(governanceId);
            try {
                let res = await gc.get_metadata({});
                #ok(res)
            } catch(e){
                return #err(Error.message(e))
            };   
        };

        public func getGovernanceFunctions(governanceId : Text) : async* Result.Result<[{id : Nat64;name : Text;description : ?Text;}], Text>{
            if (governanceId == NNS_GOVERNANCE_ID){
               return #ok(NNSMappings.NNSTopics);
            };
            let gc : SNSTypes.SNSCanister = actor(governanceId);
            try{
                let res = await gc.list_nervous_system_functions();
                let buf = Buffer.Buffer<{id : Nat64;name : Text;description : ?Text;}>(Array.size(res.functions));
                for(f in res.functions.vals()){
                    buf.add({id = f.id; name = f.name; description = f.description});
                };
                #ok(Buffer.toArray(buf))
            } catch(e){
                return #err(Error.message(e))
            }
        };

        public func listNeurons(governanceId : Text, args :  NNSTypes.ListNeurons) : async* Result.Result<NNSTypes.ListNeuronsResponse, Text>{
            let gc : NNSTypes.NNSCanister = actor(governanceId);
            try{
                let res = await gc.list_neurons(args);
                #ok(res)
            } catch(e){
                return #err(Error.message(e))
            }
        };
    }

}