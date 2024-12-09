import I "Int";
import Int "mo:base/Int";
import BaseLib "mo:base/Int32";
import Binary "../../Binary";
import Struct "../Struct";
import { Int32 } "../Tags";

module {

  type Struct = Struct.Struct;
  
  type Tag = Struct.Tag;
  type Length = Struct.Length;
  type Value = Struct.Value;
  
  public func tag() : Tag { Int32.tag() };

  public func valid( s : Struct ) : Bool {
    if ( Struct.Tag.notEqual(s, Int32.tag()) ) false
    else Struct.Value.length(s) == 5
  };

  public func toStruct( int32 : Int32 ) : Struct {
    let flag : Nat8 = if ( int32 < 0 ) 1 else 0;
    let nat : Nat = Int.abs( BaseLib.toInt( int32 ) );
    let (_, value) =  I.wrap_signed_value(flag, nat, #n32);
    Struct.build(?Int32.tag(), ?5, ?#array( value ))
  };

  public func fromStruct( s : Struct ) : ?Int32 {
    if ( Struct.Tag.notEqual(s, Int32.tag()) ) return null;
    if ( Struct.Value.length( s ) != 5 ) Struct.trap("Incorrect length for Type<Int32>");
    ?BaseLib.fromInt( I.unwrap_signed_value(Struct.Value.toArray(s), 4) );
  }

};