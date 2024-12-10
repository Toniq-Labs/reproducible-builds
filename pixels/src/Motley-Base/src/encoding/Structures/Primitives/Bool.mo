import Nat32 "mo:base/Nat32";
import BaseLib "mo:base/Bool";
import Option "mo:base/Option";
import Struct "../Struct";
import { Bool } "../Tags";

module {

  type Struct = Struct.Struct;
  
  type Tag = Struct.Tag;
  type Length = Struct.Length;
  type Value = Struct.Value;
  
  public func tag() : Tag { Bool.tag() };

  public func valid( s : Struct ) : Bool { 
    if ( Struct.Tag.notEqual(s, Bool.tag()) ) false
    else Struct.Value.length(s) == 1
  };

  public func toStruct( bool : Bool ) : Struct {
    let value : Nat8 = if bool 1 else 0;
    Struct.build(?Bool.tag(), ?Nat32.fromNat(1), ?#array( [value] ))
  };

  public func fromStruct( s : Struct ) : ?Bool {
    if ( Struct.Tag.notEqual(s, Bool.tag()) ) return null;
    if ( Struct.Value.length(s) != 1 ) Struct.trap("Length of Type<Bool> must equal 1");
    let value : Nat8 = Struct.Value.toArray(s)[0];
    if ( value > 1 ) Struct.trap("Value of Type<Bool> must be <= 1");
    if ( value == 1 ) ?true
    else ?false;
  }

};