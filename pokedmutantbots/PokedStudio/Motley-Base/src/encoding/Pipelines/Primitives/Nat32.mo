import BaseLib "mo:base/Nat32";
import Nat32 "../../Structures/Primitives/Nat32";
import Piping "../Piping";

module {

  type Piping = Piping.Piping;

  public func pipe( nat64 : Nat32 ) : Piping {
    let (t, _l, v) = Nat32.toStruct( nat64 );
    let l = BaseLib.toNat( _l );
    Piping.pipe(?t, ?l, ?#blob(v));
  };

};