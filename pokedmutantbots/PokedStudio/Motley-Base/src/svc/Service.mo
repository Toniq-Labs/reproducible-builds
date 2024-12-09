import Blob "mo:base/Blob";
import Char "mo:base/Char";
import Text "mo:base/Text";
import Iter "mo:base/Iter";
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";

module Service {

  public type Handle = Blob;
  public type Domain = Blob;
  public type Version = Blob;
  public type Service = Blob;
  public type Signature = Text;

  let sid : [Nat8] = [10,115,101,114,118,105,99,101]; // \x0Aservice

  public module Handle {

    let lid : [Nat8] = [10,108,97,98,101,108]; // \x0AHandle

    public func equal( x : Handle, y : Handle ) : Bool { Blob.equal(x,y) };

    public func valid( x : Handle ) : Bool {
      if ( x.size() != 60 ) false
      else {
        let b : [Nat8] = Blob.toArray(x);
        if ( b[6] > 53 or b[6] == 0 ) return false;
        let ctrl : Blob = Blob.fromArray(lid);
        let test : Blob = Blob.fromArray([b[0],b[1],b[2],b[3],b[4],b[5]]);
        Blob.equal(test, ctrl);
      }
    };

    public func toText( x : Handle ) : ?Text {
      if ( not valid(x) ) return null;
      let b : [Nat8] = Blob.toArray(x);
      let l : [var Nat8] = Array.init<Nat8>(Nat8.toNat(b[6]),0);
      for ( i in Iter.range(0, Nat8.toNat(b[6]-1)) ) l[i] := b[i+7];
      Text.decodeUtf8( Blob.fromArray( Array.freeze(l) ) );
    };

    public func fromText( x : Text ) : ?Handle {
      assert x.size() > 0;
      if ( x.size() > 53 ) return null;
      let tag = Buffer.fromArray<Nat8>(lid);
      let length : Nat8 = Nat8.fromNat( x.size() );
      let value = Buffer.fromArray<Nat8>( Blob.toArray( Text.encodeUtf8(x) ));
      let padding = Buffer.fromVarArray<Nat8>( Array.init<Nat8>(Nat8.toNat(53-length), 0) );
      tag.add( length );
      tag.append( value );
      tag.append( padding );
      assert tag.size() == 60;
      ?Blob.fromArray( Buffer.toArray( tag ) );
    };

  };

  public module Version {

    let del : Char = '.'; // element delimeter for text representation

    let vid : [Nat8] = [10,118,101,114,115,105,111,110]; // \x0Aversion

    type Elements = (Nat8,Nat8,Nat8);

    public type Comparison = { #current; #rollback; #update : {#major; #minor; #patch} };

    public func valid( x : Version ) : Bool {
      if ( x.size() != 11 ) false
      else {
        let b : [Nat8] = Blob.toArray(x);
        let ctrl : Blob = Blob.fromArray(vid);
        let test : Blob = Blob.fromArray([b[0],b[1],b[2],b[3],b[4],b[5],b[6],b[7]]);
        Blob.equal(test, ctrl);
      }
    };

    public func compare( x : Version, y : Version ) : Comparison {
      assert valid(x) and valid(y);
      switch( Blob.compare(x, y) ){
        case( #equal ) #current;
        case( #less ) #rollback;
        case( #greater ){
          let xb : Elements = ver_to_elems(x);
          let yb : Elements = ver_to_elems(y);
          if ( Nat8.greater(xb.0, yb.0) ) #update( #major )
          else if ( Nat8.greater(xb.1, yb.1) ) #update( #minor )
          else #update( #patch );
        }
      }
    };

    public func toText( x : Version ) : Text {
      let e : Elements = ver_to_elems(x);
      Text.join(Text.fromChar(del), Array.map<Nat8,Text>([e.0, e.1, e.2],n2t).vals());
    };

    public func fromText( x : Text ) : ?Version {
      let parts : [Text] = Iter.toArray( Text.split(x, #char(del)) );
      if ( parts.size() != 3 ) null
      else ?elems_to_ver(t2n(parts[0]), t2n(parts[1]), t2n(parts[2]));
    };

    func ver_to_elems( x : Version ) : Elements {
      let b : [Nat8] = Blob.toArray(x);
      (b[8], b[9], b[10])      
    };

    func elems_to_ver( e : Elements ) : Version {
      let buffer = Buffer.fromArray<Nat8>(vid);
      buffer.append( Buffer.fromArray([e.0,e.1,e.2]) );
      Blob.fromArray( Buffer.toArray<Nat8>(buffer) );
    };

    func n2t( n : Nat8 ) : Text { Nat8.toText(n) };

    func t2n( txt : Text) : Nat8 {
      assert(txt.size() > 0);
      let chars = txt.chars();
      var num : Nat = 0;
      for (v in chars){
        let charToNum = Nat32.toNat(Char.toNat32(v)-48);
        assert(charToNum >= 0 and charToNum <= 9);
        num := num * 10 +  charToNum;          
      };
      Nat8.fromIntWrap(num);
    };
    
  };

}

