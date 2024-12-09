import Nat32 "mo:base/Nat32";
import Int "../../Structures/Primitives/Int";
import Piping "../Piping";

module {

  type Piping = Piping.Piping;

  public func pipe( int : Int ) : Piping {
    let (t, _l, v) = Int.toStruct( int );
    let l = Nat32.toNat( _l );
    Piping.pipe(?t, ?l, ?#blob(v));
  };

};