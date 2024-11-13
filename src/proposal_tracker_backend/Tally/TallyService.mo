import Map "mo:map/Map";
import Result "mo:base/Result";
import List "mo:base/List";
import Buffer "mo:base/Buffer";
import Nat64 "mo:base/Nat64";
import Option "mo:base/Option";
import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Debug "mo:base/Debug";
import Timer "mo:base/Timer";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import PT "../Proposal/ProposalTypes";
import { nhash; thash; phash; n64hash; i32hash} "mo:map/Map";
import GS "../Governance/GovernanceService";
import LT "../Log/LogTypes";
import GT "../External_Canisters/NNS/NNSTypes";
import TT "../Tracker/TrackerTypes";
import TallyTypes "../Tally/TallyTypes";
import Utils "../utils";
import NNSMappings "../External_Canisters/NNS/NNSMappings";

module {

    public type TallyFeed = {
        tallyId : Text;
        proposalId : Nat;
        votes : [TallyTypes.VoteRecord];
        proposalStatus : PT.ProposalStatus;
        governanceId : Text;
        tallyStatus : TallyTypes.Vote;
    };

    public type AddTallyArgs = TallyTypes.AddTallyArgs;
    
    public type NeuronVote = {
        #Abstained;
        #Pending;
        #Yes;
        #No;
    };

    type GovernanceId = TallyTypes.GovernanceId;
    type NeuronId = TallyTypes.NeuronId;
    type TallyId = TallyTypes.TallyId;
    type ProposalId = TallyTypes.ProposalId;

    type NeuronData = {
        id : NeuronId;
        tallies : List.List<TallyId>;
        topics : Map.Map<Int32, ()>;
    };

    type TallyData = { 
        id : TallyId;
        alias : ?Text;
        governanceCanister : Text;
        topics : Map.Map<Int32, ()>;
        neurons : Map.Map<NeuronId, ()>;
    };

    type Proposal = {
        id : ProposalId; 
        isSettled : Bool; 
        topicId : Int32; 
        ballots : Map.Map<NeuronId, NeuronVote>;
        settledTimestamp : ?Time.Time;
    };

    type UpdateState = {
        #Running;
        #Stopped;
    };

    public type TallyModel = {
        neurons : Map.Map<GovernanceId, Map.Map<NeuronId, NeuronData>>;
        tallies : Map.Map<GovernanceId, Map.Map<TallyId, TallyData>>;
        proposals : Map.Map<GovernanceId, Map.Map<ProposalId, Proposal>>;
        settledProposals : Map.Map<GovernanceId, Map.Map<ProposalId, Proposal>>;
        subscribers : Map.Map<Principal, List.List<TallyData>>;

        talliesByNeuron : Map.Map<GovernanceId, Map.Map<NeuronId, List.List<TallyData>>>;
        talliesById : Map.Map<TallyId, TallyData>;

        var lastId : Nat;
        var timerId :?Nat;
    };

    public func initTallyModel() : TallyModel {
        {
            neurons = Map.new<GovernanceId, Map.Map<NeuronId, NeuronData>>();
            tallies = Map.new<GovernanceId, Map.Map<TallyId, TallyData>>();
            proposals = Map.new<GovernanceId, Map.Map<ProposalId, Proposal>>();
            settledProposals = Map.new<GovernanceId, Map.Map<ProposalId, Proposal>>();
            subscribers = Map.new<Principal, List.List<TallyData>>();

            talliesByNeuron = Map.new<GovernanceId, Map.Map<NeuronId, List.List<TallyData>>>();
            talliesById = Map.new<TallyId, TallyData>();

            var lastId = 0;
            var timerId = null;
        };
    };

    public class TallyService(tallyModel : TallyModel, logService: LT.LogService, governanceService : GS.GovernanceService, trackerService : TT.TrackerService) {

        var updateState : UpdateState = #Stopped;

        public func initTimer<system>(_tickrateInSeconds : ?Nat) : async Result.Result<(), Text> {
                    
            let tickrate : Nat = Option.get(_tickrateInSeconds, 5 * 60); // 5 minutes
            switch(tallyModel.timerId){
                case(?t){ return #err("Timer already created")};
                case(_){};
            };

            tallyModel.timerId := ?Timer.recurringTimer<system>(#seconds(tickrate), func() : async () {
                await* fetchProposalsAndUpdate()
            });

            return #ok()
        };

        public func cancelTimer() : async Result.Result<(), Text> {
            switch(tallyModel.timerId){
                case(?t){
                    Timer.cancelTimer(t);
                    tallyModel.timerId := null;
                    return #ok();
                };
                case(_){
                    return #err("No Timer to delete");
                }
            }
        };

        public func init() : async Result.Result<(), Text> {
            await* trackerService.initTimer(?300, func(governanceId : Text, new : [PT.ProposalAPI], updated : [PT.ProposalAPI]) : async* () {
                // Debug.print("Tick");
                // Debug.print("new proposals: " # debug_show(new));
                // Debug.print("updated proposals: " # debug_show(updated));
                // Debug.print("governanceId: " # governanceId);

                // await* update(governanceId, new, updated);
            });
        };

        public func addTally(args : AddTallyArgs) : async* Result.Result<TallyId, Text> {
            let governanceId = args.governanceId;
            let res = await* trackerService.addGovernance(governanceId, #All);

            switch(res) {
                case(#ok()){};
                case(#err(err)){ return #err(err);}
            };

            let tallyId : Text = Nat.toText(tallyModel.lastId + 1);
            tallyModel.lastId := tallyModel.lastId + 1;
            let topicSet = Utils.arrayToSet(args.topics, i32hash);
            let tally : TallyData = {id = tallyId; alias = args.alias; governanceCanister = governanceId; topics = topicSet; neurons = Utils.arrayToSet(args.neurons, n64hash); ballots = Map.new<ProposalId, NeuronVote>()};
            let tallyMap = Utils.getElseCreate(tallyModel.tallies, thash, governanceId, Map.new<TallyId, TallyData>());
            Map.set(tallyMap, thash, tallyId, tally);

            let subTallies = Utils.getElseCreate(tallyModel.subscribers, phash, args.subscriber, List.nil());
            Map.set(tallyModel.subscribers, phash, args.subscriber, List.push(tally, subTallies));


            Map.set(tallyModel.talliesById, thash, tallyId, tally);
            
            let neuronMap = Utils.getElseCreate(tallyModel.neurons, thash, governanceId, Map.new<NeuronId, NeuronData>());
            let tallyByNeuronMap = Utils.getElseCreate(tallyModel.talliesByNeuron, thash, governanceId, Map.new<NeuronId, List.List<TallyData>>());
            for(neuronId in args.neurons.vals()){
                switch(Map.get(neuronMap, n64hash, neuronId)){
                    case(?neuron) {
                        for(topic in Map.keys(topicSet)){
                            Map.set(neuron.topics, i32hash, topic, ());
                        };

                        Map.set(neuronMap, n64hash, neuronId, {neuron with tallies = List.push(tallyId, neuron.tallies)});
                    };
                    case(_){
                        Map.set(neuronMap, n64hash, neuronId, {id = neuronId; topics = topicSet; tallies = List.push(tallyId, List.nil<TallyId>())});
                    };
                };

                switch(Map.get(tallyByNeuronMap, n64hash, neuronId)){
                    case(?tallies) {
                        Map.set(tallyByNeuronMap, n64hash, neuronId, List.push(tally, tallies));
                    };
                    case(_){
                        var tallyList = List.nil<TallyData>();
                        tallyList := List.push(tally, tallyList);
                        Map.set(tallyByNeuronMap, n64hash, neuronId, tallyList);
                    };
                }
            };

            #ok(tally.id)
        };

        public func getTally(tallyId : TallyId) : ?TallyData {
            Map.get(tallyModel.talliesById, thash, tallyId);
        };


        //TODO: change
        public func fetchProposalsAndUpdate() : async* (){
            if(updateState == #Running){
                logService.logWarn("Update already running", ?"[update]");
                return;
            };

            updateState:= #Running;
            try{
                await* trackerService.update(func(governanceId : Text, new : [PT.ProposalAPI], updated : [PT.ProposalAPI]) : async* () {
                    await* update(governanceId, new, updated);
                });
            } catch(e){
                updateState:= #Stopped;
            };
            updateState:= #Stopped;
        };


        public func update(governanceId : Text, newProposals : [PT.ProposalAPI], changedProposals : [PT.ProposalAPI]) : async* () {

            //init proposal map for governance id if it doesnt exist
            let proposalMap = Utils.getElseCreate(tallyModel.proposals, thash, governanceId,  Map.new<ProposalId, Proposal>());
            var settledProposals = List.nil<Proposal>();
            //add new proposals to the map
            for(proposal in Array.vals(newProposals)) {
                let isSettled = isProposalSettled(proposal);
                let settledTimestamp : ?Time.Time = null;
                if(isSettled) {
                    let settledTimestamp = ?Time.now();
                };
                let p = {id = proposal.id; isSettled = isSettled; settledTimestamp = settledTimestamp; topicId = proposal.topicId; ballots = Map.new<NeuronId, NeuronVote>()};
                Map.set(proposalMap, n64hash, proposal.id,  p);
                if(isSettled) {
                    settledProposals := List.push(p, settledProposals);
                };
            };

            //update settled proposals
            for(proposal in Array.vals(changedProposals)) {
                if(isProposalSettled(proposal)) {
                    switch(Map.get(proposalMap, n64hash, proposal.id)){
                        case(?p){
                            Map.set(proposalMap, n64hash, proposal.id, {p with isSettled = true; settledTimestamp = ?Time.now()});
                            settledProposals := List.push(p, settledProposals);
                        };
                        case(_){
                            logService.logError("Error getting from proposalMap: " # governanceId, ?"[update]");
                        };
                    }
                }
            };

            //process delta of neurons with updates in their ballots
            switch(await* fetchBallots(governanceId, proposalMap, settledProposals)){
                case(#ok(delta)){
                    //send updates in batches to tallies with changes
                    //logService.logInfo("Notifying subs", ?"[update]");
                    await* notifySubscribers(governanceId, delta);
                };
                case(#err(e)){
                    logService.logError("Error fetching ballots for governance: " # governanceId # " error: " # e, ?"[update]");
                };
            };

            //move settled proposals to separate list
            for(proposal in List.toIter(settledProposals)) {
                Map.delete(proposalMap, n64hash, proposal.id);
            };

        };

        
        func fetchBallots(governanceId : Text, proposals : Map.Map<ProposalId, Proposal>, settledProposals : List.List<Proposal>) : async* Result.Result<List.List<(NeuronId, List.List<ProposalId>)>, Text> {
            var delta = List.nil<(NeuronId, List.List<ProposalId>)>();

            //for every governance canister, get the list of neurons, then chunk them and fetch new ballots
            switch(Map.get(tallyModel.neurons, thash, governanceId)){
                case(?neuronMap) {
                    let neuronChunks = getNeuronChunks(neuronMap);
                    for(chunk in List.toIter(neuronChunks)){
                        let res = await* governanceService.listNeurons(governanceId, {
                            neuron_ids = chunk;
                            include_neurons_readable_by_caller = false;
                            include_empty_neurons_readable_by_caller = null;
                            include_public_neurons_in_full_neurons = null;
                        });

                        switch(res){
                            case(#ok(neurons)) {
                                for(neuron in neurons.neuron_infos.vals()){
                                    //process proposals whose ballots changes for this neuron if any
                                    let proposalDelta = getProposalDeltaAndUpdateState(governanceId, neuron.0, neuron.1.recent_ballots, proposals, settledProposals);
                                    if(List.size(proposalDelta.1) > 0){
                                        delta := List.push(proposalDelta, delta);
                                    };
                                }
                            };
                            case(#err(err)) {
                                return #err(err);
                            };
                        };
                    };
                };
                case(_){}; //due to reentrancy the neuron could be deleted
            };

            #ok(delta)
            
        };

        func getProposalDeltaAndUpdateState(governanceId : Text, neuronId : NeuronId,  neuronBallots : [GT.BallotInfo], proposals : Map.Map<ProposalId, Proposal>, settledProposals : List.List<Proposal>) : (NeuronId, List.List<ProposalId>){
            var proposalDelta : List.List<ProposalId> = List.nil<ProposalId>();
            
            let #ok(neuron) = getNeuron(governanceId, neuronId)
            else {
                //due to reentrancy the neuron could be deleted
                return (neuronId, proposalDelta)
            };

            label l for(ballot in neuronBallots.vals()){

                let #ok(pId) = Result.fromOption(ballot.proposal_id, "proposal id not found")
                else{
                    logService.logError("proposal id not found in ballot", ?"[getProposalDeltaAndUpdateState]");
                    continue l;
                };

                let #ok(proposal) = Result.fromOption(Map.get(proposals, n64hash, pId.id), "proposal not found")
                else {
                    logService.logError("proposal not found", ?"[getProposalDeltaAndUpdateState]");
                    continue l;
                };

                //if neuron doesnt follow this topic on any tally then skip
                if(not Map.has(neuron.topics, i32hash, proposal.topicId)){
                    continue l;
                };

                //
                switch(Map.get(proposal.ballots, n64hash, neuronId)){
                    case(?vote) {
                        let newVote = NNSMappings.tryMapVoteFromInt(ballot.vote);
                        switch(newVote){
                            case(#ok(mappedBallotVote)) {
                                if(vote != mapVote(mappedBallotVote, proposal.isSettled)){
                                    proposalDelta := List.push(proposal.id, proposalDelta);
                                    let v = mapVote(mappedBallotVote, proposal.isSettled);
                                    Map.set(proposal.ballots, n64hash, neuronId, v);
                                };
                            };
                            case(#err(e)){
                                logService.logError("Failed to map vote for proposal: " # Nat64.toText(proposal.id) # "for neuron: " # Nat64.toText(neuronId) # " error " # e, ?"[getProposalDeltaAndUpdateState]");
                            };
                        };
                    };
                    case(_){
                        let vote = NNSMappings.tryMapVoteFromInt(ballot.vote);
                        switch(vote){
                             case(#ok(mappedBallotVote)){
                                let v = mapVote(mappedBallotVote, proposal.isSettled);
                                Map.set(proposal.ballots, n64hash, neuronId, v);
                                proposalDelta := List.push(proposal.id, proposalDelta);
                             };
                             case(#err(e)){
                                logService.logError("err Failed to map vote for proposal: " # Nat64.toText(proposal.id) # "for neuron: " # Nat64.toText(neuronId) # " error " # e, ?"[getProposalDeltaAndUpdateState]");
                             };
                        }
                    };
                };
            };

            label l for (proposal in List.toIter(settledProposals)){
                let #ok(neuron) = getNeuron(governanceId, neuronId)
                else {
                    //due to reentrancy the neuron could be deleted
                    continue l;
                };

                if(not Map.has(neuron.topics, i32hash, proposal.topicId)){
                    continue l;
                };
                
                //TODO: what if more than 100 proposal have been created? intersect neuronBallots with proposals and check size.
                switch(Map.get(proposal.ballots, n64hash, neuronId)){
                    case(?vote) {
                        if(vote == #Pending){
                            proposalDelta := List.push(proposal.id, proposalDelta);
                            Map.set(proposal.ballots, n64hash, neuronId, #Abstained);
                        };
                    };
                    case(_){
                        proposalDelta := List.push(proposal.id, proposalDelta);
                        Map.set(proposal.ballots, n64hash, neuronId, #Abstained);
                    };
                };
            };

            //init ballot to pending
            label l for (proposal in Map.vals(proposals)){
                //if neuron doesnt follow this topic on any tally then skip
                if(not Map.has(neuron.topics, i32hash, proposal.topicId)){
                    continue l;
                };
                if(not Map.has(proposal.ballots, n64hash, neuronId)){
                    Map.set(proposal.ballots, n64hash, neuronId, #Pending);
                    proposalDelta := List.push(proposal.id, proposalDelta);
                };
            };

            (neuronId, proposalDelta)
        };

        func processAffectedTallies(governanceId : Text, delta : List.List<(NeuronId, List.List<ProposalId>)>) : Map.Map<TallyId, List.List<Proposal>>{
            let affectedTallies = Map.new<TallyId, List.List<Proposal>>();
            label l for((neuron, proposalList) in List.toIter(delta)){
                let #ok(neuronTallies) = Result.fromOption(Map.get(tallyModel.talliesByNeuron, thash, governanceId), #err("not found"))
                else {
                    continue l;
                };
                
                switch(Map.get(neuronTallies, n64hash, neuron)){
                    case(?tallies){
                        var relatedProposals = List.nil<Proposal>();
                        for(tally in List.toIter(tallies)) {

                            for(proposalId in List.toIter(proposalList)) {
                                let #ok(proposal) = getProposal(governanceId, proposalId)
                                else {
                                    continue l;
                                };
                                if (Map.has(tally.topics, i32hash, proposal.topicId)) {
                                    relatedProposals := List.push(proposal, relatedProposals);
                                };
                            };
                            if(List.size(relatedProposals) > 0) {
                                Map.set(affectedTallies, thash, tally.id, relatedProposals);
                            }
                        };
                    };
                    case(_){};
                };
            };
            affectedTallies
        };

        func processTally(tally: TallyData, proposals : List.List<Proposal>) : TallyTypes.TallyFeed{
            {
                tallyId= tally.id;
                alias = tally.alias;
                governanceCanister = tally.governanceCanister;
                ballots = processTallyBallots(tally, proposals);
            };

        };

        func processTallyBallots(tally: TallyData, proposals : List.List<Proposal>) : [TallyTypes.Ballot]{
            let ballots = Buffer.Buffer<TallyTypes.Ballot>(List.size(proposals));
            let neuronNumber = Map.size(tally.neurons);

            //for(neuron in Map.keys(tally.neurons)) {
                for(proposal in List.toIter(proposals)) {
                    ballots.add(processTallyBallot(tally.neurons, proposal, neuronNumber));
                };
            //};

            Buffer.toArray(ballots);
        };

        func processTallyBallot(neurons : Map.Map<NeuronId, ()>, proposal : Proposal, neuronNumber : Nat) : TallyTypes.Ballot{
            var approves = 0;
            var rejects = 0;
            var tallyVote : TallyTypes.Vote = #Pending;
            let neuronVotes = Buffer.Buffer<TallyTypes.VoteRecord>(neuronNumber);

            for(neuron in Map.keys(neurons)) {
                let neuronVote : TallyTypes.VoteRecord = {
                    neuronId : NeuronId = neuron;
                    displayName : ?Text = null;
                    vote = #Pending;
                };

                switch(Map.get(proposal.ballots, n64hash, neuron)){
                    case(?voteRecord){
                        neuronVotes.add({neuronVote with vote = voteRecord});
                        if(voteRecord == #Yes) {
                            approves += 1;
                        } else if (voteRecord == #No) {
                            rejects += 1;
                        }
                    };
                    case(_){
                        if(proposal.isSettled){
                            neuronVotes.add({neuronVote with vote = #Abstained});
                        } else {
                            neuronVotes.add(neuronVote);
                        };
                    };
                };
            };

            if(approves > neuronNumber / 2){
                tallyVote := #Yes;
            } else if (rejects > neuronNumber / 2) {
                tallyVote := #No;
            } else if (proposal.isSettled){
                tallyVote := #Abstained;
            };

            {
                proposalId = proposal.id;
                tallyVote = tallyVote;
                neuronVotes = Buffer.toArray<TallyTypes.VoteRecord>(neuronVotes);
            };
        };

        func notifySubscribers(governanceId : Text, delta : List.List<(NeuronId, List.List<ProposalId>)>) :  async* (){
            let affectedTallies = processAffectedTallies(governanceId, delta);
            for((subId, tallies) in Map.entries(tallyModel.subscribers)){
                await* chunkedSend(Principal.toText(subId), tallies, affectedTallies, 100);
            };
        };

        func chunkedSend(governanceId : Text, subscriberTallies : List.List<TallyData>, affectedTallies : Map.Map<TallyId, List.List<Proposal>>, chunkSize : Nat) : async* () {
            let tallyChunk = Buffer.Buffer<TallyTypes.TallyFeed>(chunkSize);
            for(tally in List.toIter(subscriberTallies)) {
                if(Map.has(affectedTallies, thash, tally.id)){
                    switch(Map.get(affectedTallies, thash, tally.id)){
                        case(?proposals){
                            tallyChunk.add(processTally(tally, proposals));
                            if(tallyChunk.size() >= chunkSize) {
                                await* notifySubscriber(governanceId, Buffer.toArray(tallyChunk));
                                tallyChunk.clear();
                            }
                        };
                        case(_){};
                    }
                };
            };
            if(tallyChunk.size() > 0) {
                await* notifySubscriber(governanceId, Buffer.toArray(tallyChunk));
            };
        };
        
        func notifySubscriber(governanceId : Text, tallies : [TallyTypes.TallyFeed]) : async* () {
            let sub : TallyTypes.Subscriber = actor (governanceId);
            await sub.tallyUpdate(tallies);
        };

        func mapVote(vote : NNSMappings.NNSVote, isSettled : Bool) : NeuronVote{
            switch(vote){
                case(#Yes){
                    #Yes
                };
                case(#No){
                    #No
                };
                case(#Unspecified){
                    if(isSettled){
                        #Abstained;
                    } else {
                        #Pending
                    };
                }
            }
        };

        func getNeuron(governanceId : Text, neuronId : NeuronId) : Result.Result<NeuronData, Text> {
            let #ok(neuronMap) = Result.fromOption(Map.get(tallyModel.neurons, thash, governanceId), "governance ID not found")
            else {
               return #err("governance ID not found");
            };

            let #ok(neuron) = Result.fromOption(Map.get(neuronMap, n64hash, neuronId), "neuron not found")
            else {
                return #err("neuron ID not found");
            };
        };

        func isProposalSettled(proposal : PT.ProposalAPI) : Bool {
            switch(proposal.rewardStatus) {
                case(#ReadyToSettle or #Settled){
                    return true;
                };
                case(_){
                    return false;
                };
            }
        };

        func getProposal(governanceId : Text, proposalId : ProposalId) : Result.Result<Proposal, Text> {
            let #ok(proposalMap) = Result.fromOption(Map.get(tallyModel.proposals, thash, governanceId), #err("not found"))
            else {
                return #err("governanceId not found");
            };

            let #ok(proposal) = Result.fromOption(Map.get(proposalMap, n64hash, proposalId), #err("not found"))
            else {
                return #err("proposalId not found");
            };
            return #ok(proposal);
        };

        func getNeuronChunks(map : Map.Map<NeuronId, NeuronData>) : List.List<[Nat64]> {
            var tmp = List.nil<Nat64>();
            for(n in Map.keys(map)){
                tmp := List.push(n, tmp);
            };

           return List.chunks(20, tmp) |>
                    List.map(_, func (l : List.List<Nat64>) : [Nat64] {
                        return List.toArray(l);
                    });
        };

    };

};