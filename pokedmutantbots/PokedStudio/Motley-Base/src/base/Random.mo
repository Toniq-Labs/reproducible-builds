import Random "mo:base/Random";
import Deque "mo:base/Deque";
import Iter "mo:base/Iter";
import Buffer "mo:base/Buffer";
import Option "mo:base/Option";
import Blob "mo:base/Blob";

module {

  public let Finite = Random.Finite;
  public type Finite = Random.Finite;
  public type Cache = Deque.Deque<Blob>;
  public type RNG = { spin : (Nat) -> ?Nat };
  
  public type Entropy = {
    var max   : Nat;
    var size  : Nat;
    var queue : Nat;
    var cache : Cache;
  };

  public let blob = Random.blob;
  public let byteFrom = Random.byteFrom;
  public let coinFrom = Random.coinFrom;
  public let rangeFrom = Random.rangeFrom;
  public let binomialFrom = Random.binomialFrom;

  /*
    Thanks to Ryan Vandersmith who provided this function in the motoko examples repository
    source : https://github.com/dfinity/examples/blob/master/motoko/random_maze/src/random_maze/Main.mo
  */
  func bit(b : Bool) : Nat {
    if (b) 1 else 0;
  };
  public class NumberGenerator( b : Blob ) {
    let f : Finite = Finite(b);
    func coin() : ?Bool {
      switch( f.range(1) ){
        case null null;
        case ( ?n ){
          if ( n == 1 ) ?true
          else ?false
        }
      }
    };
    public func spin( max : Nat ) : ?Nat {
      assert max > 0;
      do ? {
        if (max == 1) return ? 0;
        var k = bit(coin()!);
        var n = max / 2;
        while (n > 1) {
          k := k * 2 + bit(f.coin()!);
          n := n / 2;
        };
        if (k < max)
          return ? k
        else spin(max) !; // retry
      };
    };
  };

  public module Entropy = {

    public type Entropy = {
      var max   : Nat;
      var size  : Nat;
      var queue : Nat;
      var cache : Cache;
    };

    public func init( _max : Nat ) : Entropy {
      return {
        var max = _max;
        var size = 0;
        var queue = 0;
        var cache = Deque.empty<Blob>();
      };
    };

    public func rng( e : Entropy ) : RNG { NumberGenerator( get(e) ) };

    public func isAvailable( e : Entropy ) : Bool { e.size > 0 };
    
    public func isEmpty( e : Entropy ) : Bool { e.size == 0 };
    
    public func isFull( e : Entropy ) : Bool { e.size == e.max };
    
    public func size( e : Entropy ) : Nat { e.size };

    public func queue( e : Entropy ) : Nat { e.queue };

    public func fill( e : Entropy ) : async () {
      if ( e.size + e.queue < e.max ){
        let delta : Nat = e.max - e.size - e.queue;
        e.queue += delta;
        for ( i in Iter.range(1, delta) ){
          let b : Blob = await blob();
          push(e,b);
          e.queue -= 1;
        };
      };
    };

    public func push( e : Entropy, b : Blob ) : () {
      if ( e.size + e.queue <= e.max ) {
        e.cache := Deque.pushBack<Blob>(e.cache, b);
        e.size += 1;
      };
    };

    public func pop( e : Entropy ) : ?Blob {
      switch( Deque.popFront<Blob>(e.cache) ){
        case null null;
        case ( ?(b, dq) ) {
          e.cache := dq;
          e.size -= 1;
          ?b;
        };
      };
    };

    public func get( e : Entropy ) : Blob {
      assert e.size > 0;
      let (b, dq) = Option.get<(Blob,Cache)>(
        Deque.popFront<Blob>(e.cache), (Blob.fromArray([]), e.cache));
      e.cache := dq;
      e.size -= 1;
      b;
    };

    public func flip_a_coin( e : Entropy ) : Bool {
      Random.coinFrom(get(e));
    };

    public func flip_many_coins( e : Entropy, n : Nat ) : Iter.Iter<Bool> {
      var f : Finite = Finite(get(e));
      let coins = Buffer.Buffer<Bool>(0);
      var count : Nat = 0;
      while ( count < n ) {
        switch( f.coin() ){
          case null f := Finite(get(e));
          case ( ?toss ) {
            coins.add(toss);
            count += 1;
          };
        };
      };
      coins.vals();
    };

  };

};