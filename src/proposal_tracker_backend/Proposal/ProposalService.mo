import GS "../Governance/GovernanceService";
import GT "../Governance/GovernanceTypes";
import GU "../Governance/GovernanceUtils";
import LT "../Log/LogTypes";
import PT "./ProposalTypes";
import Result "mo:base/Result";
import Buffer "mo:base/Buffer";
import Array "mo:base/Array";
import Int32 "mo:base/Int32";
import Int64 "mo:base/Int64";
import Nat64 "mo:base/Nat64";
import Option "mo:base/Option";
import Utils "../utils";
    // TODO: separate functions and topics
    // Reconciciliate NNS and SNS differences: (no active_proposals endpoint and topics instead of types)
    // Status that reflects when proposal no longer accepts votes

module{

    let BATCH_SIZE_LIMIT = 50;
    let NNS_GOVERNANCE_ID = "rrkah-fqaaa-aaaaa-aaaaq-cai";

    public class ProposalService(governanceService : GS.GovernanceService, logService : LT.LogService){
        public func getValidTopicIds(governanceId : Text) : async* Result.Result<[(Int32, Text, ?Text)], Text>{
            if (governanceId == NNS_GOVERNANCE_ID){
                return #ok(GU.NNSFunctions);
            };
            let buf = Buffer.Buffer<(Int32, Text, ?Text)>(50);
            let res = await* governanceService.getGovernanceFunctions(governanceId);
            switch(res){
                case(#ok(res)){
                    for(function in Array.vals(res.functions)){
                        buf.add((Int32.fromInt64(Int64.fromNat64(function.id))), function.name, function.description);
                    };
                    return #ok(Buffer.toArray(buf));
                };
                case(#err(err)){
                    return #err(err);
                };
            };
        };


        public func listProposalsAfterId(governanceId : Text, _after : ?PT.ProposalId, args :  PT.ListProposalArgs) : async* Result.Result<GT.ListProposalInfoResponse, Text>{
            let info = {
                include_reward_status = args.includeRewardStatus;
                omit_large_fields =  args.omitLargeFields;
                before_proposal = null;
                limit : Nat32 = 50;
                exclude_topic = args.excludeTopic;
                include_all_manage_neuron_proposals = args.includeAllManageNeuronProposals;
                include_status = args.includeStatus;
            };
            let #ok(after) = Utils.optToRes(_after)
            else{
                return await* governanceService.listProposals(governanceId, info);
            };
            
            let proposalBuffer = Buffer.Buffer<GT.ProposalInfo>(BATCH_SIZE_LIMIT);
                    
            var curr : ?GT.NeuronId = null;
            label sync loop {
                let res = await* governanceService.listProposals(governanceId, {
                    info with
                    before_proposal = curr
                });
                switch(res){
                    case(#ok(res)){
                        if(Array.size(res.proposal_info) == 0){
                            break sync;
                        };

                        var min = res.proposal_info[0].id;
                        var check = false;
                        for (proposal in Array.vals(res.proposal_info)){
                            switch((proposal.id)){
                                case((?p)){
                                    if(p.id <= after){
                                        check := true;
                                    } else if (p.id > after){
                                        proposalBuffer.add(proposal);
                                    };
                                    
                                    switch(min){
                                        case((?m)){
                                            if(p.id < m.id){
                                                min := ?p;
                                            };
                                        };
                                        case(_){};
                                    }
                                };
                                case(_){
                                    return #err("broken invariant in listProposalsAfterId")
                                };
                            };

                        };
                        if(check){
                            break sync;
                        };
                        curr := min;
                    };
                    case(#err(err)){
                        return #err(err);
                    };
            };
        };
        Buffer.reverse(proposalBuffer);
        #ok({proposal_info = Buffer.toArray(proposalBuffer)}); 
    }
  };

    // public func processIncludeTopics(validTopics : [(Int32, Text, ?Text)], topicsToInclude : [Int32]) : [Int32] {
    //     return Array.mapFilter<(Int32, Text, ?Text), Int32>(validTopics, func (t : (Int32, Text, ?Text)) : ?Int32 {
    //         for(id in Array.vals(topicsToInclude)){
    //             if(id != t.0){
    //                 return ?t.0;
    //             }
    //         };
    //         return null;
    //     });
    // };

    
    public func processIncludeTopics(validTopics : [(Int32, Text, ?Text)], topicsToInclude : [Int32]) : [Int32] {

        let buf = Buffer.Buffer<Int32>(50);
        for(id in Array.vals(validTopics)){
            if(Option.isNull(Array.find(topicsToInclude, func (x : Int32) : Bool { return x == id.0 }))){
                buf.add(id.0);
            };
        };

        Buffer.toArray(buf);
    };


    public func ListProposalArgsDefault() : PT.ListProposalArgs {
        {
            includeRewardStatus = [];
            omitLargeFields = ?true;
            excludeTopic= [];
            includeAllManageNeuronProposals = null;
            includeStatus = [];
        }
    };


}