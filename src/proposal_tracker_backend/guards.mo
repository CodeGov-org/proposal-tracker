import Result "mo:base/Result";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Debug "mo:base/Debug";
import Bool "mo:base/Bool";
import List "mo:base/List";
  
module{

  public func isAnonymous(caller : Principal) : Bool {
      Principal.equal(caller, Principal.fromText("2vxsx-fae"));
  };

  public func isCanisterPrincipal(p : Principal) : Bool {
    let principal_text = Principal.toText(p);
    let correct_length = Text.size(principal_text) == 27;
    let correct_last_characters = Text.endsWith(principal_text, #text "-cai");

    if (Bool.logand(correct_length, correct_last_characters)) {
      return true;
    };
    return false;
  };
    
  public func isCustodian(caller : Principal, custodians : List.List<Principal>) : Bool {
    Debug.print(debug_show (caller));
    if (not List.some(custodians, func(custodian : Principal) : Bool { custodian == caller })) {
      return false;
    };
    return true;
  };

}