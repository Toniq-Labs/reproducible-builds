import I "Int";
import Int "mo:base/Int";
import BaseLib "mo:base/Int16";
import Binary "../../Binary";
import Struct "../Struct";
import { Int16 } "../Tags";

module {

  type Struct = Struct.Struct;
  
  type Tag = Struct.Tag;
  type Length = Struct.Length;
  type Value = Struct.Value;
  
  public func tag() : Tag { Int16.tag() };

  public func valid( s : Struct ) : Bool {
    if ( Struct.Tag.notEqual(s, Int16.tag()) ) false
    else Struct.Value.length(s) == 3
  };

  public func toStruct( int16 : Int16 ) : Struct {
    let flag : Nat8 = if ( int16 < 0 ) 1 else 0;
    let nat : Nat = Int.abs( BaseLib.toInt( int16 ) );
    let (_, value) =  I.wrap_signed_value(flag, nat, #n16);
    Struct.build(?Int16.tag(), ?3, ?#array( value ))
  };

  public func fromStruct( s : Struct ) : ?Int16 {
    if ( Struct.Tag.notEqual(s, Int16.tag()) ) return null;
    if ( Struct.Value.length( s ) != 3 ) Struct.trap("Incorrect length for Type<Int16>");
    ?BaseLib.fromInt( I.unwrap_signed_value(Struct.Value.toArray(s), 2) );
  }

};