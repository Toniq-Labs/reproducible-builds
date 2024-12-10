import Nat32 "mo:base/Nat32";
import Int8 "../../Structures/Primitives/Int8";
import Piping "../Piping";

module {

  type Piping = Piping.Piping;

  public func pipe( int8 : Int8 ) : Piping {
    let (t, _l, v) = Int8.toStruct( int8 );
    let l = Nat32.toNat( _l );
    Piping.pipe(?t, ?l, ?#blob(v));
  };

};