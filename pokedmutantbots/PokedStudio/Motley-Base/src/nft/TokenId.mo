import Text "../base/Text";
import Nat8 "mo:base/Nat8";
import Blob "mo:base/Blob";
import Iter "mo:base/Iter";
import Nat32 "mo:base/Nat32";
import Principal "../base/Principal";
import Buffer "mo:base/Buffer";
import Array "mo:base/Array";
import Encoding "../encoding/Binary";

module TokenId = {

  public type TokenId = Text;

  public type TokenIndex = Nat32;

  public type TokenObj = {
    index : TokenIndex;
    canister : [Nat8];
  };

  private let tds : [Nat8] = [10, 116, 105, 100]; //b"\x0Atid"

  public let equal = Text.equal;

  public let hash = Text.hash;

  public func isPrincipal(tid : TokenId, p : Principal) : Bool {
    let tobj = decode(tid);
    Blob.equal(Blob.fromArray(tobj.canister), Principal.toBlob(p));
  };

  public func index(tid : TokenId) : TokenIndex {
    let tobj = decode(tid);
    tobj.index;
  };

  public func fromText(t : Text, i : TokenIndex) : TokenId {
    fromPrincipal(Principal.fromText(t), i);
  };

  public func fromPrincipal(p : Principal, i : TokenIndex) : TokenId {
    fromBlob(Principal.toBlob(p), i);
  };

  public func fromBlob(b : Blob, i : TokenIndex) : TokenId {
    fromBytes(Blob.toArray(b), i);
  };

  public func fromBytes(c : [Nat8], i : TokenIndex) : TokenId {
    let _tindex = Buffer.fromArray<Nat8>( Encoding.BigEndian.fromNat32(i) );
    let _canister = Buffer.fromArray<Nat8>( c );
    let _tds = Buffer.fromArray<Nat8>( tds );
    _tds.append( _canister );
    _tds.append( _tindex );
    Principal.toText(
      Principal.fromBlob(
        Blob.fromArray(
          Buffer.toArray<Nat8>( _tds )
        )
      )
    )
  };

  public func decode(tid : TokenId) : TokenObj {
    let bytes = Blob.toArray(Principal.toBlob(Principal.fromText(tid)));
    let size     : Nat    = bytes.size();
    let tdscheck : [Nat8] = [ bytes[0], bytes[1], bytes[2], bytes[3] ];
    if ( Array.equal(tds, tdscheck, Nat8.equal) ){
      let canister : [Nat8] = byte_range(bytes, 4, (size - 5));
      let tindex   : [Nat8] = byte_range(bytes, (size - 4), (size - 1));
      return {
        index = bytestonat32( tindex );
        canister = canister;
      }
    } else {
      return {
        index = 0;
        canister = bytes;
      }
    }
  };

  func byte_range( b : [Nat8], start : Nat, stop : Nat ) : [Nat8] {
    let buffer = Buffer.Buffer<Nat8>((stop - start) +1);
    for ( i in Iter.range(start,stop) ) buffer.add( b[i] );
    Buffer.toArray(buffer);
  };
    
  func bytestonat32(b : [Nat8]) : Nat32 {
    var index : Nat32 = 0;
    Array.foldRight<Nat8, Nat32>(b, 0, func (u8, accum) {
      index += 1;
      accum + Nat32.fromNat(Nat8.toNat(u8)) << ((index-1) * 8);
    });
  };

  func nat32tobytes(n : Nat32) : [Nat8] {
    if (n < 256) {
      return [1, Nat8.fromNat(Nat32.toNat(n))];
    } else if (n < 65536) {
      return [
        2,
        Nat8.fromNat(Nat32.toNat((n >> 8) & 0xFF)), 
        Nat8.fromNat(Nat32.toNat((n) & 0xFF))
      ]
    } else if (n < 16777216) {
      return [
        3,
        Nat8.fromNat(Nat32.toNat((n >> 16) & 0xFF)), 
        Nat8.fromNat(Nat32.toNat((n >> 8) & 0xFF)), 
        Nat8.fromNat(Nat32.toNat((n) & 0xFF))
      ]
    } else {
      return [
        4,
        Nat8.fromNat(Nat32.toNat((n >> 24) & 0xFF)), 
        Nat8.fromNat(Nat32.toNat((n >> 16) & 0xFF)), 
        Nat8.fromNat(Nat32.toNat((n >> 8) & 0xFF)), 
        Nat8.fromNat(Nat32.toNat((n) & 0xFF))
      ]
    }
  };

}; 