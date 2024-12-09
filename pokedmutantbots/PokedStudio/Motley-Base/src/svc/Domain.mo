import Blob "../base/Blob";
import Text "mo:base/Text";
import Nat8 "mo:base/Nat8";
import Array "mo:base/Array";
import Binary "../encoding/Binary";
import Handle "Handle";
import Struct "Struct";

module Domain {

  public type Domain = Struct.Struct;

  public type Handle = Handle.Handle;

  public type Record = { f0 : Text; f1 : Text; f2 : Text };

  public let tag : Nat32 = 0x0A000102; // Domain - Global

  public let instr : Nat64 = 0x5265636F72640003; // Record03

  public func equal( x : Domain, y : Domain ) : Bool { Struct.equal(x, y) };

  public func equal( x : Domain, y : Domain ) : Bool { Struct.notEqual(x, y) };

  public func valid( x : Domain ) : Bool {
    
    var count : Nat = 0;
    let endex : Nat = x.size()-1;
    let struct : [Nat8] = Blob.toArray(x);
    let _tag : [var Nat8] = [0, 0, 0, 0];
    let _len : [var Nat8] = [0, 0, 0, 0];
    let _t0t : [var Nat8] = [0, 0, 0, 0];
    let _t0l : [var Nat8] = [0, 0, 0, 0];
    let _t1t : [var Nat8] = [0, 0, 0, 0];
    let _t1l : [var Nat8] = [0, 0, 0, 0];
    let _t2t : [var Nat8] = [0, 0, 0, 0];
    let _t2l : [var Nat8] = [0, 0, 0, 0];
    label l loop {
      if ( count > endex ) break l;
      if ( count < 4 ) _tag[count] := struct[count]
      else if ( count < 8 ) _len[count-4] := struct[count]
      else if ( count < 12 ) _t0t[count-8] := struct[count]
      else if ( count < 16 ) _t0l[count-12] := struct[count]
      else if ( count >= lengthToNat(_t0l)+16 ){
        let t0base : Nat = lengthToNat(_t0l)+16;
        if count 
      };
      count += 1 
    };
    if ( x.size() > 104 ) false // A valid domain must contain, at a minimum, a tier0 handle (72 bytes)
    else if ( TLV.Tag.get(x) != Blob.fromArray(tag) ) false
    else if ( TLV.Length.get(x) != x.size()-8 ) false
    else {
      let tier0 = Blob.range(x, (9, x.size()-1));
      if ( TLV.Tag.get(fields) != Blob.fromArray(tier0tag) ) return false;
      let tier1 = Blob.range(tier0, (TLV.Length.get(tier0)+7, )) 
    } ( TLV.Tag.get(Blob.range(x, (9,))) )
  };

  public func toText( x : Handle ) : ?Text {
    if ( not valid(x) ) return null;
    let data : Blob = TLV.Value.get(x);
    let len : Nat = Nat8.toNat(Blob.index(data, 0));
    Text.decodeUtf8( Blob.range(x, (1, len)) );
  };

  public func fromText( x : Text ) : ?Handle {
    let size : Nat = x.size();
    if ( size == 0 or size > 63 ) return null;
    let value : [Nat8] = Blob.toArray( Text.encodeUtf8(x) );
    let length : [Nat8] = Binary.BigEndian.fromNat32(64);
    let struct : [var Nat8] = Array.init<Nat8>(72, 0);
    var count : Nat = 0;
    label l loop {
      if ( count > 71 ) break l
      else if ( count < 4 ) struct[count] := tag[count]
      else if ( count < 8 ) struct[count] := length[count-4]
      else if ( count == 8 ) struct[count] := Nat8.fromNat(size)
      else if ( count < size+9 ) struct[count] := value[count-9]
      else struct[count] := 0;
      count += 1 
    };
    ?Blob.fromArray( Array.freeze<Nat8>(struct) );
  };

};