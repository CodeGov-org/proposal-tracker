
import Debug "mo:base/Debug";
import List "mo:base/List";
import Time "mo:base/Time";

module {
    public type LogLevel = {
        #Error;
        #Warn;
        #Info;
        #Debug;
    };

    public type LogService = {
        log : (level : LogLevel, message : Text) -> ();
        // logError : (message : Text) -> ();
        // logWarn : (message : Text) -> ();
        // logInfo : (message : Text) -> ();
        // logDebug : (message : Text) -> ();
        getLogs(height : ?Nat) : [(LogLevel,Text)];
        clearLogs(height : ?Nat) : ();
    };

    public type Log = (Nat, LogLevel, Text);

    public type LogList= List.List<Log>;
    public type LogModel = {
        var logs : LogList;
        var lastBlockTime : Time.Time;
        var currentHeight : Nat;
    };

    public func initLogModel() : LogModel {
        {
           var logs = List.nil<(Nat, LogLevel,Text)>();
           var lastBlockTime = Time.now();
           var currentHeight = 0;
        }
    };

    public class LogServiceImpl(logModel : LogModel, maxLogSize : Nat, isDebug : Bool) {
        public func log(level : LogLevel, message : Text) : () {
            if(isDebug){
                Debug.print(message);
            };

            if(Time.now() > logModel.lastBlockTime){
                logModel.lastBlockTime := Time.now();
                logModel.currentHeight := logModel.currentHeight + 1;
            };
            
            logModel.logs := List.push((logModel.currentHeight, level, message), logModel.logs);
            if (List.size(logModel.logs) > maxLogSize){
                let (_, tmp) = List.pop(logModel.logs);
                logModel.logs := tmp;
            };
        };

        public func getLogs(height : ?Nat) : [Log] {
            switch(height){
                case(?h){
                    if (logModel.currentHeight < h) {
                        return List.toArray(logModel.logs);
                    };
                    List.filter(logModel.logs, func (x : Log) : Bool {x.0 >= h}) |>
                        List.toArray(_);
                };
                case(_){
                    return List.toArray(logModel.logs);
                };
            };
        };

        public func clearLogs(height : ?Nat) : () {
            switch(height){
                case(?h){
                    if (List.size(logModel.logs) < h) {
                        logModel.logs := List.nil<Log>();
                    };
                   logModel.logs := List.filter(logModel.logs, func (x : Log) : Bool {x.0 >= h});
                };
                case(_){
                    logModel.logs := List.nil<Log>();
                }
            }
        }
    };
}