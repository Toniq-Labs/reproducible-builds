import { Object; Array; Null; Mutable } "../Structures/Tags";
import Binary "../Binary";
import Blob "mo:base/Blob";
import Iter "mo:base/Iter";
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Arrays "mo:base/Array";
import Debug "mo:base/Debug";
import Option "mo:base/Option";

module Pipeline = {

  public type Tag = Nat32;
  public type Length = Nat;
  public type Value = Blob;

  public type ByteIter = Iter.Iter<Nat8>;

  public type Piping = {
    tag : () -> Tag;
    length : () -> Nat;
    next : () -> ?Nat8;
  };

  public type Pattern = {
    #varArray : [var Nat8];
    #array : [Nat8];
    #blob : Blob;
    #iter : Iter.Iter<Nat8>;
  };

  public func empty() : Piping { pipe(null, null, null) };

  public func wrap_array( _t : Tag, pa : [Piping] ) : Piping {
    var l : Nat = pa.size();
    let t : Tag = Array.tag() | _t;
    for ( entry in pa.vals() ){ assert entry.tag() == _t };
    wrap_record(t, pa);
  };

  public func wrap_mutable( p : Piping ) : Piping {
    let l : Nat = 8;
    var idx : Nat = 0;
    let t : Tag = Mutable.tag();
    var _tag : ByteIter = object { public func next() : ?Nat8 { null } };
    var _len : ByteIter = object { public func next() : ?Nat8 { null } };
    object {
      public func tag() : Tag { t };
      public func length() : Nat { l };
      public func next() : ?Nat8 {
        if ( idx == 0 ){ _tag := Binary.BigEndian.fromNat32(t).vals() };
        if ( idx == 4 ){ _len := Binary.BigEndian.fromNat32(Nat32.fromNat(0)).vals() };
        let resp : ?Nat8 =
          if ( idx < 4 ) _tag.next()
          else if ( idx < 8 ) _len.next()
          else p.next();
        if ( idx < 8 ) idx += 1;
        resp
      };
    }
  }; 

  public func wrap_record( _t : Tag, pa : [Piping] ) : Piping {
    let l : Nat = 8 + Arrays.foldLeft<Piping,Nat>(pa, 0, func(_,x) { x.length() });
    let t : Tag = Object.tag() | _t;
    let endex : Nat = pa.size();
    var idx : Nat = 0;
    var idy : Nat = 0;
    var _tag : ByteIter = object { public func next() : ?Nat8 { null } };
    var _len : ByteIter = object { public func next() : ?Nat8 { null } };
    var _val : ByteIter = object { public func next() : ?Nat8 { null } };
    object {
      public func tag() : Tag { t };
      public func length() : Nat { l };
      public func next() : ?Nat8 {
        if ( idy >= endex ) return null;
        if ( idx == 0 ){ _tag := Binary.BigEndian.fromNat32(t).vals() };
        if ( idx == 4 ){ _len := Binary.BigEndian.fromNat32(Nat32.fromNat(endex)).vals() };
        let resp : ?Nat8 =
          if ( idx < 4 ) _tag.next()
          else if ( idx < 8 ) _len.next()
          else {
            switch( pa[idy].next() ){
              case ( ?some ) ?some;
              case null {
                if ( idy + 1 >= l ) null
                else { idy += 1; pa[idy].next() }
              }
            }
          };
        if ( idx < 8 ) idx += 1;
        idy += 1;
        resp
      };
    }
  };

  public func pipe( _t : ?Tag, _l : ?Length, _v : ?Pattern ) : Piping {
    let t : Tag = Option.get<Tag>(_t, Null.tag());
    let l : Length = Option.get<Length>(_l, 0);
    let p : Pattern = Option.get<Pattern>(_v, #blob(""));
    let v : Value = switch( p ){
      case ( #varArray b ) Blob.fromArrayMut( b );
      case ( #array b ) Blob.fromArray( b );
      case ( #iter b ) Blob.fromArray(Iter.toArray<Nat8>(b));
      case ( #blob b ) b 
    };
    var idx : Nat = 0;
    var _tag : ByteIter = object { public func next() : ?Nat8 { null } };
    var _len : ByteIter = object { public func next() : ?Nat8 { null } };
    var _val : ByteIter = object { public func next() : ?Nat8 { null } };
    object {
      public func tag() : Tag { t };
      public func length() : Nat { l };
      public func next() : ?Nat8 {
        if ( idx >= l ) return null;
        if ( idx == 0 ){ _tag := Binary.BigEndian.fromNat32(t).vals() };
        if ( idx == 4 ){ _len := Binary.BigEndian.fromNat32(Nat32.fromNat(l)).vals() };
        if ( idx == 8 ){ _val := v.vals() };
        let resp : ?Nat8 =
          if ( idx < 4 ) _tag.next()
          else if ( idx < 8 ) _len.next()
          else _val.next();
        idx += 1;
        resp
      };
    }
  };

}