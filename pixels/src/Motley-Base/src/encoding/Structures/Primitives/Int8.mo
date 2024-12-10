import Int "Int";
import BaseLib "mo:base/Int8";
import Binary "../../Binary";
import Struct "../Struct";
import { Int8 } "../Tags";

module {

  type Struct = Struct.Struct;
  
  type Tag = Struct.Tag;
  type Length = Struct.Length;
  type Value = Struct.Value;
  
  public func tag() : Tag { Int8.tag() };

  public func valid( s : Struct ) : Bool {
    if ( Struct.Tag.notEqual(s, Int8.tag()) ) false
    else Struct.Value.length(s) == 2
  };

  public func toStruct( int8 : Int8 ) : Struct {
    let flag : Nat8 = if ( int8 < 0 ) 1 else 0;
    let bytes : [Nat8] = [flag, BaseLib.toNat8(int8)];
    Struct.build(?Int8.tag(), ?1, ?#array( bytes ))
  };

  public func fromStruct( s : Struct ) : ?Int8 {
    if ( Struct.Tag.notEqual(s, Int8.tag()) ) return null;
    if ( Struct.Value.length( s ) != 2 ) Struct.trap("Incorrect length for Type<Int8>");
    ?BaseLib.fromNat8( Struct.Value.toArray(s)[0] );
  }

};