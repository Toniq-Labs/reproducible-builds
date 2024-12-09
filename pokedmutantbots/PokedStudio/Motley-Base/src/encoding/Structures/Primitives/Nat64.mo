import BaseLib "mo:base/Nat64";
import Binary "../../Binary";
import Struct "../Struct";
import { Nat64 } "../Tags";

module {

  type Struct = Struct.Struct;
  
  type Tag = Struct.Tag;
  type Length = Struct.Length;
  type Value = Struct.Value;
  
  public func tag() : Tag { Nat64.tag() };

  public func valid( s : Struct ) : Bool {
    if ( Struct.Tag.notEqual(s, Nat64.tag()) ) false
    else Struct.Value.length(s) == 8
  };

  public func toStruct( nat64 : Nat64 ) : Struct {
    Struct.build(?Nat64.tag(), ?1, ?#array( Binary.BigEndian.fromNat64( nat64 ) ))
  };

  public func fromStruct( s : Struct ) : ?Nat64 {
    if ( Struct.Tag.notEqual(s, Nat64.tag()) ) return null;
    if ( Struct.Value.length( s ) != 8 ) Struct.trap("Incorrect length for Type<Nat64>");
    ?Binary.BigEndian.toNat64( Struct.Value.toArray(s) );
  }

};