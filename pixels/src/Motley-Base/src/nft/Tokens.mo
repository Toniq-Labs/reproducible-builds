import Assets "../asset/Types";
import Array "mo:base/Array";
import Http "../asset/Http";
import Index "../base/Index";
import Text "../base/Text";
import Path "../asset/Path";
import Buffer "mo:base/Buffer";
import Iter "mo:base/Iter";
import Blob "mo:base/Blob";
import Debug "mo:base/Debug";
import AccountId "../base/AccountId";

module Tokens {

  public module Metadata = {

    public type Metadata = Text.Tree<Value>;

    public type Key = Text;
  
    public type Value = {
      #stream : Stream;
      #blob : Blob;
      #url : Text;
      #none;
    };

    public type Stream = {
      name : Text;
      ftype : Text;
      pointer : {
        callback : Http.StreamingCallback;
        token    : Http.StreamingToken;
      }
    };

    public func init() : Metadata { Text.Tree.init<Value>() };
    
    public func find( md : Metadata, k : Key ) : ?Value {
      Text.Tree.find<Value>(md, k);
    };
    public func insert( md : Metadata, k : Key, v : Value ) : Metadata {
      Text.Tree.insert<Value>(md, k, v);
    };
    public func toArray( md : Metadata ) : [(Key, Value)] {
      Iter.toArray<(Key,Value)>(Text.Tree.entries<Value>(md));
    };
    public func fromArray( arr : [(Key,Value)] ) : Metadata {
      Text.Tree.fromEntries<Value>(arr);
    };
    public func entries( md : Metadata ) : Iter.Iter<(Key,Value)> {
      Text.Tree.entries<Value>(md);
    };

  };

  type AID = AccountId.AccountId;
  type Path = Path.Path;
  type Lock = { #locked; #unlocked };
  type Metadata = Metadata.Metadata;
  type Value = Metadata.Value;
  type Key = Metadata.Key;
  type Index = Index.Index;

  public type Tokens = {
    var size : Nat;
    var burned : Nat;
    var elems : [var Token];
  };

  public type Token = {
    var owner : AID;
    var path : Path;
    var lock : Lock;
    var burned : Bool;
    var metadata : Metadata;
  };

  public func init( initial_supply : Nat ) : Tokens {
    return {
      var size = 0;
      var burned = 0;
      var elems = if ( initial_supply == 0 ) [var]
        else Array.init(initial_supply, placeholder() 
      )
    }
  };

  public func placeholder() : Token {
    return {
      var owner = "";
      var path = "";
      var lock = #locked;
      var burned = true;
      var metadata = Metadata.init(); 
    }
  };

  public func supply( t : Tokens ) : Nat { t.size - t.burned };

  public func is_valid( t : Tokens, i : Index ) : Bool { i < t.size };

  /// Functions for working with token owner data
  public func map_owners( t : Tokens ) : [(Index, AID)] {
    var i : Nat = 0;
    var ret = Buffer.Buffer<(Index,AID)>(t.size);
    label l loop {
      if ( i >= t.size ) break l
      else {
        let token = t.elems[i];
        if ( not token.burned ) ret.add((i, token.owner));
        i += 1;
      }
    };
    Buffer.toArray( ret ); 
  };

  public func get_owner( t : Tokens, i : Index ) : AID {
    assert ( i < t.size );
    t.elems[i].owner;
  };

  public func set_owner( t : Tokens, i : Index, a : AID ) : () {
    assert ( i < t.size );
    t.elems[i].owner := a;
  };

  public func is_owner( t : Tokens, i : Index, a : AID ) : Bool {
    assert ( i < t.size );
    Text.equal(t.elems[i].owner, a);
  };

  /// Functions for working with token paths
  public func map_paths( t : Tokens ) : [(Index, Path)] {
    var i : Nat = 0;
    var ret = Buffer.Buffer<(Index,Path)>(t.size);
    label l loop {
      if ( i > t.size ) break l
      else {
        let token = t.elems[i];
        if ( not token.burned ) ret.add((i, token.path));
        i += 1;
      }
    };
    Buffer.toArray( ret ); 
  };

  public func get_path( t : Tokens, i : Index ) : Path {
    assert ( i < t.size );
    t.elems[i].path;
  };

  public func set_path( t : Tokens, i : Index, p : Path ) : () {
    assert ( i < t.size );
    t.elems[i].path := p;
  };

  /// Functions for working with token locks
  public func map_locks( t : Tokens ) : [(Index, Lock)] {
    var i : Nat = 0;
    var ret = Buffer.Buffer<(Index,Lock)>(t.size);
    label l loop {
      if ( i > t.size ) break l
      else {
        let token = t.elems[i];
        if ( not token.burned ) ret.add((i, token.lock));
        i += 1;
      }
    };
    Buffer.toArray( ret ); 
  };

  public func lock( t : Tokens, i : Index ) : () {
    assert ( i < t.size );
    t.elems[i].lock := #locked;
  };

  public func unlock( t : Tokens, i : Index ) : () {
    assert ( i < t.size );
    t.elems[i].lock := #unlocked;
  };

  public func is_unlocked( t : Tokens, i : Index ) : Bool {
    not is_locked(t, i);
  };

  public func is_locked( t : Tokens, i : Index ) : Bool {
    assert ( i < t.size );
    switch( t.elems[i].lock ){
      case ( #unlocked ) false;
      case ( #locked ) true;
    };
  };

  /// Functions for retrieving and inserting token metadata entries
  public func get_metadata( t : Tokens, i : Index ) : [(Index, [(Key,Value)])] {
    var i : Nat = 0;
    var ret = Buffer.Buffer<(Index,[(Key,Value)])>( supply( t ) );
    label l loop {
      if ( i > t.size ) break l
      else {
        let token = t.elems[i];
        if ( not token.burned ) ret.add((i, Metadata.toArray(token.metadata)));
        i += 1
      }
    };
    Buffer.toArray( ret ); 
  };

  public func query_metadata( t : Tokens, i : Index, k : Key ) : Value {
    assert ( i < t.size );
    switch( Metadata.find(t.elems[i].metadata, k) ){
      case ( ?v ) v;
      case null #none;
    }
  };

  public func insert_metadata( t : Tokens, i : Index, k : Key, v : Value ) : () {
    assert ( i < t.size );
    let metadata : Metadata = t.elems[i].metadata;
    t.elems[i].metadata := Metadata.insert(metadata, k, v);
  };

  public func mint_token( t : Tokens, a : AID, p : Path, m : Metadata ): Index {
    if ( t.size == t.elems.size()) {
      var elems2 : [var Token] = [var];
      if ( t.size == 0 ) elems2 := Array.init<Token>(2, placeholder())
      else {
        let size = 2 * t.elems.size();
        elems2 := Array.init<Token>(size, placeholder())
      };
      var i = 0;
      label l loop {
        if (i >= t.size) break l;
        elems2[i] := t.elems[i];
        i += 1;
      };
      t.elems := elems2;
    };
    t.elems[t.size] := {
      var owner = a;
      var path = p;
      var lock = #unlocked;
      var burned = false;
      var metadata = m;
    };
    let index : Index = t.size;
    t.size += 1;
    index;
  };

};