import Nat32 "mo:base/Nat32";
import Int32 "../../Structures/Primitives/Int32";
import Piping "../Piping";

module {

  type Piping = Piping.Piping;

  public func pipe( int32 : Int32 ) : Piping {
    let (t, _l, v) = Int32.toStruct( int32 );
    let l = Nat32.toNat( _l );
    Piping.pipe(?t, ?l, ?#blob(v));
  };

};