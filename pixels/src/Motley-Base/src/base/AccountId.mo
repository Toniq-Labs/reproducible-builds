/**
Generates AccountId's for the IC (32 bytes). Use with 
hex library to generate corresponding hex address.
Uses custom SHA224 and CRC32 motoko libraries
 */

import Nat8 "mo:base/Nat8";
import Option "mo:base/Option";
import Principal "../base/Principal";
import Buffer "mo:base/Buffer";
import Iter "mo:base/Iter";
import Blob "mo:base/Blob";
import Array "mo:base/Array";
import Text "../base/Text";
import SHA224 "../encoding/sha224";
import CRC32 "../encoding/crc32";
import Hex "../encoding/Hex";

module {

  public type AccountId = Text;

  public type SubAccount = [Nat8];
  
  private let ads : [Nat8] = [10, 97, 99, 99, 111, 117, 110, 116, 45, 105, 100]; //b"\x0Aaccount-id"
  public let SUBACCOUNT_ZERO : [Nat8] = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0];

  //Public functions
  public func fromText(t : Text, sa : ?SubAccount) : AccountId {
    return fromPrincipal(Principal.fromText(t), sa);
  };
  public func fromPrincipal(p : Principal, sa : ?SubAccount) : AccountId {
    return fromBlob(Principal.toBlob(p), sa);
  };
  public func fromBlob(b : Blob, sa : ?SubAccount) : AccountId {
    return fromBytes(Blob.toArray(b), sa);
  };
  public func fromBytes(data : [Nat8], sa : ?SubAccount) : AccountId {
    let aid = Buffer.fromArray<Nat8>( ads );
    aid.append( Buffer.fromArray<Nat8>( data ) );
    aid.append( Buffer.fromArray<Nat8>( Option.get(sa, SUBACCOUNT_ZERO) ) );
    var hash = Buffer.fromArray<Nat8>( SHA224.sha224( Buffer.toArray<Nat8>( aid ) ) );
    var crc = Buffer.fromArray<Nat8>( CRC32.crc32(hash.vals()) );
    crc.append(hash);
    Hex.encode( Buffer.toArray<Nat8>(crc) );
  };

  public let equal = Text.equal;
  public let notEqual = Text.notEqual;
  public let hash = Text.hash;

  public func valid( aid : AccountId ) : Bool {
    Option.isSome( toBlob( aid ) );
  };

  public func toBlob( aid : AccountId ) : ?Blob {
    switch( Hex.decode( aid ) ){
      case ( #err(_) ) null;
      case ( #ok( b ) ){
        if ( b.size() != 32 ) null
        else {
          let crcx : [Nat8] = byte_range(b,0,3);
          let crcy : [Nat8] = CRC32.crc32(Iter.fromArray(byte_range(b,4,31)));
          if ( not Array.equal(crcx, crcy, Nat8.equal) ) null
          else ?Blob.fromArray(b);
        }
      }
    }
  };

  func byte_range( b : [Nat8], start : Nat, stop : Nat ) : [Nat8] {
    let buffer = Buffer.Buffer<Nat8>((stop - start) +1);
    for ( i in Iter.range(start,stop) ) buffer.add( b[i] );
    Buffer.toArray(buffer);
  };

  public module Struct {}
  
};