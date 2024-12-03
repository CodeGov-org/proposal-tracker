import GS "../Governance/GovernanceService";
import GT "../External_Canisters/NNS/NNSTypes";
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
module{

    let BATCH_SIZE_LIMIT = 50;
    let NNS_GOVERNANCE_ID = "rrkah-fqaaa-aaaaa-aaaaq-cai";

    public class ProposalService(governanceService : GS.GovernanceService, logService : LT.LogService){


        public func listProposalsFromId(governanceId : Text, _from : ?PT.ProposalId, args :  PT.ListProposalArgs) : async* Result.Result<GT.ListProposalInfoResponse, Text>{
            let info = {
                include_reward_status = args.includeRewardStatus;
                omit_large_fields =  args.omitLargeFields;
                before_proposal = null;
                limit : Nat32 = 50;
                exclude_topic = args.excludeTopic;
                include_all_manage_neuron_proposals = args.includeAllManageNeuronProposals;
                include_status = args.includeStatus;
            };
            let #ok(from) = Utils.optToRes(_from)
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
                                    if(p.id < from){
                                        check := true;
                                    } else if (p.id >= from){
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
    
    public func processIncludeTopics(validTopics : [{id : Nat64;name : Text;description : ?Text;}], topicsToInclude : [Nat64]) : [Nat64] {

        let buf = Buffer.Buffer<Nat64>(50);
        for(id in Array.vals(validTopics)){
            if(Option.isNull(Array.find(topicsToInclude, func (x : Nat64) : Bool { return x == id.id }))){
                buf.add(id.id);
            };
        };

        Buffer.toArray(buf);
    };


    public func listProposalArgsDefault() : PT.ListProposalArgs {
        {
            includeRewardStatus = [];
            omitLargeFields = ?true;
            excludeTopic= [];
            includeAllManageNeuronProposals = null;
            includeStatus = [];
        }
    };


}