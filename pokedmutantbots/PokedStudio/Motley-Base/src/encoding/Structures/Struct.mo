import Binary "../Binary";
import Blob "mo:base/Blob";
import Iter "mo:base/Iter";
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Option "mo:base/Option";
import { Null } "Tags";

module Struct = {

  public type Struct = (Tag, Length, Value);

  public type Tag = Nat32;
  public type Length = Nat32;
  public type Value = Blob;

  public type ByteIter = Iter.Iter<Nat8>;
  public type Staged = {
    size : () -> Nat;
    bytes : () -> ByteIter;
  };

  public type Pattern = {
    #varArray : [var Nat8];
    #array : [Nat8];
    #blob : Blob;
    #iter : Iter.Iter<Nat8>;
  };

  public module Tag = {

    public func raw( struct : Struct ) : Nat32 { struct.0 };
  
    public func set( struct : Struct, tag : Tag ) : Struct { (tag, struct.1, struct.2) };

    public func equal( struct : Struct, tag : Tag ) : Bool { struct.0 == tag };

    public func notEqual( struct : Struct, tag : Tag ) : Bool { struct.0 != tag };

    public func toArray( struct : Struct ) : [Nat8] {
      Binary.BigEndian.fromNat32( struct.0 )
    };

    public func toVarArray( struct : Struct ) : [var Nat8] {
      Array.thaw<Nat8>( Binary.BigEndian.fromNat32( struct.0 ) )
    };

  };

  public module Length = {

    public let empty : Nat32 = 0x00000000;

    public func raw( struct : Struct ) : Nat32 { struct.1 };

    public func set( struct : Struct, md : Length ) : Struct { (struct.0, md, struct.2) };

    public func equal( struct : Struct, n : Nat32 ) : Bool { struct.1 == n };

    public func notEqual( struct : Struct, n : Nat32 ) : Bool { struct.1 != n }; 

    public func toArray( struct : Struct ) : [Nat8] {
      Binary.BigEndian.fromNat32( struct.1 )
    };
    public func toVarArray( struct : Struct ) : [var Nat8] {
      Array.thaw<Nat8>( Binary.BigEndian.fromNat32( struct.1 ) )
    };

  };

  public module Value = {

    public func raw( struct : Struct ) : Blob { struct.2 };

    public func length( struct : Struct ) : Nat { Nat32.toNat(struct.1) };

    public func convert<T>( struct : Struct, fn : Blob -> T ) : T { fn( struct.2 ) };

    public func toArray( struct : Struct ) : [ Nat8 ] { Blob.toArray( struct.2 ) };

    public func toVarArray( struct : Struct ) : [ var Nat8 ] { Blob.toArrayMut( struct.2 ) };

    public func compare( sx : Struct, sy : Struct ) : {#less; #equal; #greater} {
      Blob.compare( sx.2, sy.2 )
    };

    public func set( struct : Struct, val : Pattern ) : Struct {
      switch val {
        case ( #varArray b ) (struct.0, struct.1, Blob.fromArrayMut( b ));
        case ( #array b ) (struct.0, struct.1, Blob.fromArray( b ));
        case ( #iter b ) (struct.0, struct.1, Blob.fromArray(Iter.toArray<Nat8>(b)));
        case ( #blob b ) (struct.0, struct.1, b);
      }
    };

  };

  public func empty() : Struct { build(null, null, null) };

  public func trap( _type : Text ) : () { Debug.trap("Faulty Structure: " # _type) };

  public func length( struct : Struct ) : Nat { Value.length(struct) + 8 };

  public func equal( sx : Struct, sy : Struct ) : Bool {
    sx.0 == sy.0 and sx.1 == sy.1 and sx.2 == sy.2
  };

  public func notEqual( sx : Struct, sy : Struct ) : Bool {
    sx.0 != sy.0 or sx.1 != sy.1 or sx.2 != sy.2
  };

  public func build( _tag : ?Tag, _len : ?Length, _val : ?Pattern ) : Struct {
    let t : Tag = Option.get<Tag>(_tag, Null.tag());
    let l : Length = Option.get<Length>(_len, Length.empty);
    let p : Pattern = Option.get<Pattern>(_val, #blob(""));
    let v : Value = switch( p ){
      case ( #varArray b ) Blob.fromArrayMut( b );
      case ( #array b ) Blob.fromArray( b );
      case ( #iter b ) Blob.fromArray(Iter.toArray<Nat8>(b));
      case ( #blob b ) b 
    };
    (t,l,v)
  };

  public func serialize( struct : Struct ) : (Nat, Iter.Iter<Nat8>) {
    var idx : Nat = 0;
    let size : Nat = length( struct );
    let tag : [Nat8] = Tag.toArray( struct );
    let val : [Nat8] = Value.toArray( struct );
    let len : [Nat8] = Length.toArray( struct );
    let payload : [var Nat8] = Array.init<Nat8>(size, 0);
    label l loop {
      if ( idx >= size ) break l;
      if ( idx < 4 ) payload[idx] := tag[idx]
      else if ( idx < 8 ) payload[idx] := len[idx-4]
      else payload[idx] := val[idx-8]
    };
    idx := 0;
    let bytes : [Nat8] = Array.freeze<Nat8>( payload );
    let byteIter = object {
      public func next() : ?Nat8 {
        if (idx >= size) {
          return null
        } else {
          let res = ?(bytes[idx]);
          idx += 1;
          return res
        }
      }
    };
    (size, byteIter)
  };

  public func deserialize( blob : Blob ) : Struct {
    let b : [Nat8] = Blob.toArray(blob);
    let tag : Nat32 = Binary.BigEndian.toNat32([b[0],b[1],b[2],b[3]]);
    let length : Nat32 = Binary.BigEndian.toNat32([b[4],b[5],b[6],b[7]]);
    let value : [var Nat8] = Array.init<Nat8>(Nat32.toNat(length), 0);
    for ( i in Iter.range(12, b.size()-1) ) value[i-12] := b[i];
    (tag, length, Blob.fromArrayMut( value ))
  };

}