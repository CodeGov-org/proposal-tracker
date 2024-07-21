import Result "mo:base/Result";
import Map "mo:map/Map";
module {
    //TODO: deprecate
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

    public func arrayToSet<T>(arr : [T], hash : Map.HashUtils<T>) : Map.Map<T, ()> {
        var set = Map.new<T, ()>();
        for(i in arr.vals()) {
            Map.set(set, hash, i, ());
        };
        return set;
    };


    // public func unwrapOr<T, V>(val : Result.Result<?T, V>, f : (?T) -> Result.Result<T, V> , err : V) : Result.Result<T, V> {
    //     switch(val){
    //         case(#ok(opt)) {
    //             switch(opt){
    //                 case(?t) {
    //                     return #ok(f(t));
    //                 };
    //                 case(_){
    //                     return #err(err);
    //                 }
    //             }
    //         };
    //         case(#err(e)){
    //             return #err(e);
    //         };
    //     }
    // };

    public func getElseCreate<K, V>(map : Map.Map<K, V>, hash : Map.HashUtils<K>, key : K, val :  V) : V {
        switch(Map.get(map, hash, key)){
            case(?v) {
                return v;
            };
            case(_){
                Map.set(map, hash, key, val);
                return val;
            };
        };
    };
}