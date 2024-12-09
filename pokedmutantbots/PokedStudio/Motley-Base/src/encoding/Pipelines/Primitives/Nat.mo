import Nat32 "mo:base/Nat32";
import Nat "../../Structures/Primitives/Nat";
import Piping "../Piping";

module {

  type Piping = Piping.Piping;

  public func pipe( nat : Nat ) : Piping {
    let (t, _l, v) = Nat.toStruct( nat );
    let l = Nat32.toNat( _l );
    Piping.pipe(?t, ?l, ?#blob(v));
  };

};