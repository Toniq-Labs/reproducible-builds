import Text "../..//base/Text";
import Time "mo:base/Time";
import Iter "mo:base/Iter";
import Blob "mo:base/Blob";
import Char "mo:base/Char";
import Nat32 "mo:base/Nat32";
import Array "mo:base/Array";
import Index "../../base/Index";
import Buffer "mo:base/Buffer";
import Ext "../../../../Motley/src/ext/Core";
import Principal "../../../../Motley-Base/src/base/Principal";

module {

  public type SharedHistory = Text.Tree<Value>;

  public type History = {
    var index : Index.Index;
    var tree : Text.Tree<Value>; 
  };

  public type Event = {
    address   : Ext.AccountIdentifier;
    claimed   : [Ext.TokenIdentifier];
    burned    : [Ext.TokenIdentifier];
    timestamp : Time.Time;
    memo      : Blob;
  };

  public type Value = {
    #index : Index.Index;
    #event : Event;
  };

  let pk_collection = "collection#";
  let pk_address = "address#";
  let sk_claimed = "#claimed#";
  let sk_burned = "#burned#";
  let sk_event = "#event#";

  public func init() : History {
    return {
      var index = 0;
      var tree = Text.Tree.init<Value>();
    };
  };

  public func share( h : History ) : Text.Tree<Value> { h.tree };

  public func add_event( h : History, e : Event ) : () {
    for ( (k,v) in key_value_pairs(h,e) ){
      h.tree := Text.Tree.insert<Value>(h.tree, k, v);
    };
  };

  public func get_event( h : History, e : Index.Index ) : ?Event {
    for ( (k,v) in Text.Tree.entries<Value>(h.tree) ){
      if ( Text.contains(k, #text(sk_event#Index.toText(e))) ){
        switch(v){
          case (#event(val)) return ?val;
          case _ return null;
    }}};
    null;
  };

  public func get_user_events( h : History, aid : Ext.AccountIdentifier ) : [Event] {
    let lower : Text = search_key_event(aid);
    let upper : Text = lower#"z";
    let results : [(Text,Value)] = Text.Tree.scan<Value>(h.tree, lower, upper);
    Array.map<(Text,Value),Event>(results, func (kv : (Text,Value)) : Event {
      switch(kv.1){
        case (#event(val)) val; // This should always happen
        case (#index(val)){{
            address="Corrupted"; // This should never happen
            claimed=[];
            burned=[]; 
            timestamp=Time.now();
            memo = Text.encodeUtf8(kv.0); // For troubleshooting
        }};
      };
    });
  };

  public func get_claimed( h : History, p : Principal ) : [(Ext.TokenIndex, Index.Index)] {
    let lower : Text = search_key_claimed(p);
    let upper : Text = lower # "z";
    let results : [(Text,Value)] = Text.Tree.scan<Value>(h.tree, lower, upper);
    Array.map<(Text,Value),(Ext.TokenIndex,Index.Index)>(results,
      func (kv : (Text,Value)) : (Ext.TokenIndex,Index.Index) {
        switch( Text.stripStart(kv.0, #text(lower)) ){
          case (?text_index){
            let tindex : Ext.TokenIndex = textToNat32(text_index);
            switch(kv.1){
              case (#index(val)) (tindex, val); // This should always happen
              case (#event(val)) (tindex, 999999); // This should never happen
            };
          };
          case null (999999, 999999); // This should never happen
        };
      }
    );
  };

  public func get_burned( h : History, p : Principal ) : [(Ext.TokenIndex, Index.Index)] {
    let lower : Text = search_key_burned(p);
    let upper : Text = lower # "9999999";
    let results : [(Text,Value)] = Text.Tree.scan<Value>(h.tree, lower, upper);
    Array.map<(Text,Value),(Ext.TokenIndex,Index.Index)>(results,
      func (kv : (Text,Value)) : (Ext.TokenIndex,Index.Index) {
        switch( Text.stripStart(kv.0, #text(lower)) ){
          case (?text_index){
            let tindex : Ext.TokenIndex = textToNat32(text_index);
            switch(kv.1){
              case (#index(val)) (tindex, val);
              case (#event(val)) (tindex, 999999);
            };
          };
          case null (999999, 999999);
        };
      }
    );
  };

  func search_key_event( aid : Ext.AccountIdentifier ) : Text {
    pk_address # aid # sk_event;
  };

  func search_key_claimed( p : Principal ) : Text {
    pk_collection # Principal.toText(p) # sk_claimed;
  };

  func search_key_burned( p : Principal ) : Text {
    pk_collection # Principal.toText(p) # sk_burned;
  };

  func collection_key( tokenid : Ext.TokenIdentifier, sortKey : Text ) : Text {
    let tobj = Ext.TokenIdentifier.decode(tokenid);
    let ckey = Principal.toText(Principal.fromBlob(Blob.fromArray(tobj.canister)));
    pk_collection#ckey#sortKey#Nat32.toText(tobj.index);
  };

  func key_value_pairs( h : History, e : Event) : Iter.Iter<(Text,Value)> {
    let pairs = Buffer.Buffer<(Text,Value)>(0);
    pairs.add((pk_address#e.address#sk_event#Index.toText(h.index), #event(e)));
    for ( tokenid in e.claimed.vals() ){
      pairs.add((collection_key(tokenid, sk_claimed), #index(h.index)));
    };
    for ( tokenid in e.burned.vals() ){
      pairs.add((collection_key(tokenid, sk_burned), #index(h.index)));
    };
    h.index += 1;
    pairs.vals();
  };

  /**
  Credit to Dfinity forum user Goose for this handy function. Thank you!
  source : https://forum.dfinity.org/t/motoko-convert-text-123-to-nat-or-int-123/7033/2?u=lightninglad91
  **/
  func textToNat32( txt : Text) : Nat32 {
    assert(txt.size() > 0);
    let chars = txt.chars();
    var num : Nat = 0;
    for (v in chars){
      let charToNum = Nat32.toNat(Char.toNat32(v)-48);
      assert(charToNum >= 0 and charToNum <= 9);
      num := num * 10 +  charToNum;          
    };
    Nat32.fromNat(num);
  };

};