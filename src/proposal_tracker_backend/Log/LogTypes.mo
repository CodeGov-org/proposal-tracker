import List "mo:base/List";
import Int "mo:base/Int";
import Option "mo:base/Option";
import Result "mo:base/Result";
import Text "mo:base/Text";
module {
    public type LogLevel = {
        #Error;
        #Warn;
        #Info;
    };

    public type LogFilter = {
        beforeTimestampMs : ?Int;
        afterTimestampMs : ?Int;
        level : ?LogLevel;
        messageContains : ?Text;
        contextContains : ?Text;
        matchAll : ?Bool;
    };

    public type LogService = {
        addLog : (level : LogLevel, message : Text, context : ?Text) -> ();
        logError : (message : Text, context : ?Text) -> ();
        logWarn : (message : Text, context : ?Text) -> ();
        logInfo : (message : Text, context : ?Text) -> ();
        getLogs : (?LogFilter) -> [Log];
        clearLogs() : ();
    };

    public type Log ={
        timestamp : Int;
        level : LogLevel;
        message : Text;
        context : ?Text;
    };

    public type LogList= List.List<Log>;
    public type LogModel = {
        var logs : LogList;
    };

    public func optToRes<T>(opt : ?T) : Result.Result<T, ()> {
        switch(opt){
            case (?t) {
                return #ok(t);
            };
            case (_) {
                return #err();
            };
        };
    };

    public func matchLogFilter(_filter : ?LogFilter, log : Log) : Bool {
        let #ok(filter) = optToRes<LogFilter>(_filter)
        else {
            return true;
        };

        let matchAll = Option.get(filter.matchAll, false);
        
        switch(filter.beforeTimestampMs){
            case(?t) {
                if (log.timestamp < t and not matchAll) {
                    return true;
                } else if (log.timestamp > t and matchAll){
                    return false;
                }
            };
            case(_) {};
        };

        switch(filter.afterTimestampMs){
            case(?t) {
                if (log.timestamp > t and not matchAll) {
                    return true;
                } else if (log.timestamp < t and matchAll){
                    return false;
                }
            };
            case(_) {};
        };

        switch(filter.level){
            case(?t) {
                if (log.level == t and not matchAll) {
                    return true;
                } else if (log.level != t and matchAll){
                    return false;
                }
            };
            case(_) {};
        };

        switch(filter.messageContains){
            case(?t) {
                if (Text.contains(log.message, #text t) and not matchAll) {
                    return true;
                } else if (not Text.contains(log.message, #text t) and matchAll){
                    return false;
                }
            };
            case(_) {};
        };

        switch((filter.contextContains, log.context)){
            case((?fc,?lc)) {
                if (Text.contains(lc, #text fc) and not matchAll) {
                    return true;
                } else if (not Text.contains(lc, #text fc) and matchAll){
                    return false;
                }
            };
            case((?fc, _)) {
                if(matchAll){
                    return false;
                }
            };
            case((_, _)){};
        };
        
        if(matchAll){
            return true;
        } else {
            return false;
        }
        
    };

}