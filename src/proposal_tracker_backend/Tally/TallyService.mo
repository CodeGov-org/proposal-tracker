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
    type TopicId = TallyTypes.TopicId;

    type NeuronData = {
        id : NeuronId;
        topics : Map.Map<TopicId, Nat>;
    };

    type NeuronDataAPI = {
        id : NeuronId;
        topics : [{id: TopicId; count : Nat}];
    };

    type TallyData = { 
        id : TallyId;
        alias : ?Text;
        governanceCanister : Text;
        var topics : Map.Map<TopicId, ()>; //todo probably var can be removed
        var neurons : Map.Map<NeuronId, ()>;
    };

    type Proposal = {
        id : ProposalId; 
        isSettled : Bool; 
        topicId : TopicId; 
        ballots : Map.Map<NeuronId, NeuronVote>;
        settledTimestamp : ?Time.Time;
    };

    type UpdateState = {
        #Running;
        #Stopped;
    };

    public type TallyModel = {
        neurons : Map.Map<GovernanceId, Map.Map<NeuronId, NeuronData>>;
        //tallies : Map.Map<GovernanceId, Map.Map<TallyId, TallyData>>;
        proposals : Map.Map<GovernanceId, Map.Map<ProposalId, Proposal>>;
        settledProposals : Map.Map<GovernanceId, Map.Map<ProposalId, Proposal>>;
        subscribers : Map.Map<Principal, List.List<TallyData>>;

        talliesByNeuron : Map.Map<GovernanceId, Map.Map<NeuronId, List.List<TallyData>>>;
        talliesById : Map.Map<TallyId, TallyData>;

        var lastId : Nat;
        var timerId :?Nat;
        var tickrateInSeconds : ?Nat;
    };

    public func initTallyModel() : TallyModel {
        {
            neurons = Map.new<GovernanceId, Map.Map<NeuronId, NeuronData>>();
            //tallies = Map.new<GovernanceId, Map.Map<TallyId, TallyData>>();
            proposals = Map.new<GovernanceId, Map.Map<ProposalId, Proposal>>();
            settledProposals = Map.new<GovernanceId, Map.Map<ProposalId, Proposal>>();
            subscribers = Map.new<Principal, List.List<TallyData>>();

            talliesByNeuron = Map.new<GovernanceId, Map.Map<NeuronId, List.List<TallyData>>>();
            talliesById = Map.new<TallyId, TallyData>();

            var lastId = 0;
            var timerId = null;
            var tickrateInSeconds = null;
        };
    };

    public class TallyService(tallyModel : TallyModel, logService: LT.LogService, governanceService : GS.GovernanceService, trackerService : TT.TrackerService) {

        var updateState : UpdateState = #Stopped;

        public func initTimer<system>(_tickrateInSeconds : ?Nat) : async Result.Result<(), Text> {
                    
            let tickrate : Nat = Option.get(_tickrateInSeconds, 5 * 60); // 5 minutes
            tallyModel.tickrateInSeconds := ?tickrate;
            switch(tallyModel.timerId){
                case(?t){ return #err("Timer already created")};
                case(_){};
            };

            tallyModel.timerId := ?Timer.recurringTimer<system>(#seconds(tickrate), func() : async () {
                logService.logInfo("Running timer", null);
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

        public func init(tickrateInSeconds : ?Nat) : async Result.Result<(), Text> {
            await initTimer(tickrateInSeconds);
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
            let topicSet = Utils.arrayToSet(args.topics, n64hash);
            let tally : TallyData = {id = tallyId; alias = args.alias; governanceCanister = governanceId; var topics = topicSet; var neurons = Utils.arrayToSet(args.neurons, thash); ballots = Map.new<ProposalId, NeuronVote>()};
            // let tallyMap = Utils.getElseCreate(tallyModel.tallies, thash, governanceId, Map.new<TallyId, TallyData>());
            // Map.set(tallyMap, thash, tallyId, tally);
            
            switch(args.subscriber){
                case(?subscriber){
                    let subTallies = Utils.getElseCreate(tallyModel.subscribers, phash, subscriber, List.nil());
                    Map.set(tallyModel.subscribers, phash, subscriber, List.push(tally, subTallies));
                };
                case(_){};
            };


            Map.set(tallyModel.talliesById, thash, tallyId, tally);
            
            let neuronMap = Utils.getElseCreate(tallyModel.neurons, thash, governanceId, Map.new<NeuronId, NeuronData>());
            let tallyByNeuronMap = Utils.getElseCreate(tallyModel.talliesByNeuron, thash, governanceId, Map.new<NeuronId, List.List<TallyData>>());
            for(neuronId in args.neurons.vals()){
                switch(Map.get(neuronMap, thash, neuronId)){
                    case(?neuron) {
                        for(topic in args.topics.vals()){
                            switch(Map.get(neuron.topics, n64hash, topic)){
                                case(?topicData){
                                     Map.set(neuron.topics, n64hash, topic, topicData + 1);
                                };
                                case(_){
                                    Map.set(neuron.topics, n64hash, topic, 1);
                                };
                            };
                        };
                    };
                    case(_){
                        let topicMap = Map.new<TopicId, Nat>();
                        for(topic in args.topics.vals()){
                            Map.set(topicMap, n64hash, topic, 1);
                        };
                        Map.set(neuronMap, thash, neuronId, {id = neuronId; topics = topicMap;});
                    };
                };

                switch(Map.get(tallyByNeuronMap, thash, neuronId)){
                    case(?tallies) {
                        Map.set(tallyByNeuronMap, thash, neuronId, List.push(tally, tallies));
                    };
                    case(_){
                        var tallyList = List.nil<TallyData>();
                        tallyList := List.push(tally, tallyList);
                        Map.set(tallyByNeuronMap, thash, neuronId, tallyList);
                    };
                }
            };

            #ok(tally.id)
        };

        public func getTallyAPI(tallyId : TallyId) : ?TallyTypes.TallyDataAPI {
            switch(Map.get(tallyModel.talliesById, thash, tallyId)){
                case(?tally){
                    return ?tallyDataToAPI(tally);
                };
                case(_){null};
            };
        };

        public func getTally(tallyId : TallyId) : ?TallyData {
            Map.get(tallyModel.talliesById, thash, tallyId);
        };

        public func getTallies() : [TallyTypes.TallyDataAPI] {
            var tallies = Buffer.Buffer<TallyTypes.TallyDataAPI>(Map.size(tallyModel.talliesById));
            for(tally in Map.vals(tallyModel.talliesById)){
                tallies.add(tallyDataToAPI(tally));
            };
            Buffer.toArray(tallies);
        };

        public func getNeurons() : Text {
            var neurons = "";
            for (neuron in Map.vals(tallyModel.neurons)) {
                neurons := neurons # debug_show(neuron) # "\n";
            };
            neurons
        };

        public func getNeuronInfo(governanceId : GovernanceId, neuronId : NeuronId) : Result.Result<{neuron : NeuronDataAPI; tallies : [TallyId]}, Text> {
            //var neuron : NeuronDataAPI = {
            switch(Map.get(tallyModel.neurons, thash, governanceId)){
                case(?neuronMap){
                    switch(Map.get(neuronMap, thash, neuronId)){
                        case(?neuron){
                            switch(Map.get(tallyModel.talliesByNeuron, thash, governanceId)){
                                case(?tallies){
                                    switch(Map.get(tallies, thash, neuronId)){
                                        case(?neuronTallies){
                                            let sharedNeuron = neuronToNeuronDataAPI(neuron);
                                            let tallies = List.map<TallyData, TallyId>(neuronTallies, func(tally){tally.id});

                                            #ok({neuron = sharedNeuron; tallies = List.toArray(tallies)});
                                        };
                                        case(_){
                                            return #err("No tallies in talliesByNeuron for this neuron, this should not happen");
                                        };
                                    };
                                };
                                case(_){
                                    return #err("No tallies for this governance id, this should not happen");
                                };
                            };


                        };
                        case(_){
                            return #err("Neuron not found");
                        };
                    };
                };
                case(_){
                    return #err("Governance not found");
                };
            };


        };

        func deleteNeuron(governanceId : GovernanceId, neuronId : NeuronId) : () {
            switch(Map.get(tallyModel.neurons, thash, governanceId)){
                case(?neuronMap){
                    Map.delete(neuronMap, thash, neuronId);
                };
                case(_){};
            };
        };

        func updateNeuronTopics(governanceId : GovernanceId, neuronId : NeuronId, removedTopics :  Map.Map<TopicId, ()>, addedTopics : Map.Map<TopicId, ()>) : () {
            switch(Map.get(tallyModel.neurons, thash, governanceId)){
                case(?neuronMap){
                    switch(Map.get(neuronMap, thash, neuronId)){
                        case(?neuron) {
                            for(removedTopic in Map.keys(removedTopics)){
                                switch(Map.get(neuron.topics, n64hash, removedTopic)){
                                    case(?topicData){
                                        let newCount : Nat = topicData - 1;
                                        if(newCount == 0){
                                            Map.delete(neuron.topics, n64hash, removedTopic);
                                        } else {
                                            Map.set(neuron.topics, n64hash, removedTopic, newCount);
                                        };
                                    };
                                    case(_){};
                                };
                            };

                            for(addedTopic in Map.keys(addedTopics)){
                                switch(Map.get(neuron.topics, n64hash, addedTopic)){
                                    case(?topicData){
                                        let newCount : Nat = topicData + 1;
                                        Map.set(neuron.topics, n64hash, addedTopic, newCount);
                                    };
                                    case(_){
                                        Map.set(neuron.topics, n64hash, addedTopic, 1);
                                    };
                                };
                            }
                        };
                        case(_){};
                    };
                };
                case(_){};
            };
        };

        public func deleteTally(tallyId : TallyId) : Result.Result<(), Text> {
            if(updateState == #Running){
                return #err("Tallies are being updated, deleting could cause issues with global state");
            };

            let #ok(tally) = Utils.optToRes(getTally(tallyId)) else {return #err("Tally not found")};
            Map.delete(tallyModel.talliesById, thash, tallyId);

            for ((sub, tally) in Map.entries(tallyModel.subscribers)){
                Map.set(tallyModel.subscribers, phash, sub, List.filter(tally, func(t : TallyData) : Bool {t.id != tallyId}));
            };

            switch(Map.get(tallyModel.talliesByNeuron, thash, tally.governanceCanister)){
                case(?neurons){
                    for(neuronId in Map.keys(neurons)){
                        switch(Map.get(neurons, thash, neuronId)){
                            case(?tallies){
                                let newList = List.filter(tallies, func(t : TallyData) : Bool {t.id != tallyId});
                                //If no tallies depend on this neuron anymore it should be deleted.
                                if(List.size(newList) == 0){
                                    deleteNeuron(tally.governanceCanister, neuronId);
                                } else {
                                    Map.set(neurons, thash, neuronId, newList);
                                    updateNeuronTopics(tally.governanceCanister, neuronId, tally.topics, Map.new());
                                };
                            };
                            case(_){};
                        };
                    };
                };
                case(_){};
            };


            // switch(Map.get(tallyModel.tallies, thash, tally.governanceCanister)){
            //     case(?tallies){
            //         Map.delete(tallies, thash, tallyId);
            //     };
            //     case(_){};
            // };


            #ok()
        };

        // func updateOrDeleteNeuron(neuronId : NeuronId) : () {

        // };

        public func addNeuronToTally(tallyId : TallyId, neuronId : NeuronId) : Result.Result<(), Text> {
            if(updateState == #Running){
                return #err("Tallies are being updated, deleting could cause issues with global state");
            };

            let #ok(tally) = Utils.optToRes(getTally(tallyId)) else {return #err("Tally not found")};

            if(Map.has(tally.neurons, thash, neuronId)){
                    return #err("Neuron already added to tally");
            } else {
                //neuron is new, add it
                Map.set(tally.neurons, thash, neuronId, ());
                let neuronMap = Utils.getElseCreate(tallyModel.neurons, thash, tally.governanceCanister , Map.new<NeuronId, NeuronData>());
                let tallyByNeuronMap = Utils.getElseCreate(tallyModel.talliesByNeuron, thash, tally.governanceCanister, Map.new<NeuronId, List.List<TallyData>>());
                switch(Map.get(neuronMap, thash, neuronId)){
                    case(?neuron) {
                        for(topic in Map.keys(tally.topics)){
                            switch(Map.get(neuron.topics, i32hash, topic)){
                                case(?topicData){
                                    Map.set(neuron.topics, i32hash, topic, topicData + 1);
                                };
                                case(_){
                                    Map.set(neuron.topics, i32hash, topic, 1);
                                };
                            };
                        };
                    };
                    case(_){
                        let topicMap = Map.new<TopicId, Nat>();
                        for(topic in Map.keys(tally.topics)){
                            Map.set(topicMap, i32hash, topic, 1);
                        };
                        Map.set(neuronMap, thash, neuronId, {id = neuronId; topics = topicMap;});
                    };
                };

                switch(Map.get(tallyByNeuronMap, thash, neuronId)){ 
                    case(?tallies) {
                        Map.set(tallyByNeuronMap, thash, neuronId, List.push(tally, tallies));
                    };
                    case(_){
                        let tallyList = List.make<TallyData>(tally);
                        Map.set(tallyByNeuronMap, thash, neuronId, tallyList);
                    };
                };
            };
            
            #ok()
        };

        public func updateTally(tallyId : TallyId, newTally : {topics : [TopicId]; neurons : [NeuronId] }) : Result.Result<(), Text> {
            if(updateState == #Running){
                return #err("Tallies are being updated, deleting could cause issues with global state");
            };

            let #ok(tally) = Utils.optToRes(getTally(tallyId)) else {return #err("Tally not found")};
            let topicSet = Utils.arrayToSet(newTally.topics, n64hash);
            let neuronSet = Utils.arrayToSet(newTally.neurons, thash);

            let removedTopics = Map.new<TopicId, ()>();
            let addedTopics = Map.new<TopicId, ()>();

            for(topic in Map.keys(tally.topics)){
                if(not Map.has(topicSet, n64hash, topic)){
                    Map.set(removedTopics, n64hash, topic, ());
                };
            };

            for(topic in Map.keys(topicSet)){
                if(not Map.has(tally.topics, n64hash, topic)){
                    Map.set(addedTopics, n64hash, topic, ());
                };
            };

            //if the neuron is not in the new list it has to be removed from the tally neurons and the neuron itself has to be updated
            for(neuronTally in Map.keys(tally.neurons)){
                if(not Map.has(neuronSet, thash, neuronTally)){
                    switch(Map.get(tallyModel.talliesByNeuron, thash, tally.governanceCanister)){
                        case(?neurons){
                            for(neuronId in Map.keys(neurons)){
                                switch(Map.get(neurons, thash, neuronId)){
                                    case(?tallies){
                                        let newList = List.filter(tallies, func(t : TallyData) : Bool {t.id != tallyId});
                                        //If no tallies depend on this neuron anymore it should be deleted.
                                        if(List.size(newList) == 0){
                                            deleteNeuron(tally.governanceCanister, neuronId);
                                        } else {
                                            Map.set(neurons, thash, neuronId, newList);
                                            updateNeuronTopics(tally.governanceCanister, neuronId, tally.topics, Map.new());
                                        };
                                    };
                                    case(_){};
                                };
                            };
                        };
                        case(_){};
                    };
                };
            };

            //add new neurons to tally or update them if there are new topics
            for(neuronId in newTally.neurons.vals()){
                if(Map.has(tally.neurons, thash, neuronId)){
                    //neuron might have to be updated
                    updateNeuronTopics(tally.governanceCanister, neuronId, removedTopics, addedTopics);
                } else {
                    //neuron is new, add it
                    Map.set(tally.neurons, thash, neuronId, ());
                    let neuronMap = Utils.getElseCreate(tallyModel.neurons, thash, tally.governanceCanister , Map.new<NeuronId, NeuronData>());
                    let tallyByNeuronMap = Utils.getElseCreate(tallyModel.talliesByNeuron, thash, tally.governanceCanister, Map.new<NeuronId, List.List<TallyData>>());
                    switch(Map.get(neuronMap, thash, neuronId)){
                        case(?neuron) {
                            for(topic in newTally.topics.vals()){
                                switch(Map.get(neuron.topics, n64hash, topic)){
                                    case(?topicData){
                                        Map.set(neuron.topics, n64hash, topic, topicData + 1);
                                    };
                                    case(_){
                                        Map.set(neuron.topics, n64hash, topic, 1);
                                    };
                                };
                            };
                        };
                        case(_){
                            let topicMap = Map.new<TopicId, Nat>();
                            for(topic in newTally.topics.vals()){
                                Map.set(topicMap, n64hash, topic, 1);
                            };
                            Map.set(neuronMap, thash, neuronId, {id = neuronId; topics = topicMap;});
                        };
                    };

                    switch(Map.get(tallyByNeuronMap, thash, neuronId)){
                        case(?tallies) {
                            Map.set(tallyByNeuronMap, thash, neuronId, List.push(tally, tallies));
                        };
                        case(_){
                            var tallyList = List.nil<TallyData>();
                            tallyList := List.push(tally, tallyList);
                            Map.set(tallyByNeuronMap, thash, neuronId, tallyList);
                        };
                    };

                };
            };

            tally.topics := topicSet;
            tally.neurons := neuronSet;
            #ok()
        };

        public func addSubscriber(subscriber : Principal, tallyId : TallyId) : Result.Result<(), Text> {
            let #ok(tally) = Utils.optToRes(getTally(tallyId)) else {return #err("Tally not found")};

            let subTallies = Utils.getElseCreate(tallyModel.subscribers, phash, subscriber, List.nil());
            Map.set(tallyModel.subscribers, phash, subscriber, List.push(tally, subTallies));
            #ok()
        };

        public func deleteSubscriber(subscriber : Principal, tallyId : TallyId) : Result.Result<(), Text> {
            switch(Map.get(tallyModel.subscribers, phash, subscriber)){
                case(?tallies){
                    let newTallies = List.filter(tallies, func(tally : TallyData) : Bool {
                        return tally.id != tallyId;
                    });
                    Map.set(tallyModel.subscribers, phash, subscriber, newTallies);
                    #ok()
                };
                case(_){
                    return #err("No subscriber found");
                };
            }
        };

        public func getSubscribersByTallyId(tallyId : TallyId) : [Principal]{
            let buf = Buffer.Buffer<Principal>(20);
            for((sub, tallies) in Map.entries(tallyModel.subscribers)){
                for(tally in List.toIter(tallies)){
                    if(tally.id == tallyId){
                        buf.add(sub);
                    };
                };
            };

            Buffer.toArray(buf);
        };

        public func getTalliesByPrincipal(principal : Principal) : Result.Result<[{id : Text; alias : ?Text}], Text> {
            switch(Map.get(tallyModel.subscribers, phash, principal)){
                case(?tallies){
                    var buf = Buffer.Buffer<{id : Text; alias : ?Text}>(20);
                    for(tally in List.toIter(tallies)){
                        buf.add({id = tally.id; alias = tally.alias;});
                    };
                    #ok(Buffer.toArray(buf))
                };
                case(_){
                    return #err("No tallies found")
                };
            };
        };

        //TODO: change for SNS
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
            logService.logInfo("New Proposals: " # Nat.toText(newProposals.size()) # " Changed Proposals: " #  Nat.toText(changedProposals.size()), ?"[update]");
            //add new proposals to the map
            for(proposal in Array.vals(newProposals)) {
                let _isSettled = isProposalSettled(proposal);
                let settledTimestamp : ?Time.Time = null;
                if(_isSettled) {
                    let settledTimestamp = ?Time.now();
                };
                let p = {id = proposal.id; isSettled = _isSettled; settledTimestamp = settledTimestamp; topicId = proposal.topicId; ballots = Map.new<NeuronId, NeuronVote>()};
                Map.set(proposalMap, n64hash, proposal.id,  p);
                if(_isSettled) {
                    logService.logInfo("Proposal settled: " # Nat64.toText(proposal.id), ?"[update]");
                    settledProposals := List.push(p, settledProposals);
                };
            };

            //update settled proposals
            for(proposal in Array.vals(changedProposals)) {
                if(isProposalSettled(proposal)) {
                    logService.logInfo("Proposal settled: " # Nat64.toText(proposal.id), ?"[update]");
                    switch(Map.get(proposalMap, n64hash, proposal.id)){
                        case(?p){
                            let updatedProposal = {p with isSettled = true; settledTimestamp = ?Time.now()};
                            Map.set(proposalMap, n64hash, proposal.id, updatedProposal);
                            settledProposals := List.push(updatedProposal, settledProposals);
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
                                    let proposalDelta = getProposalDeltaAndUpdateState(governanceId, Nat64.toText(neuron.0), neuron.1.recent_ballots, proposals, settledProposals);
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
                    //logService.logError("Proposal not found: " # Nat64.toText(pId.id), ?"[getProposalDeltaAndUpdateState]");
                    continue l;
                };

                //if neuron doesnt follow this topic on any tally then skip
                if(not Map.has(neuron.topics, n64hash, proposal.topicId)){
                    continue l;
                };

                //
                switch(Map.get(proposal.ballots, thash, neuronId)){
                    case(?vote) {
                        let newVote = NNSMappings.tryMapVoteFromInt(ballot.vote);
                        switch(newVote){
                            case(#ok(mappedBallotVote)) {
                                if(vote != mapVote(mappedBallotVote, proposal.isSettled)){
                                    proposalDelta := List.push(proposal.id, proposalDelta);
                                    let v = mapVote(mappedBallotVote, proposal.isSettled);
                                    Map.set(proposal.ballots, thash, neuronId, v);
                                };
                            };
                            case(#err(e)){
                                logService.logError("Failed to map vote for proposal: " # Nat64.toText(proposal.id) # "for neuron: " # neuronId # " error " # e, ?"[getProposalDeltaAndUpdateState]");
                            };
                        };
                    };
                    case(_){
                        let vote = NNSMappings.tryMapVoteFromInt(ballot.vote);
                        switch(vote){
                             case(#ok(mappedBallotVote)){
                                let v = mapVote(mappedBallotVote, proposal.isSettled);
                                Map.set(proposal.ballots, thash, neuronId, v);
                                proposalDelta := List.push(proposal.id, proposalDelta);
                             };
                             case(#err(e)){
                                logService.logError("err Failed to map vote for proposal: " # Nat64.toText(proposal.id) # "for neuron: " # neuronId # " error " # e, ?"[getProposalDeltaAndUpdateState]");
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

                if(not Map.has(neuron.topics, n64hash, proposal.topicId)){
                    continue l;
                };
                
                //what if more than 100 proposal have been created? intersect neuronBallots with proposals and check size.
                switch(Map.get(proposal.ballots, thash, neuronId)){
                    case(?vote) {
                        if(vote == #Pending){
                            proposalDelta := List.push(proposal.id, proposalDelta);
                            Map.set(proposal.ballots, thash, neuronId, #Abstained);
                        };
                    };
                    case(_){
                        proposalDelta := List.push(proposal.id, proposalDelta);
                        Map.set(proposal.ballots, thash, neuronId, #Abstained);
                    };
                };
            };

            //init ballot to pending
            label l for (proposal in Map.vals(proposals)){
                //if neuron doesnt follow this topic on any tally then skip
                if(not Map.has(neuron.topics, n64hash, proposal.topicId)){
                    continue l;
                };
                if(not Map.has(proposal.ballots, thash, neuronId)){
                    Map.set(proposal.ballots, thash, neuronId, #Pending);
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
                
                switch(Map.get(neuronTallies, thash, neuron)){
                    case(?tallies){
                        for(tally in List.toIter(tallies)) {
                            var relatedProposals = List.nil<Proposal>();
                            for(proposalId in List.toIter(proposalList)) {
                                let #ok(proposal) = getProposal(governanceId, proposalId)
                                else {
                                    continue l;
                                };
                                if (Map.has(tally.topics, n64hash, proposal.topicId)) {
                                    //logService.logInfo("Tally ID: " # tally.id # " is affected cause proposal: " # Nat64.toText(proposal.id), ?"[processAffectedTallies]");
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

            // for((key, value) in Map.entries(affectedTallies)){
            //     logService.logInfo("Proposals affected by tallyid: " # key # " n times:" # Nat.toText(List.size(value)), null);
            // };
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

                switch(Map.get(proposal.ballots, thash, neuron)){
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
            } else if (rejects >= neuronNumber / 2) {
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

        func chunkedSend(subId : Text, subscriberTallies : List.List<TallyData>, affectedTallies : Map.Map<TallyId, List.List<Proposal>>, chunkSize : Nat) : async* () {
            let tallyChunk = Buffer.Buffer<TallyTypes.TallyFeed>(chunkSize);
            for(tally in List.toIter(subscriberTallies)) {
                //if(Map.has(affectedTallies, thash, tally.id)){
                    switch(Map.get(affectedTallies, thash, tally.id)){
                        case(?proposals){
                            //logService.logInfo("Proposals affected by tallyid: " # tally.id # Nat.toText(List.size(proposals)), null);
                            tallyChunk.add(processTally(tally, proposals));
                            if(tallyChunk.size() >= chunkSize) {
                                await* notifySubscriber(subId, Buffer.toArray(tallyChunk));
                                tallyChunk.clear();
                            }
                        };
                        case(_){};
                    }
               // };
            };
            if(tallyChunk.size() > 0) {
                await* notifySubscriber(subId, Buffer.toArray(tallyChunk));
            };
        };
        
        public func notifySubscriber(subId : Text, tallies : [TallyTypes.TallyFeed]) : async* () {
            logService.logInfo("Notifying subscriber", null);
            let sub : TallyTypes.Subscriber = actor (subId);
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

            let #ok(neuron) = Result.fromOption(Map.get(neuronMap, thash, neuronId), "neuron not found")
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
                switch(textToNat64(n)){
                    case (?success){
                        tmp := List.push(success, tmp);
                    };
                    case(_){};
                };
            };

           return List.chunks(20, tmp) |>
                    List.map(_, func (l : List.List<Nat64>) : [Nat64] {
                        return List.toArray(l);
                    });
        };

        func tallyDataToAPI(tally : TallyData) : TallyTypes.TallyDataAPI {
            let neuronBuffer = Buffer.Buffer<TallyTypes.NeuronId>(0);
            let topicBufer = Buffer.Buffer<Int32>(0);
            for(topic in Map.keys(tally.topics)){
                topicBufer.add(topic);
            };

            for(neuron in Map.keys(tally.neurons)){
                neuronBuffer.add(neuron);
            };

            {
                tallyId = tally.id;
                alias = tally.alias;
                governanceCanister = tally.governanceCanister;
                topics = Buffer.toArray(topicBufer);
                neurons= Buffer.toArray(neuronBuffer);
            }
        };

        func neuronToNeuronDataAPI(neuron : NeuronData) : NeuronDataAPI {
            let buf = Buffer.Buffer<{id: TopicId; count : Nat}>(Map.size(neuron.topics));
            for ((topicId, count) in Map.entries(neuron.topics)) {
                buf.add({id = topicId; count = count});
            };
            
            {
                id = neuron.id;
                topics = Buffer.toArray(buf);
            };
        }; 

        public func textToNat64(t : Text) : ?Nat64 {
            switch (Nat.fromText(t)) {
                case (null) { null };
                case (?n) { ?Nat64.fromNat(n) };
            };
        };

    };

};