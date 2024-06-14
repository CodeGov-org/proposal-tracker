module{

    public let NNSFunctions : [(Int32, Text, ?Text)] = [
        (0, "Unspecified", null),
        (1, "CreateSubnet", null),
        (2, "AddNodeToSubnet", null),
        (3, "NnsCanisterInstall", null),
        (4, "NnsCanisterUpgrade", null),
        (5, "BlessReplicaVersion", null),
        (6, "RecoverSubnet", null),
        (7, "UpdateConfigOfSubnet", null),
        (8, "AssignNoid", null),
        (9, "NnsRootUpgrade", null),
        (10, "IcpXdrConversionRate", null),
        (11, "DeployGuestosToAllSubnetNodes", null),
        (12, "ClearProvisionalWhitelist", null),
        (13, "RemoveNodesFromSubnet", null),
        (14, "SetAuthorizedSubnetworks", null),
        (15, "SetFirewallConfig", null),
        (16, "UpdateNodeOperatorConfig", null),
        (17, "StopOrStartNnsCanister", null),
        (18, "RemoveNodes", null),
        (19, "UninstallCode", null),
        (20, "UpdateNodeRewardsTable", null),
        (21, "AddOrRemoveDataCenters", null),
        (22, "UpdateUnassignedNodesConfig", null),
        (23, "RemoveNodeOperators", null),
        (24, "RerouteCanisterRanges", null),
        (25, "AddFirewallRules", null),
        (26, "RemoveFirewallRules", null),
        (27, "UpdateFirewallRules", null),
        (28, "PrepareCanisterMigration", null),
        (29, "CompleteCanisterMigration", null),
        (30, "AddSnsWasm", null),
        (31, "ChangeSubnetMembership", null),
        (32, "UpdateSubnetType", null),
        (33, "ChangeSubnetTypeAssignment", null),
        (34, "UpdateSnsWasmSnsSubnetIds", null),
        (35, "UpdateAllowedPrincipals", null),
        (36, "RetireReplicaVersion", null),
        (37, "InsertSnsWasmUpgradePathEntries", null),
        (38, "ReviseElectedGuestosVersions", null),
        (39, "BitcoinSetConfig", null),
        (40, "UpdateElectedHostosVersions", null),
        (41, "UpdateNodesHostosVersion", null),
        (42, "HardResetNnsRootToVersion", null),
        (43, "AddApiBoundaryNodes", null),
        (44, "RemoveApiBoundaryNodes", null),
        (46, "UpdateApiBoundaryNodesVersion", null),
        (47, "DeployGuestosToSomeApiBoundaryNodes", null),
        (48, "DeployGuestosToAllUnassignedNodes", null),
        (49, "UpdateSshReadonlyAccessForAllUnassignedNodes", null),
        (50, "ReviseElectedHostosVersions", null),
        (51, "DeployHostosToSomeNodes", null)
    ];

   public type NNSTopic = {
        #Unspecified;
        #ManageNeuron;
        #ExchangeRate;
        #NetworkEconomics;
        #Governance;
        #NodeAdmin;
        #ParticipantManagement;
        #SubnetManagement;
        #NetworkCanisterManagement;
        #Kyc;
        #NodeProviderRewards;
        // @deprecated
        #SnsDecentralizationSale;
        #SubnetReplicaVersionManagement;
        #ReplicaVersionManagement;
        #SnsAndCommunityFund;
        #ApiBoundaryNodeManagement;
        #SubnetRental;
    };

   public type NNSVote = {
        #Unspecified; //0
        #Yes; //1
        #No; //2
    };

    public type ProposalRewardStatus = {
        #Unknown; //0

        // The proposal still accept votes, for the purpose of
        // vote rewards. This implies nothing on the ProposalStatus.
        #AcceptVotes; //1

        // The proposal no longer accepts votes. It is due to settle
        // at the next reward event.
        #ReadyToSettle; //2

        // The proposal has been taken into account in a reward event.
        #Settled; //3

        // The proposal is not eligible to be taken into account in a reward event.
        #Ineligible; //4
    };

    public type ProposalStatus = {
        #Unknown; //0

        // A decision (accept/reject) has yet to be made.
        #Open; //1

        // The proposal has been rejected.
        #Rejected;

        // The proposal has been accepted. At this time, either execution
        // as not yet started, or it has but the outcome is not yet known.
        #Accepted;

        // The proposal was accepted and successfully executed.
        #Executed;

        // The proposal was accepted, but execution failed.
        #Failed;
    }

}
