import Blob "../base/Blob";
import Char "mo:base/Char";
import Text "mo:base/Text";
import Iter "mo:base/Iter";
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Struct "Struct";

module Version {

  public type Version = Struct.Struct;

  public type Elements = [var Nat8];
  public type Release = { #major; #minor; #patch };
  public type Comparison = { #current; #rollback; #update : Release };

  public let tag : Struct.Tag = 0x0A000103; // Version - Global

  public func valid( v : Version ) : Bool {
    if ( Struct.Tag.notEqual(v, tag) ) false
    else if( Struct.Value.length(v) > 3 ) false
    else true
  };

  public func build( raw : [Nat8], _meta : ?Nat64 ) : Version {
    let version = Struct.build(tag, _meta, #array( raw ));
    assert valid( version );
    version
  };

  public func increment( v : Version, r : Release ) : Version {
    let elems : Elements = Struct.Value.toVarArray( v );
    switch r {
      case( #major ) elems[0] += 1;
      case( #minor ) elems[1] += 1;
      case( #patch ) elems[2] += 1;
    };
    Struct.Value.replace(v, #varArray(elems));
  };

  public func compare( x : Version, y : Version ) : Comparison {
    assert valid(x) and valid(y);
    switch( Struct.Value.compare(x, y) ){
      case( #equal ) #current;
      case( #less ) #rollback;
      case( #greater ){
        let xb : Elements = Struct.Value.toVarArray( x );
        let yb : Elements = Struct.Value.toVarArray( y );
        if ( xb[0] > yb[0] ) #update( #major )
        else if ( xb[1] > yb[1] ) #update( #minor )
        else #update( #patch );
      }
    }
  };

  public func toText( v : Version ) : Text {
    let elems : [Nat8] = Struct.Value.toArray( v );
    Text.join(Text.fromChar('.'), Array.map<Nat8,Text>(elems, n2t).vals());
  };

  public func fromText( x : Text ) : Version {
    let elems : [Text] = Iter.toArray( Text.split(x, #char('.')) );
    assert elems.size() == 3;
    for ( elem in elems.vals() ) assert elem.size() <= 3;
    Struct.build(tag, null, #array([t2n(elems[0]),t2n(elems[1]),t2n(elems[2])]));
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