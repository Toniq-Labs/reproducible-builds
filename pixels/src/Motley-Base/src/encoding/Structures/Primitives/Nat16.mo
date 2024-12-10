import BaseLib "mo:base/Nat16";
import Binary "../../Binary";
import Struct "../Struct";
import { Nat16 } "../Tags";

module {

  type Struct = Struct.Struct;
  
  type Tag = Struct.Tag;
  type Length = Struct.Length;
  type Value = Struct.Value;
  
  public func tag() : Tag { Nat16.tag() };

  public func valid( s : Struct ) : Bool {
    if ( Struct.Tag.notEqual(s, Nat16.tag()) ) false
    else Struct.Value.length(s) == 2
  };

  public func toStruct( nat16 : Nat16 ) : Struct {
    Struct.build(?Nat16.tag(), ?1, ?#array( Binary.BigEndian.fromNat16( nat16 ) ))
  };

  public func fromStruct( s : Struct ) : ?Nat16 {
    if ( Struct.Tag.notEqual(s, Nat16.tag()) ) return null;
    if ( Struct.Value.length( s ) != 2 ) Struct.trap("Incorrect length for Type<Nat16>");
    ?Binary.BigEndian.toNat16( Struct.Value.toArray(s) );
  }

};