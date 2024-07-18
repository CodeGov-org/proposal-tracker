import NNSTypes "../External_Canisters/NNS/NNSTypes";
import List "mo:base/List";
import Result "mo:base/Result";
import Buffer "mo:base/Buffer";
import Nat64 "mo:base/Nat64";
import Array "mo:base/Array";
import Time "mo:base/Time";
import Option "mo:base/Option";
import NNSMappings "../External_Canisters/NNS/NNSMappings";
import LogTypes "../Log/LogTypes";

module{

        type Neuron = {
            dissolve_delay_seconds : Nat64;
            var recent_ballots : [NNSTypes.BallotInfo];
            neuron_type : ?Int32;
            created_timestamp_seconds : Nat64;
            state : Int32;
            stake_e8s : Nat64;
            joined_community_fund_timestamp_seconds : ?Nat64;
            retrieved_at_timestamp_seconds : Nat64;
            known_neuron_data : ?NNSTypes.KnownNeuronData;
            voting_power : Nat64;
            age_seconds : Nat64;
        };

        type Proposal = {
            id : ?NNSTypes.NeuronId;
            var status : Int32;
            topic : Int32;
            failure_reason : ?NNSTypes.GovernanceError;
            ballots : [(Nat64, NNSTypes.Ballot)];
            proposal_timestamp_seconds : Nat64;
            reward_event_round : Nat64;
            deadline_timestamp_seconds : ?Nat64;
            failed_timestamp_seconds : Nat64;
            reject_cost_e8s : Nat64;
            derived_proposal_information : ?NNSTypes.DerivedProposalInformation;
            latest_tally : ?NNSTypes.Tally;
            var reward_status : Int32;
            decided_timestamp_seconds : Nat64;
            proposal : ?NNSTypes.Proposal;
            proposer : ?NNSTypes.NeuronId;
            executed_timestamp_seconds : Nat64;
        };

    public class FakeGovernanceService(logService : LogTypes.LogService) {

        var neurons = List.nil<(Nat64, Neuron)>();
        var proposals = List.nil<Proposal>();
        var neuronCount = 0;
        var lastProposalId : Nat64 = 0;
        var lastNeuronId : Nat64 = 0;

        public func listProposals(_ : Text, info :  NNSTypes.ListProposalInfo) : async* Result.Result<NNSTypes.ListProposalInfoResponse, Text>{
            let buf = Buffer.Buffer<NNSTypes.ProposalInfo>(50);
            var count : Nat32 = 0;
            label l for(proposal in List.toIter(proposals)){
                if(count >= info.limit){
                    break l;
                };

                count := count + 1;

                switch(info.before_proposal){
                    case(?before){
                        switch(proposal.id){
                            case(?id){
                                if(id.id < before.id){
                                    buf.add({proposal with status = proposal.status; reward_status = proposal.reward_status;});
                                };
                            };
                            case(_){
                                count := count - 1;
                            };
                        }
                    };
                    case(_){
                        let lastProposal = List.last(proposals);
                        switch(lastProposal){
                            case(?last){
                                buf.add({last with status = last.status; reward_status = last.reward_status;});
                            };
                            case(_){};
                        };
                        break l;
                    };

                };
            };

            #ok({proposal_info = Buffer.toArray(buf)});
        };

        public func listNeurons(_ : Text, args :  NNSTypes.ListNeurons) : async* Result.Result<NNSTypes.ListNeuronsResponse, Text>{
            let buf = Buffer.Buffer<(Nat64, NNSTypes.NeuronInfo)>(50);

            for(neuronId in args.neuron_ids.vals()){
                for((id, neuron) in List.toIter(neurons)){
                    if(id == neuronId){
                        buf.add((id, {neuron with recent_ballots = neuron.recent_ballots}));
                    }
                };
            };

            #ok({neuron_infos = Buffer.toArray(buf); full_neurons = []});
        };

        public func getPendingProposals(_ : Text) : async* Result.Result<[NNSTypes.ProposalInfo], Text>{
            let buf = Buffer.Buffer<NNSTypes.ProposalInfo>(50);
            label l for(proposal in List.toIter(proposals)){
                if(proposal.status == NNSMappings.mapStatusToInt(#Open)){
                    buf.add({proposal with status = proposal.status; reward_status = proposal.reward_status;});
                };
            };

            #ok(Buffer.toArray(buf));
        };

        public func getMetadata(_ : Text) : async* Result.Result<( {name:?Text; description:?Text}), Text>{
            #ok({name = ?"fake governance"; description = ?"fake governance description"});
        };
        
        public func getGovernanceFunctions(_ : Text) : async* Result.Result<NNSTypes.ListNervousSystemFunctionsResponse, Text>{
            #ok({
                reserved_ids = [1,2,3,4,5,6,7,8,9,10,11,12,13];
                functions = [];
            });
        };

        public func addNeuronWithId(id : Nat64) : Nat64 {
            if(Option.isSome(List.find(neurons, func (n : (Nat64, Neuron)) : Bool {
                n.0 == id
                }))){
                return id
            };

            if(id > lastNeuronId){
                lastNeuronId := id;
            } else {
                lastNeuronId := lastNeuronId + 1;
            };

            neuronCount := neuronCount + 1;
            let neuron : Neuron = {
                id = ?{id = id};
                age_seconds = 0;
                created_timestamp_seconds = 1609459200;
                dissolve_delay_seconds = 0;
                known_neuron_data = null;
                joined_community_fund_timestamp_seconds = null;
                neuron_type = null;
                var recent_ballots = [];
                retrieved_at_timestamp_seconds = 1609459200;
                stake_e8s = 0;
                state = 0;
                voting_power = 0;
            };

            neurons := List.push((lastNeuronId, neuron), neurons);

            lastNeuronId
        };

        public func addProposalWithId(id : Nat64, topicId : Int32, status : NNSMappings.ProposalStatus) : Nat64 {
            if(Option.isSome(List.find(proposals, func (p : Proposal) : Bool {
                isNeuronIdEqual(p.id, id)
                })
            )){
                return id
            };

            if(id > lastProposalId){
                lastProposalId := id;
            } else {
                lastProposalId := lastProposalId + 1;
            };

            
            let proposal : Proposal = {
                id = ?{id = id};
                topic = topicId;
                var status = NNSMappings.mapStatusToInt(status);
                failure_reason = null;
                ballots = [];
                proposal_timestamp_seconds = 1609459200;
                reward_event_round = 0;
                deadline_timestamp_seconds = null;
                failed_timestamp_seconds = 0;
                reject_cost_e8s = 0;
                derived_proposal_information = null;
                latest_tally = null;
                var reward_status = 1;
                decided_timestamp_seconds = 0;
                proposal = ?{
                    url = "";
                    title = ?("Test Proposal N: " # Nat64.toText(lastProposalId));
                    action = null;
                    summary = "Test Proposal N: " # Nat64.toText(lastProposalId);
                };
                proposer = ?{id = lastProposalId};
                executed_timestamp_seconds = 0;

            };

            proposals := List.append(proposals, List.make<Proposal>(proposal));

            lastProposalId


        };

        public func addProposal(topicId : Int32, status : NNSMappings.ProposalStatus) : Nat64 {
            addProposalWithId(lastProposalId + 1, topicId, status)
        };

        public func addNeuron() : Nat64 {
            addNeuronWithId(lastNeuronId + 1)
        };

        public func voteWithNeuronOnProposal(neuronId : Nat64, proposalId : Nat64, vote : NNSMappings.NNSVote) : Result.Result<(), Text>{
            let #ok(neuron) = Result.fromOption(getNeuronWithId(neuronId), "Neuron not found")
            else{
                logService.logError("Neuron not found", ?"[voteWithNeuronOnProposal]");
                return #err("Neuron not found");
            };

            for(ballot in neuron.1.recent_ballots.vals()){
                if(isNeuronIdEqual(ballot.proposal_id, proposalId)){
                    logService.logError("Already voted on this proposa", ?"[voteWithNeuronOnProposal]");
                    return #err("Already voted on this proposal");
                };
            };

            
            //update neuron ballots
            neuron.1.recent_ballots := Array.append(neuron.1.recent_ballots, [{vote = NNSMappings.mapVoteToInt(vote); proposal_id = ?{id = proposalId}}]);


            let #ok(status) = processProposalState(proposalId)
            else{
                logService.logError("Error in processProposalState proposalid : " # Nat64.toText(proposalId) # " neuronId: " # Nat64.toText(neuronId), ?"[voteWithNeuronOnProposal]");
                return #err("Error in processProposalState");
            };

            updateProposalState(proposalId, status);
            #ok()
        };


        //to be used to simulate execution or reject if not enough votes have been cast
        public func terminateProposal(proposalId : Nat64) : Result.Result<(), Text>{
            let #ok(proposal) = Result.fromOption(getProposalWithId(proposalId), "")
            else{
                return #err("Proposal not found");
            };
            
            let #ok(status) = NNSMappings.tryMapStatusFromInt(proposal.status)
            else{
                return #err("Proposal has invalid status id");
            };

            if(status == #Open){
                proposal.status := NNSMappings.mapStatusToInt(#Rejected);
            };

            if(status == #Accepted){
                proposal.status := NNSMappings.mapStatusToInt(#Executed);
            };

            proposal.reward_status := NNSMappings.mapRewardStatusToInt(#Settled);

            #ok()
        };

        func processProposalState(proposalId : Nat64) : Result.Result<NNSMappings.ProposalStatus, Text>{
            let p = getProposalWithId(proposalId);
            switch(p){
                case(?proposal){
                    var approves = 0;
                    var rejects = 0;
                    var status : NNSMappings.ProposalStatus = #Open;

                    for(neuron in List.toIter(neurons)){
                        for(ballot in neuron.1.recent_ballots.vals()){
                            if(isNeuronIdEqual(ballot.proposal_id, proposalId)){
                                switch(ballot.vote){
                                    case(1){
                                        approves := approves + 1;
                                    };
                                    case(2){
                                        rejects := rejects + 1;
                                    };
                                    case(_){};
                                };
                            };
                        };
                    };

                if(approves > neuronCount / 2){
                    status := #Accepted;
                } else if (rejects > neuronCount / 2) {
                    status := #Rejected;
                };

                #ok(status);

                };
                case(_){
                    #err("Proposal not found");
                };
            };
        };

        func updateProposalState(proposalId : Nat64, newState : NNSMappings.ProposalStatus) : (){
             let proposal = getProposalWithId(proposalId);
            switch(proposal){
                case(?proposal){
                    proposal.status := NNSMappings.mapStatusToInt(newState);
                    if(newState == #Accepted or newState == #Rejected or newState == #Executed){
                        proposal.reward_status := NNSMappings.mapRewardStatusToInt(#ReadyToSettle);
                    };
                };
                case(_){};
            }
        };

        public func getProposalWithId(proposalId : Nat64) : ?Proposal{
            for(proposal in List.toIter(proposals)){
                if(isNeuronIdEqual(proposal.id, proposalId)){
                    return ?proposal;
                }
            };
            return null;
        };

        func getNeuronWithId(neuronId : Nat64) : ?(Nat64, Neuron){
            for(neuron in List.toIter(neurons)){
                if(neuron.0 == neuronId){
                    return ?neuron;
                }
            };
            return null;
        };


        func isNeuronIdEqual(a : ?NNSTypes.NeuronId, b : Nat64) : Bool {
            switch(a){
                case(?id){
                    return id.id == b;
                };
                case(_){false};
            };
        };
    };

}