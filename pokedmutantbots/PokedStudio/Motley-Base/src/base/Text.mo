import Prim "mo:⛔";
import SB "StableBuffer";
import RBT "StableRBTree";
import Char "mo:base/Char";
import Iter "mo:base/Iter";
import Stack "mo:base/Stack";
import Text "mo:base/Text";
import Option "mo:base/Option";
import TrieSet "mo:base/TrieSet";

module {

  type Hash = Nat32;

  public type Text = Prim.Types.Text;

  public type Pattern = Text.Pattern;
  public type Tree<T> = RBT.Tree<Text,T>;
  public type Buffer = SB.StableBuffer<Text>;
  public type Set = TrieSet.Set<Text>;
  public type LargeSet = RBT.Tree<Text,()>;

  public let fromChar = Text.fromChar;
  public let toIter = Text.toIter;
  public let fromIter = Text.fromIter;
  public let size = Text.size;
  public let hash = Text.hash;
  public let concat = Text.concat;
  public let equal = Text.equal;
  public let notEqual = Text.notEqual;
  public let less = Text.less;
  public let greater = Text.greater;
  public let lessOrEqual = Text.lessOrEqual;
  public let greaterOrEqual = Text.greaterOrEqual;
  public let compare = Text.compare;
  public let join = Text.join;
  public let map = Text.map;
  public let translate = Text.translate;
  public let split = Text.split;
  public let tokens = Text.tokens;
  public let contains = Text.contains;
  public let startsWith = Text.startsWith;
  public let endsWith = Text.endsWith;
  public let replace = Text.replace;
  public let stripStart = Text.stripStart;
  public let stripEnd = Text.stripEnd;
  public let trimStart = Text.trimStart;
  public let trimEnd = Text.trimEnd;
  public let trim = Text.trim;
  public let compareWith = Text.compareWith;
  public let encodeUtf8 = Text.encodeUtf8;
  public let decodeUtf8 = Text.decodeUtf8;

  public module Set = {

    public func init() : Set { TrieSet.empty<Text>() };

    public func insert( s : Set, p : Text ) : Set { 
      TrieSet.put<Text>(s, p, hash(p), Text.equal);
    };
    public func delete(s : Set, p : Text) : Set {
      TrieSet.delete<Text>( s, p, hash(p), Text.equal);
    };
    public func equal(s1 : Set, s2 : Set) : Bool {
      TrieSet.equal<Text>(s1, s2, Text.equal);
    };
    public func size(s : Set) : Nat {
      TrieSet.size<Text>(s);
    };
    public func match(s : Set, p : Text) : Bool {
      TrieSet.mem<Text>(s, p, hash(p), Text.equal);
    };
    public func union(s1 : Set, s2 : Set) : Set {
      TrieSet.union<Text>(s1, s2, Text.equal);
    };
    public func diff(s1 : Set, s2 : Set) : Set {
      TrieSet.diff<Text>(s1, s2, Text.equal);
    };
    public func intersect(s1 : Set, s2 : Set) : Set {
      TrieSet.intersect<Text>(s1, s2, Text.equal);
    };
    public func fromArray(arr : [Text]) : Set {
      TrieSet.fromArray<Text>(arr, hash, Text.equal);
    };
    public func toArray(s : Set) : [Text] {
      TrieSet.toArray<Text>(s);
    };

  };

  public module Tree = {

    public func init<T>() : Tree<T> { RBT.init<Text,T>() };

    public func scan<T>( tree : Tree<T>, lower : Text, upper : Text ) : [(Text,T)] {
      RBT.scanLimit<Text,T>(tree, Text.compare, lower, upper, #fwd, 10000).results;
    };
    public func keys<T>( tree : Tree<T> ) : Iter.Iter<Text> {
      Iter.map<(Text,T),Text>(entries(tree), func (kv : (Text, T)) : Text { kv.0 });
    };
    public func vals<T>( tree : Tree<T> ) : Iter.Iter<T> {
      Iter.map<(Text,T),T>(entries(tree), func (kv : (Text, T)) : T { kv.1 });
    };
    public func fromEntries<T>( arr : [(Text,T)] ) : Tree<T> {
      var tree : Tree<T> = init<T>();
      for ( e in arr.vals() ){
        tree := insert<T>(tree, e.0, e.1);
      };
      tree;
    };
    public func entries<T>( tree : Tree<T> ) : Iter.Iter<(Text, T)> {
      RBT.entries<Text,T>(tree);
    };
    public func insert<T>( tree : Tree<T>, key : Text, val : T ) : Tree<T> {
      RBT.put<Text,T>(tree, Text.compare, key, val);
    };
    public func delete<T>( tree : Tree<T>, key : Text ) : Tree<T> {
      RBT.delete<Text, T>(tree, Text.compare, key );
    };
    public func find<T>( tree : Tree<T>, key : Text) : ?T {
      RBT.get<Text,T>(tree, Text.compare, key);
    };
    public func size<T>( tree : Tree<T>) : Nat {
      RBT.size<Text,T>(tree);
    };

  };

  // This is probably not the best way to implement this. Should come up with something else
  // when I have more time.
  public module LargSet = {

    public func init() : LargeSet { RBT.init<Text,()>() };

    public func insert( ls : LargeSet, val : Text ) : LargeSet { 
      Tree.insert<()>(ls, val, ());
    };
    public func delete( ls : LargeSet, val : Text) : LargeSet {
      Tree.delete<()>(ls, val);
    };
    public func entries( ls : LargeSet ) : Iter.Iter<Text> {
      Iter.map<(Text,()),Text>(Tree.entries<()>(ls), func (kv : (Text,())) : Text { kv.0 });
    };
    public func size(ls : LargeSet) : Nat {
      Tree.size<()>(ls);
    };
    public func match( ls : LargeSet, val : Text) : Bool {
      Option.isSome(Tree.find<()>(ls, val));
    };
    public func fromArray(arr : [Text]) : LargeSet {
      var ls : LargeSet = init();
      for ( val in arr.vals() ){
        ls := Tree.insert<()>(ls, val, ());
      };
      ls;
    };
    public func toArray(ls : LargeSet) : [Text] {
      Iter.toArray(Tree.keys<()>(ls));
    };

  };

  public module Buffer = {

    public func initPresized(initCapacity: Nat): Buffer {
      SB.initPresized<Text>(initCapacity);
    };
    public func init(): Buffer {
      SB.init<Text>();
    };
    public func add(buffer: Buffer, elem: Text): () {
      SB.add<Text>(buffer, elem);
    };
    public func removeLast(buffer: Buffer) : ?Text {
      SB.removeLast<Text>(buffer);
    };
    public func append( b1: Buffer, b2 : Buffer): () {
      SB.append<Text>(b1,b2);
    };
    public func size(buffer: Buffer) : Nat {
      buffer.count;
    };
    public func clear(buffer: Buffer): () {
      buffer.count := 0;
    };
    public func clone(buffer: Buffer) : Buffer {
      SB.clone<Text>(buffer);
    };
    public func vals(buffer: Buffer) : Iter.Iter<Text> {
      SB.vals<Text>(buffer);
    };
    public func fromArray( arr: [Text]): Buffer {
      SB.fromArray<Text>(arr);
    };
    public func toArray(buffer: Buffer) : [Text] {
      SB.toArray<Text>(buffer);
    };
    public func toVarArray(buffer: Buffer) : [var Text] {
      SB.toVarArray<Text>(buffer);
    };
    public func get(buffer: Buffer, i : Nat) : Text {
      SB.get<Text>(buffer, i);
    };
    public func getOpt(buffer: Buffer, i : Nat) : ?Text {
      SB.getOpt<Text>(buffer, i);
    };
    public func put(buffer: Buffer, i : Nat, elem : Text) {
      SB.put<Text>(buffer, i, elem);
    };    

  };

};