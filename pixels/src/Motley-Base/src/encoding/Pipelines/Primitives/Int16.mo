import Nat32 "mo:base/Nat32";
import Int16 "../../Structures/Primitives/Int16";
import Piping "../Piping";

module {

  type Piping = Piping.Piping;

  public func pipe( int16 : Int16 ) : Piping {
    let (t, _l, v) = Int16.toStruct( int16 );
    let l = Nat32.toNat( _l );
    Piping.pipe(?t, ?l, ?#blob(v));
  };

};