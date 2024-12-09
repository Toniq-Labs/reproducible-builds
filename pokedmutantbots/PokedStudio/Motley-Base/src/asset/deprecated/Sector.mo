import Prim "mo:⛔";
import Blob "mo:base/Blob";
import Iter "mo:base/Iter";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import Buffer "mo:base/Buffer";
import Pointer "Pointer";
import T "../Types";

module {

  public type Pointer = Pointer.Pointer;
  public type Sector = [var Page];
  type Page = [var Block];
  type Block = [Nat8];

  public func init() : Sector {
    let zero_block : Block = [];
    let zero_page : Page = Prim.Array_init(2000,zero_block);
    Prim.Array_init(500,zero_page) : Sector;
  };

  public func verify( sector : Sector, range : T.Range ) : [T.Index] {
    let blocks : [T.Point] = Pointer.enumerate(range.0, range.1, 1000000).0;
    let buffer = Buffer.Buffer<T.Index>(0);
    var block_count : Nat = 1;
    for ( block in Iter.fromArray(blocks) ){
      if ( sector[block.0][block.1] == [] ){ buffer.add(block_count) };
      block_count += 1;
    };
    buffer.toArray();
  };

  public func write( sector : Sector, range : T.Range, blocks : [(T.Index,Blob)] ) : () {
    let pointer = Pointer.initPoint(range.0);
    for ( block in blocks.vals() ){
      Pointer.move_to(pointer, block.0, range.1);
      let point : T.Point = Pointer.location(pointer);
      sector[point.0][point.1] := Blob.toArray(block.1);
      Debug.print("Block index: " # Nat.toText(block.0) # " written to: (" # Nat.toText(point.0)#","#Nat.toText(point.1)#")");
      Pointer.reset(pointer, range.0);
    };
  };

  public func serialize( sector : Sector, blocks : [T.Point] ) : Blob {
    let bytes = Buffer.Buffer<Nat8>(0);
    for ( block in Iter.fromArray(blocks) ){
      for ( byte_index in Iter.range( 0, sector[block.0][block.1].size() - 1 )){
        bytes.add(sector[block.0][block.1][byte_index])
      };
    };
    Blob.fromArray( bytes.toArray() );
  };

};