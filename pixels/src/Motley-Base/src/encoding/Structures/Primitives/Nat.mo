import Text "mo:base/Text";
import Char "mo:base/Char";
import Blob "mo:base/Blob";
import Nat8 "mo:base/Nat8";
import Nat16 "mo:base/Nat16";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import BaseLib "mo:base/Nat";
import Option "mo:base/Option";
import Binary "../../Binary";
import Struct "../Struct";
import { Nat } "../Tags";

module {

  type Struct = Struct.Struct;
  
  type Tag = Struct.Tag;
  type Length = Struct.Length;
  type Value = Struct.Value;
  
  public func tag() : Tag { Nat.tag() };

  public func valid( s : Struct ) : Bool {
    if ( Struct.Tag.notEqual(s, Nat.tag()) ) false
    else Struct.Value.length(s) > 0
  };

  public func toStruct( nat : Nat ) : Struct {
    let (size, value) : (Nat, [Nat8]) = 
      if ( nat <= 255 ) (1, [Nat8.fromNat( nat )])
      else if ( nat <= 65535 ) (2, Binary.BigEndian.fromNat16( Nat16.fromNat( nat ) ))
      else if ( nat <= 4294967295 ) (4, Binary.BigEndian.fromNat32( Nat32.fromNat( nat ) ))
      else if ( nat <= 9223372036854775807 ) (8, Binary.BigEndian.fromNat64( Nat64.fromNat( nat ) ))
      else {
        let blob : Blob = Text.encodeUtf8( BaseLib.toText( nat ) );
        (blob.size(), Blob.toArray(blob))
      };
    Struct.build(?Nat.tag(), ?Nat32.fromNat(size), ?#array( value ))
  };

  public func fromStruct( s : Struct ) : ?Nat {
    if ( Struct.Tag.notEqual(s, Nat.tag()) ) return null;
    if ( Struct.Value.length( s ) == 0 ) Struct.trap("Value field can't be empty for Type<Nat>"); 
    let bytes : [Nat8] = Struct.Value.toArray( s );
    if ( Struct.Value.length(s) == 1 ) ?Nat8.toNat( bytes[0] )
    else if ( Struct.Value.length(s) == 2 ) ?Nat16.toNat( Binary.BigEndian.toNat16( bytes ) )
    else if ( Struct.Value.length(s) == 4 ) ?Nat32.toNat( Binary.BigEndian.toNat32( bytes ) )
    else if ( Struct.Value.length(s) == 8 ) ?Nat64.toNat( Binary.BigEndian.toNat64( bytes ) )
    else {
      let opt : ?Text = Text.decodeUtf8( Blob.fromArray(bytes) );
      if ( Option.isNull(opt) ) return null;
      text_to_nat( Option.get<Text>(opt, "") );
    }
  };

  func text_to_nat( txt : Text) : ?Nat {
    let chars = txt.chars();
    var num : Nat = 0;
    for (v in chars){
      let charToNum = Nat32.toNat(Char.toNat32(v)-48);
      if (charToNum >= 0 and charToNum <= 9) num := num * 10 +  charToNum
      else return null;          
    };
    ?num;
  };

};