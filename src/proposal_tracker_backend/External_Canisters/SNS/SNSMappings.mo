import Result "mo:base/Result";
import Nat64 "mo:base/Nat64";
import Option "mo:base/Option";
import Text "mo:base/Text";
import Int64 "mo:base/Int64";
import Time "mo:base/Time";
import Util "../../utils";
import SNSTypes "./SNSTypes";
import ProposalTypes "../../Proposal/ProposalTypes";

module {

    //     id : ?ProposalId;
    // payload_text_rendering : ?Text;
    // action : Nat64; //topicID
    // failure_reason : ?GovernanceError;
    // action_auxiliary : ?ActionAuxiliary;
    // ballots : [(Text, Ballot)];
    // minimum_yes_proportion_of_total : ?Percentage;
    // reward_event_round : Nat64;
    // failed_timestamp_seconds : Nat64;
    // reward_event_end_timestamp_seconds : ?Nat64;
    // proposal_creation_timestamp_seconds : Nat64;
    // initial_voting_period_seconds : Nat64;
    // reject_cost_e8s : Nat64;
    // latest_tally : ?Tally;
    // wait_for_quiet_deadline_increase_seconds : Nat64;
    // decided_timestamp_seconds : Nat64;
    // proposal : ?Proposal;
    // proposer : ?NeuronId;
    // wait_for_quiet_state : ?WaitForQuietState;
    // minimum_yes_proportion_of_exercised : ?Percentage;
    // is_eligible_for_rewards : Bool;
    // executed_timestamp_seconds : Nat64;

    let MINIMUM_YES_PROPORTION_OF_EXERCISED_VOTING_POWER : Nat64 = 5000;
    let MINIMUM_YES_PROPORTION_OF_TOTAL_VOTING_POWER : Nat64 = 300;

    public func mapSNSProposalToProposal(snsProposal: SNSTypes.ProposalData): Result.Result<ProposalTypes.ProposalAPI, Text> {

        let id = switch(snsProposal.id){
          case(?_id){_id.id};
          case(_){
            return #err("Proposal has no id")
          };
        };

        let proposer = switch(snsProposal.proposer){
            case(?_proposer){
                let decoded_text: Text = switch (Text.decodeUtf8(_proposer.id)) {
                    case (null) { return #err("Could not decode proposer id") };
                    case (?y) { y };
                };
            };
            case(_){
                return #err("Proposal has no proposer")
            };
        };

        let title = switch(snsProposal.proposal){
            case(?p){p.title};
            case(_){ "" };
        };

        let now = Int64.toNat64(Int64.fromInt(Time.now()));
        let deadline = processDeadline(snsProposal);

        #ok({
            id = id;
            title = title;
            topicId = snsProposal.action;
            description = null;
            proposer = proposer;
            timestamp = now;
            deadlineTimestampSeconds = ?deadline;
            proposalTimestampSeconds = snsProposal.proposal_creation_timestamp_seconds;
            rewardStatus = mapSNSProposalRewardStatus(snsProposal);
            status = mapSNSProposalStatus(snsProposal);
        });

    };

    func mapSNSProposalRewardStatus(snsProposal: SNSTypes.ProposalData): ProposalTypes.ProposalRewardStatus {
    if (Option.isSome(snsProposal.reward_event_end_timestamp_seconds) or snsProposal.reward_event_round > 0) {
        return #Settled;
    };

    let now = Time.now() / 1_000_000_000; // Convert to seconds
    let deadline = switch (snsProposal.wait_for_quiet_state) {
        case (?state) { state.current_deadline_timestamp_seconds };
        case (null) { snsProposal.proposal_creation_timestamp_seconds + snsProposal.initial_voting_period_seconds };
    };

    if (Int64.toNat64(Int64.fromInt(now)) < deadline) {
        return #AcceptVotes;
    };

    if (snsProposal.is_eligible_for_rewards) {
        return #ReadyToSettle;
    };

    return #Settled;
    };

    func mapSNSProposalStatus(snsProposal: SNSTypes.ProposalData): ProposalTypes.ProposalStatus {
        if(snsProposal.decided_timestamp_seconds == 0){
           return #Open;
        };

        if(isAccepted(snsProposal)){
            if (snsProposal.executed_timestamp_seconds > 0) {
            return #Executed;
            };

            if (snsProposal.failed_timestamp_seconds > 0) {
            return #Failed;
            };

            return #Accepted;
        };

        return #Rejected;

    };

    func processDeadline(snsProposal: SNSTypes.ProposalData): Nat64 {
        let deadline = switch (snsProposal.wait_for_quiet_state) {
            case (?state) { state.current_deadline_timestamp_seconds };
            case (null) { snsProposal.proposal_creation_timestamp_seconds + snsProposal.initial_voting_period_seconds };
        };

        return deadline;
    };


    func isAccepted(snsProposal: SNSTypes.ProposalData): Bool {
        let #ok(tally) = Util.optToRes(snsProposal.latest_tally)else {
            return false;
        };

        let total = tally.yes + tally.no;
        let majorityMet = majorityDecision(tally.yes, tally.no, total, minimumYesProportionOfExercised(snsProposal)) == #Yes;

        let quorumMet = tally.yes * 10_000 >= total * minimumYesProportionOfTotal(snsProposal);

        return quorumMet and majorityMet;
    };

    type Vote = {
        #Unspecified; //0
        #Yes; //1
        #No; //2
    };

    func majorityDecision(yes: Nat64, no: Nat64, total: Nat64, requiredYesOfTotalBasisPoints: Nat64): Vote {
        // 10_000n is 100% in basis points
        let requiredNoOfTotalBasisPoints = 10_000 - requiredYesOfTotalBasisPoints;

        if (yes * 10_000 > total * requiredYesOfTotalBasisPoints) {
            return #Yes;
        } else if (no * 10_000 >= total * requiredNoOfTotalBasisPoints) {
            return #No;
        } else {
            return #Unspecified;
        }
    };

    func minimumYesProportionOfExercised(snsProposal: SNSTypes.ProposalData): Nat64 {
    // `minimum_yes_proportion_of_exercised` property could be missing in older canister versions
        switch(fromPercentageBasisPoints(snsProposal.minimum_yes_proportion_of_exercised)){
            case(?v){
                v;
            };
            case(_){
                MINIMUM_YES_PROPORTION_OF_EXERCISED_VOTING_POWER;
            };
        };
    };

    func minimumYesProportionOfTotal(snsProposal: SNSTypes.ProposalData): Nat64 {
        switch(fromPercentageBasisPoints(snsProposal.minimum_yes_proportion_of_total)){
            case(?v){
                v;
            };
            case(_){
                MINIMUM_YES_PROPORTION_OF_TOTAL_VOTING_POWER;
            };
        };
    };


    func fromPercentageBasisPoints(value : ?SNSTypes.Percentage) : ?Nat64 {
        switch(value){
            case(?v){
                v.basis_points;
            };
            case(_){
                null;
            };
        };
    };



}