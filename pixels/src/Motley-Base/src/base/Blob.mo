import Prim "mo:⛔";
import Blob "mo:base/Blob";
import Struct "../encoding/Struct";

module {

  public type Blob = Prim.Types.Blob;

  /// Base functions - Copied directly from the Motoko-base repository
  public let hash = Blob.hash;
  public let equal = Blob.equal;
  public let notEqual = Blob.notEqual;
  public let less = Blob.less;
  public let lessOrEqual = Blob.lessOrEqual;
  public let greater = Blob.greater;
  public let greaterOrEqual = Blob.greaterOrEqual;
  public let compare = Blob.compare;
  public let fromArray = Blob.fromArray;
  public let toArray = Blob.toArray;
  public let fromArrayMut = Blob.fromArrayMut;
  public let toArrayMut = Blob.toArrayMut;

  /// Motley Functions
  public func range( x : Blob, r : (Nat,Nat) ) : Blob {
    assert x.size() > r.1;
    let buff = Prim.Array_init<Nat8>(r.1-(r.0)+1, 0);
    let bytes : [Nat8] = toArray(x);
    var i_index : Nat = r.0;
    var o_index : Nat = 0;  
    label l loop {
      if ( i_index > r.1 ) break l;
      buff[o_index] := bytes[i_index];
      i_index += 1;
      o_index += 1;
    };
    fromArrayMut( buff );
  };  

}