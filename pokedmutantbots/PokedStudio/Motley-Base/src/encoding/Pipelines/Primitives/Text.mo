import Nat32 "mo:base/Nat32";
import Text "../../Structures/Primitives/Text";
import Piping "../Piping";

module {

  type Piping = Piping.Piping;

  public func pipe( text : Text ) : Piping {
    let (t, _l, v) = Text.toStruct( text );
    let l = Nat32.toNat( _l );
    Piping.pipe(?t, ?l, ?#blob(v));
  };

};