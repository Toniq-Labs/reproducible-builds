import Index "../base/Index";
import Text "../base/Text";
import Iter "mo:base/Iter";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import AccountId "../base/AccountId";

module Owners {

  type Index = Index.Index;
  type AID = AccountId.AccountId;

  public type Owners = Text.Tree<[Index]>;

  public func init() : Owners {
    Text.Tree.init<[Index]>();
  };

  public func get_tokens( o : Owners, k : AID ) : [Index] {
    switch( Text.Tree.find<[Index]>(o, k) ){
      case ( ?tokens ) tokens;
      case null [];
    };
  };

  public func add_token( o : Owners, k : AID, v : Index ) : Owners {
    let tbuffer = Buffer.fromArray<Index>( get_tokens(o, k) );
    tbuffer.add(v);
    Text.Tree.insert<[Index]>(o, k, Buffer.toArray<Index>(tbuffer));
  };

  public func remove_token( o : Owners, k : AID, v : Index ) : Owners {
    let tokens : [Index] = get_tokens(o, k);
    assert ( tokens.size() > 0 );
    Text.Tree.insert<[Index]>(o, k, Array.filter<Index>(
      tokens, func(x) = x != v )
    );
  };

  public func purge( o : Owners ) : Owners {
    Text.Tree.fromEntries<[Index]>(
      Iter.toArray<(AID,[Index])>(
        Iter.filter<(AID,[Index])>(
          Text.Tree.entries<[Index]>( o ),
          func (x) : Bool { x.1.size() > 0 }
        )
      )
    )
  };

};