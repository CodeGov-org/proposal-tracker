import Result "mo:base/Result";

module {

    
   public type Vote = {
        #Unspecified; //0
        #Yes; //1
        #No; //2
    };

    public func tryMapVote(vote: Int32): Result.Result<Vote, Text> {
        switch(vote){
            case(0){#ok(#Unspecified)};
            case(1){#ok(#Yes)};
            case(2){#ok(#No)};
            case(_){#err("Unknown vote value")};
        }
    };
}