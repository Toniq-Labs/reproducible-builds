import Nat32 "mo:base/Nat32";
import Bool "../../Structures/Primitives/Bool";
import Piping "../Piping";

module {

  type Piping = Piping.Piping;

  public func pipe( bool : Bool ) : Piping {
    let (t, _l, v) = Bool.toStruct( bool );
    let l = Nat32.toNat( _l );
    Piping.pipe(?t, ?l, ?#blob(v));
  };

};