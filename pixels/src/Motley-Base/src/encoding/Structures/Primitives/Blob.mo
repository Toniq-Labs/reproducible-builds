import Nat32 "mo:base/Nat32";
import BaseLib "mo:base/Blob";
import Option "mo:base/Option";
import Struct "../Struct";
import { Blob } "../Tags";

module {

  type Struct = Struct.Struct;
  
  type Tag = Struct.Tag;
  type Length = Struct.Length;
  type Value = Struct.Value;
  
  public func tag() : Tag { Blob.tag() };

  public func valid( s : Struct ) : Bool { Struct.Tag.equal(s, Blob.tag()) };

  public func toStruct( blob : Blob ) : Struct {
    Struct.build(?Blob.tag(), ?Nat32.fromNat(blob.size()), ?#blob( blob ))
  };

  public func fromStruct( s : Struct ) : ?Blob {
    if ( Struct.Tag.notEqual(s, Blob.tag()) ) return null;
    ?Struct.Value.raw(s);
  }

};