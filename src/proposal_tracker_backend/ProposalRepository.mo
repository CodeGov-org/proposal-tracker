import PT "./ProposalTypes";
module {
    type ProposalRepository = {
        getProposalById : (PT.ProposalService, PT.TextPrincipal, Nat) -> (PT.Proposal);
        getProposals : (PT.ProposalService, PT.TextPrincipal) -> [PT.Proposal];
        addProposal : (PT.ProposalService, PT.TextPrincipal, PT.Proposal) -> ();
        updateProposal : (PT.ProposalService, PT.TextPrincipal, PT.Proposal) -> ();
        updateProposals : (PT.ProposalService, PT.TextPrincipal, [PT.Proposal]) -> ();
        deleteProposalById : (PT.ProposalService, PT.TextPrincipal, Nat) -> ();
    };
}