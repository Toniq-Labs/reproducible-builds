/// Hash values

import Prim "mo:⛔";
import Text "Text";
import Nat "mo:base/Nat";
import Blob "mo:base/Blob";
import Iter "mo:base/Iter";
import Binary "../encoding/Binary";
import SHA256 "mo:crypto/SHA/SHA256";

module {

  public type Hash = Nat32;

  public func hash( n : Nat ) : Nat32 {
    let ba : [Nat8] = SHA256.sum(Blob.toArray(Text.encodeUtf8(Nat.toText(n))));
    Binary.BigEndian.toNat32([ba[0],ba[1],ba[30],ba[31]]);
    // Binary.BigEndian.toNat32(ba);
  };

  public func equal( x : Hash, y : Hash ) : Bool {
    x == y;
  };

};