import Struct "Struct";
import Binary "Binary";
import Nat64 "mo:base/Nat64";
import Nat32 "mo:base/Nat32";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";

module Record = {

  type Tag = Struct.Tag;
  type Struct = Struct.Struct;
  public type StructArray = Struct;
  public type Record = Struct;
  public type Field = Struct;

  public module Field = {

    public let tag : Tag = 0x0A000302; // Record Field Tag : Nat32

    public func valid( s : Struct ) : Bool { Struct.Tag.equal(s, tag) };

    public func unwrap( f : Field ) : Struct {
      if ( Struct.Tag.notEqual(f, tag) ) Struct.trap("Record<Field>");
      Struct.deserialize(Struct.Value.raw(f));
    }; 

    public func wrap( s : Struct ) : Field {
      var struct : Struct = Struct.empty();
      let itag : [Nat8] = Struct.Tag.toArray( s );
      let ilen : [Nat8] = Binary.BigEndian.fromNat32(Nat32.fromNat(Struct.Value.length(s)));
      let (_, value) : (Nat, Iter.Iter<Nat8>) = Struct.serialize( s );
      struct := Struct.Tag.set(struct, tag);
      struct := Struct.Value.set(struct, #iter(value));
      struct := Struct.Metadata.set(struct, Binary.BigEndian.toNat64(
        [itag[0], itag[1], itag[2], itag[3], ilen[0], ilen[1], ilen[2], ilen[3]]
      ));
      struct
    };

    public func inspect( f : Field ) : (Nat32, Nat) {
      if ( Struct.Tag.notEqual(f, tag) ) Struct.trap("Record<Field>");
      let md : [Nat8] = Struct.Metadata.toArray(f);
      (
        Binary.BigEndian.toNat32([md[0], md[1], md[2], md[3]]),
        Nat32.toNat( Binary.BigEndian.toNat32([md[4], md[5], md[6], md[7]]) )
      )
    };

  };

  public let tag : Tag = 0x0A000301; // Record Tag : Nat32

  public func valid( s : Struct ) : Bool { Struct.Tag.equal(s, tag) };

//   public func unwrap( r : Record ) : [Field] {
//     if ( Struct.Tag.notEqual(r, tag) ) Struct.trap("Record");
//     Struct.deserialize(Struct.)
//   };

  public func wrap( arr : [Struct], typetag : Nat32 ) : StructArray {

    var struct = Struct.empty();

    let entry_count = Nat32.fromNat( arr.size() );

    var index : Nat = 0;
    var bytecount : Nat32 = 0;
    let serial_vals = Array.init<(Nat, Iter.Iter<Nat8>)>(entry_count, (0, Iter.fromArray([])));
    for ( entry in arr.vals() ){
      if ( Struct.Tag.notEqual(entry, typetag) ) Struct.trap("Array<Type>");
      serial_vals[index] := Struct.serialize(entry);
      bytecount += serial_vals[index].0;
      index += 1;
    };

    index := 0;
    let metadata = Array.init<Nat8>(8,0);
    for ( byte in Binary.BigEndian.fromNat32( typetag ).vals() ){
      metadata[index] := byte;
      index += 1;
    };
    for ( byte in Binary.BigEndian.fromNat32( entry_count ) ){
      metdata[index] := byte;
      index += 1;
    };

    index := 0;
    let payload : [var Nat8] = Array.init(4 * entry_count + byte_count,  0x00);
    for ( (size, value) in arr.vals() ){
      for ( byte in Binary.BigEndian.fromNat32(Nat32.fromNat(size)).vals() ){
        payload[index] := byte;
        index += 1;
      };
      for ( byte in value ) {
        payload[index] := byte;
        index += 1;
      }
    };

    struct := Struct.Tag.set(struct, tag);
    struct := Struct.Value.set(struct, #varArray(payload));
    struct := Struct.Metadata.set(struct, Binary.BigEndian.toNat64(metadata));

    return struct

  };


};

