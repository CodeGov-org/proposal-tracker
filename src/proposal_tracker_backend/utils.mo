import Result "mo:base/Result";
module {
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
}