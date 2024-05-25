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


    //     public func getValidTopicIds(governanceId : Text) : async* Result.Result<[(Int32, Text, ?Text)], Text>{
    //         if (governanceId == NNS_GOVERNANCE_ID){
    //             return #ok(GU.NNSFunctions);
    //         };
    //         let buf = Buffer.Buffer<(Int32, Text, ?Text)>(50);
    //         let res = await* getGovernanceFunctions(governanceId);
    //         switch(res){
    //             case(#ok(res)){
    //                 for(function in Array.vals(res.functions)){
    //                     buf.add((Int32.fromInt64(Int64.fromNat64(function.id))), function.name, function.description);
    //                 };
    //                 return #ok(Buffer.toArray(buf));
    //             };
    //             case(#err(err)){
    //                 return #err(err);
    //             };
    //         };
    //     };

    //     public func listProposalsAfterId(governanceId : Text, _after : ?Nat, info :  GT.ListProposalInfo) : async* Result.Result<GT.ListProposalInfoResponse, Text>{
    //         let #ok(after) = Utils.optToRes(_after)
    //         else{
    //             return await* listProposals(governanceId, info);
    //         };
            
    //         let proposalBuffer = Buffer.Buffer<GT.ProposalInfo>(BATCH_SIZE_LIMIT);
                    
    //         var curr : ?GT.NeuronId = null;
    //         label sync loop {
    //             let res = await* listProposals(governanceId, {
    //                 info with
    //                 before_proposal = curr
    //             });
    //             switch(res){
    //                 case(#ok(res)){
    //                     var min = res.proposal_info[0].id;
    //                     for (proposal in Array.vals(res.proposal_info)){
    //                         proposalBuffer.add(proposal);

    //                         switch((proposal.id)){
    //                             case((?p)){
    //                                 if(Nat64.toNat(p.id) == after){
    //                                     break sync;
    //                                 };
                                    
    //                                 switch(min){
    //                                     case((?m)){
    //                                         if(p.id < m.id){
    //                                             min := ?p;
    //                                         };
    //                                     };
    //                                     case(_){};
    //                                 }
    //                             };
    //                             case(_){
    //                                 return #err("broken invariant in listProposalsAfterId")
    //                             };
    //                         };

    //                     };
    //                     curr := min;
    //                 };
    //                 case(#err(err)){
    //                     return #err(err);
    //                 };
    //         };
    //     };
    //     #ok({proposal_info = Buffer.toArray(proposalBuffer)}); 
    // }
    }

}