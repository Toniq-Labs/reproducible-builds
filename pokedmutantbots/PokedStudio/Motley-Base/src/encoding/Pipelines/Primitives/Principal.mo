import Nat32 "mo:base/Nat32";
import Prin "../../Structures/Primitives/Principal";
import Piping "../Piping";

module {

  type Piping = Piping.Piping;

  public func pipe( prin : Principal ) : Piping {
    let (t, _l, v) = Prin.toStruct( prin );
    let l = Nat32.toNat( _l );
    Piping.pipe(?t, ?l, ?#blob(v));
  };

};