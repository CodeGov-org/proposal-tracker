import Time "mo:base/Time";
import Map "mo:map/Map";

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

    public type ServiceData = {
        topics : [Nat];
        name : ?Text;
        proposals : Map.Map<ProposalId, Proposal>;
        lastProposalId : Nat;
    };

    public type ProposalServiceJob = {
        id : ProposalId;
        description : ?Text;
        task : (ServiceData, [Proposal]) -> (); //each task is provided with updated data for each governance service and the delta of the last update
    };

    public type TextPrincipal = Text;
    public type ProposalService = {
        services : Map.Map<TextPrincipal, ServiceData>;
        var tickrate : Nat;
        var timerId : ?Nat;
        var jobs : [ProposalServiceJob];
    };
}