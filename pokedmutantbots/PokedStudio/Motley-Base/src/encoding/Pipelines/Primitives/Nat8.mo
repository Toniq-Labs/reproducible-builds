import Nat32 "mo:base/Nat32";
import Nat8 "../../Structures/Primitives/Nat8";
import Piping "../Piping";

module {

  type Piping = Piping.Piping;

  public func pipe( nat8 : Nat8 ) : Piping {
    let (t, _l, v) = Nat8.toStruct( nat8 );
    let l = Nat32.toNat( _l );
    Piping.pipe(?t, ?l, ?#blob(v));
  };

};