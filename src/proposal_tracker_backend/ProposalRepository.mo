import PT "./ProposalTypes";
module {
    type ProposalRepository = {
        getProposalById : (PT.ProposalService, Principal, Nat) -> (PT.Proposal);
        getProposals : (PT.ProposalService, Principal) -> [PT.Proposal];
        addProposal : (PT.ProposalService, Principal, PT.Proposal) -> ();
        updateProposal : (PT.ProposalService, Principal, PT.Proposal) -> ();
        updateProposals : (PT.ProposalService, Principal, [PT.Proposal]) -> ();
        deleteProposalById : (PT.ProposalService, Principal, Nat) -> ();
    };
}