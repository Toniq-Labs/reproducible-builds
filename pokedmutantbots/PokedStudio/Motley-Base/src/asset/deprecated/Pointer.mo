import Prim "mo:⛔";
import Blob "mo:base/Blob";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import Buffer "mo:base/Buffer";
import T "../Types";

module {

  public type Point = (T.Index,T.Index);
  public type Pointer = [var T.Index];
  let _MAX_BLOCKS_ : T.BlockCount = 2000;
  let _MAX_PAGES_ : T.PageCount = 500;


  public func init() : Pointer { 
    let pointer : Pointer = Prim.Array_init<T.Index>(3,0);
    pointer[0] := 1;
    pointer;
  };

  public func initPoint( p: Point ) : Pointer {
    let pointer : Pointer = Prim.Array_init<T.Index>(3,0);
    pointer[0] := p.0;
    pointer[1] := p.1;
    pointer[2] := p.1;
    pointer;
  };

  public func at_point( pointer : Pointer, point : (T.Index,T.Index) ) : Bool {
    ( pointer[0] == point.0 ) and ( pointer[2] == point.1 );
  };

  public func last_block( pointer : Pointer ) : Bool {
    return ( pointer[2] == _MAX_BLOCKS_ );
  };
  
  public func enumerate( start : T.Point, stop : T.Point, max_size : T.BlockCount ) : ([T.Point],?T.Point) {
    let pointer : Pointer = initPoint(start);
    let point_buffer = Buffer.Buffer<Point>(0);
    var next : ?T.Point = null;
    var block_count : Nat = 1;
    var counting : Bool = true;
    while counting {
      if ( block_count == max_size ){
        point_buffer.add(location(pointer));
        if ( not at_point(pointer,stop) ){
          next := ?peek_next_block(pointer);
        };
        counting := false;
      } else { 
        if ( at_point(pointer, stop) ){
          point_buffer.add(stop);
          counting := false;
        } else {
          point_buffer.add(location(pointer));
          next_block(pointer);
          block_count += 1;
      }}};
    (point_buffer.toArray(), next);
  };

  public func block_range( pointer : Pointer, size : T.BlockCount ) : (Point,Point) {
    let start : Point = location(pointer);
    var stop  : Point = (0,0);
    var block_count : Nat = 1;
    var counting : Bool = true;
    while counting {
      if ( block_count == size ){
        stop := location(pointer);
        next_block(pointer);
        counting := false;
      } else {
        next_block(pointer);
        block_count += 1;
      };
    };
    (start,stop);
  };

  public func move_to( pointer : Pointer, blocks : T.BlockCount, bound : Point ) : () {
    var block_count : Nat = 1;
    var counting : Bool = true;
    while counting {
      if ( block_count == blocks ){
        counting := false;
      } else {
        if ( at_point(pointer, bound) and (block_count < blocks) ){
          assert false;
        } else {
          next_block(pointer);
          block_count += 1;
        };
      };
    };
  };

  public func reset( pointer : Pointer, point : Point ) : () {
    pointer[0] := point.0;
    pointer[1] := point.1;
    pointer[2] := point.1;
  };

  public func start_block( pointer : Pointer ) : () {
    pointer[1] := pointer[2];
  };

  public func location( pointer : Pointer ) : T.Point {
    (pointer[0], pointer[2]);
  };

  public func snapshot( pointer : Pointer ) : (T.Index,T.Index,T.Index) {
    let page : T.Index = pointer[0];
    let start : T.Index = pointer[1];
    let end : T.Index = pointer[2];
    (page,start,end);
  };

  public func peek_next_block( pointer : Pointer ) : Point {
    assert ( pointer[0] <= _MAX_PAGES_ );
    assert ( pointer[1] <= _MAX_BLOCKS_ );
    assert ( pointer[2] <= _MAX_BLOCKS_ );
    if ( (pointer[2] + 1) > _MAX_BLOCKS_ ){
      ((pointer[0] + 1), 0 );
    } else {
      (pointer[0], (pointer[2] + 1));
    };
  };

  public func next_block( pointer : Pointer ) : () {
    assert ( pointer[0] <= _MAX_PAGES_ );
    assert ( pointer[1] <= _MAX_BLOCKS_ );
    assert ( pointer[2] <= _MAX_BLOCKS_ );
    if ( (pointer[2] + 1) > _MAX_BLOCKS_ ){
      pointer[0] += 1;
      pointer[1] := 0;
      pointer[2] := 0;
    } else {
      pointer[2] += 1;
    };
  };

};