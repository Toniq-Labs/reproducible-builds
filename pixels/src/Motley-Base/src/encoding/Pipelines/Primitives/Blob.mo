import Nat32 "mo:base/Nat32";
import Blob "../../Structures/Primitives/Blob";
import Piping "../Piping";

module {

  type Piping = Piping.Piping;

  public func pipe( blob : Blob ) : Piping {
    let (t, _l, v) = Blob.toStruct( blob );
    let l = Nat32.toNat( _l );
    Piping.pipe(?t, ?l, ?#blob(v));
  };

};