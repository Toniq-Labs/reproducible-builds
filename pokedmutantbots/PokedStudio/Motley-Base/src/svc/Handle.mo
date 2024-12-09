import Blob "../base/Blob";
import Text "mo:base/Text";
import Nat8 "mo:base/Nat8";
import Array "mo:base/Array";
import Option "mo:base/Option";
import Binary "../encoding/Binary";
import Struct "Struct";

module Handle {

  public type Handle = Struct.Struct;

  public let tag : Nat32 = 0x0A000101; // Handle - Global

  public func equal( x : Handle, y : Handle ) : Bool { Struct.equal(x, y) };

  public func notEqual( x : Handle, y : Handle ) : Bool { Struct.notEqual(x, y) };

  public func valid( h : Handle ) : Bool {
    if ( Struct.Tag.notEqual(h, tag) ) false
    else if ( Struct.Value.length(h) > 63 ) false
    else if ( Option.isNull( Text.decodeUtf8( Struct.Value.raw(h) ) ) ) false
    else true
  };

  public func toText( h : Handle ) : Text {
    Struct.Value.convert<Text>(h, func(x) {
      Option.get<Text>(Text.decodeUtf8(x), "")
    })
  };

  public func fromText( text : Text ) : ?Handle {
    let size : Nat = text.size();
    if ( size == 0 or size > 63 ) return null;
    ?Struct.build(tag, null, #blob(Text.encodeUtf8( text )))
  };

};