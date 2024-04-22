import Time "mo:base/Time";
import Map "mo:map/Map";

module {
    public type Proposal = {
        id : Nat;
        title : Text;
        description : ?Text;
        proposer : Principal;
        timestamp : Time.Time;
        status : { #Pending; #Approved; #Rejected };
    };

    public type ServiceData = {
        topics : [Nat];
        name : ?Text;
        proposals : [Proposal];
        lastId : Nat;
    };

    public type ProposalJob = {
        id : Nat;
        description : ?Text;
        f : (ServiceData, [Proposal]) -> ();
    };

    public type ProposalService = {
        services : Map.Map<Principal, ServiceData>;
        tickrate : Nat;
        timerId : ?Nat;
        jobs : [ProposalJob];
    };
}