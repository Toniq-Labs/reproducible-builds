import Nat32 "mo:base/Nat32";
import Nat16 "../../Structures/Primitives/Nat16";
import Piping "../Piping";

module {

  type Piping = Piping.Piping;

  public func pipe( nat16 : Nat16 ) : Piping {
    let (t, _l, v) = Nat16.toStruct( nat16 );
    let l = Nat32.toNat( _l );
    Piping.pipe(?t, ?l, ?#blob(v));
  };

};