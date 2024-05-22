
import Debug "mo:base/Debug";
import List "mo:base/List";
import Time "mo:base/Time";
import LT "./LogTypes";

module {
    public func initLogModel() : LT.LogModel {
        {
           var logs = List.nil<LT.Log>();
        }
    };

    public class LogServiceImpl(logModel : LT.LogModel, maxLogSize : Nat, isDebug : Bool) {

        public func addLog(_level : LT.LogLevel, _message : Text, _context : ?Text) : () {
            if(isDebug){
                Debug.print(_message);
            };

            let log = {
                timestamp = Time.now();
                level = _level;
                message = _message;
                context = _context;
            };  

            logModel.logs := List.push(log, logModel.logs);
            if (List.size(logModel.logs) > maxLogSize){
                let (_, tmp) = List.pop(logModel.logs);
                logModel.logs := tmp;
            };
        };

        public func logError(message : Text, context : ?Text) : () {
            addLog(#Error, message, context);
        };

        public func logWarn(message : Text, context : ?Text) : () {
            addLog(#Warn, message, context);
        };

        public func logInfo(message : Text, context : ?Text) : () {
            addLog(#Info, message, context);
        };
  

        public func getLogs(filter : ?LT.LogFilter) : [LT.Log] {
            List.filter(logModel.logs, func (x : LT.Log) : Bool {
                LT.matchLogFilter(filter, x);
            }) |>
                List.toArray(_);
        };

        public func clearLogs() : () {
            logModel.logs := List.nil<LT.Log>();
        }
    };
}