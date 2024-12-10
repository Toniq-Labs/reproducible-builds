import Nat32 "mo:base/Nat32";
import Int64 "../../Structures/Primitives/Int64";
import Piping "../Piping";

module {

  type Piping = Piping.Piping;

  public func pipe( int64 : Int64 ) : Piping {
    let (t, _l, v) = Int64.toStruct( int64 );
    let l = Nat32.toNat( _l );
    Piping.pipe(?t, ?l, ?#blob(v));
  };

};