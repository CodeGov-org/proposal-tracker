
module {
    public type ProposalId = Nat;
    public type Proposal = {
        id : ProposalId;
        title : Text;
        description : ?Text;
        proposer : Nat64;
        timestamp : Nat64;
        status : ProposalStatus;
    };

    public type ProposalStatus = {
        #Pending; #Approved; #Rejected
    };
}