import BaseLib "mo:base/Nat8";
import Binary "../../Binary";
import Struct "../Struct";
import { Nat8 } "../Tags";

module {

  type Struct = Struct.Struct;
  
  type Tag = Struct.Tag;
  type Length = Struct.Length;
  type Value = Struct.Value;
  
  public func tag() : Tag { Nat8.tag() };

  public func valid( s : Struct ) : Bool {
    if ( Struct.Tag.notEqual(s, Nat8.tag()) ) false
    else Struct.Value.length(s) == 1
  };

  public func toStruct( nat8 : Nat8 ) : Struct {
    Struct.build(?Nat8.tag(), ?1, ?#array( [nat8] ))
  };

  public func fromStruct( s : Struct ) : ?Nat8 {
    if ( Struct.Tag.notEqual(s, Nat8.tag()) ) return null;
    if ( Struct.Value.length( s ) != 1 ) Struct.trap("Incorrect length for Type<Nat8>");
    ?Struct.Value.toArray(s)[0];
  }

};