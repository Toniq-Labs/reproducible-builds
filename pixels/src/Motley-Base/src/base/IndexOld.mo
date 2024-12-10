import Prim "mo:⛔";
import Hash "HashOld";
import Nat "mo:base/Nat";
import SB "StableBuffer";
import RBT "StableRBTree";
import Iter "mo:base/Iter";
import TrieSet "mo:base/TrieSet";

module Index {

  public type Index = Prim.Types.Nat;
  public type Tree<T> = RBT.Tree<Index,T>;
  public type Buffer = SB.StableBuffer<Index>;
  public type Set = TrieSet.Set<Index>;

  public let hash = Hash.hash;
  public let equal = Nat.equal;
  public let compare = Nat.compare;
  public let toText = Nat.toText;

  public module Set = {

    public func init() : Set { TrieSet.empty<Index>() };

    public func insert( s : Set, p : Index ) : Set { 
      TrieSet.put<Index>(s, p, hash(p), Index.equal);
    };
    public func delete(s : Set, p : Index) : Set {
      TrieSet.delete<Index>( s, p, hash(p), Index.equal);
    };
    public func equal(s1 : Set, s2 : Set) : Bool {
      TrieSet.equal<Index>(s1, s2, Index.equal);
    };
    public func size(s : Set) : Nat {
      TrieSet.size<Index>(s);
    };
    public func match(s : Set, p : Index) : Bool {
      TrieSet.mem<Index>(s, p, hash(p), Index.equal);
    };
    public func union(s1 : Set, s2 : Set) : Set {
      TrieSet.union<Index>(s1, s2, Index.equal);
    };
    public func diff(s1 : Set, s2 : Set) : Set {
      TrieSet.diff<Index>(s1, s2, Index.equal);
    };
    public func intersect(s1 : Set, s2 : Set) : Set {
      TrieSet.intersect<Index>(s1, s2, Index.equal);
    };
    public func fromArray(arr : [Index]) : Set {
      TrieSet.fromArray<Index>(arr, hash, Index.equal);
    };
    public func toArray(s : Set) : [Index] {
      TrieSet.toArray<Index>(s);
    };

  };

  public module Tree = {

    public func init<T>() : Tree<T> { RBT.init<Index,T>() };

    public func keys<T>( tree : Tree<T> ) : Iter.Iter<Index> {
      Iter.map<(Index,T),Index>(entries(tree), func (kv : (Index, T)) : Index { kv.0 });
    };
    public func vals<T>( tree : Tree<T> ) : Iter.Iter<T> {
      Iter.map<(Index,T),T>(entries(tree), func (kv : (Index, T)) : T { kv.1 });
    };
    public func entries<T>( tree : Tree<T> ) : Iter.Iter<(Index, T)> {
      RBT.entries<Index,T>(tree);
    };
    public func insert<T>( tree : Tree<T>, key : Index, val : T ) : Tree<T> {
      RBT.put<Index,T>(tree, Index.compare, key, val);
    };
    public func delete<T>( tree : Tree<T>, key : Index ) : Tree<T> {
      RBT.delete<Index, T>(tree, Index.compare, key );
    };
    public func find<T>( tree : Tree<T>, key : Index) : ?T {
      RBT.get<Index,T>(tree, Index.compare, key);
    };

  };

  public module Buffer = {

    public func initPresized(initCapacity: Nat): Buffer {
      SB.initPresized<Index>(initCapacity);
    };
    public func init(): Buffer {
      SB.init<Index>();
    };
    public func add(buffer: Buffer, elem: Index): () {
      SB.add<Index>(buffer, elem);
    };
    public func removeLast(buffer: Buffer) : ?Index {
      SB.removeLast<Index>(buffer);
    };
    public func append( b1: Buffer, b2 : Buffer): () {
      SB.append<Index>(b1,b2);
    };
    public func size(buffer: Buffer) : Nat {
      buffer.count;
    };
    public func clear(buffer: Buffer): () {
      buffer.count := 0;
    };
    public func clone(buffer: Buffer) : Buffer {
      SB.clone<Index>(buffer);
    };
    public func vals(buffer: Buffer) : Iter.Iter<Index> {
      SB.vals<Index>(buffer);
    };
    public func fromArray( arr: [Index]): Buffer {
      SB.fromArray<Index>(arr);
    };
    public func toArray(buffer: Buffer) : [Index] {
      SB.toArray<Index>(buffer);
    };
    public func toVarArray(buffer: Buffer) : [var Index] {
      SB.toVarArray<Index>(buffer);
    };
    public func get(buffer: Buffer, i : Nat) : Index {
      SB.get<Index>(buffer, i);
    };
    public func getOpt(buffer: Buffer, i : Nat) : ?Index {
      SB.getOpt<Index>(buffer, i);
    };
    public func put(buffer: Buffer, i : Nat, elem : Index) {
      SB.put<Index>(buffer, i, elem);
    };   

  };

};