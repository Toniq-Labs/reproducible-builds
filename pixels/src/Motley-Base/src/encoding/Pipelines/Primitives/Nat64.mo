import Nat32 "mo:base/Nat32";
import Nat64 "../../Structures/Primitives/Nat64";
import Piping "../Piping";

module {

  type Piping = Piping.Piping;

  public func pipe( nat64 : Nat64 ) : Piping {
    let (t, _l, v) = Nat64.toStruct( nat64 );
    let l = Nat32.toNat( _l );
    Piping.pipe(?t, ?l, ?#blob(v));
  };

};