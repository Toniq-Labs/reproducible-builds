import Path "../asset/Path";
import RBT "../base/StableRBTree";
import Hash "mo:base/Hash";
import Time "mo:base/Time";
import List "mo:base/List";
import Nat32 "mo:base/Nat32";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Result "mo:base/Result";
import DQ "mo:base/Deque";

module {

  public type ExtMetadata = {
    #fungible : {
      name : Text;
      symbol : Text;
      decimals : Nat8;
      metadata : ?Blob;
    };
    #nonfungible : {
      metadata : ?Blob;
    };
  };
  public type TokenIndex = Nat32;
  public type AssetIndex = Nat32;
  public type Path = Path.Path;
  public type AccountIdentifier = Text;
  public type TokenIdentifier = Text;
  public type SubAccount = [Nat8];
  public type AssetList = List.List<AssetIndex>;
  public type Time = Time.Time;
  public type AccountsPayable = DQ.Deque<Disbursement>;

  public type Transaction = {
    token : TokenIdentifier;
    seller : Principal;
    price : Nat64;
    buyer : AccountIdentifier;
    time : Time;
  };

  public type Disbursement = (TokenIndex, AccountIdentifier, SubAccount, Nat64);

  public type User = {
    #address : AccountIdentifier;
    #principal : Principal;
  };

  public type MintMethod = {
    #Random;
    #Index : AssetIndex;
    #Path : Path;
  };

  public type MintRequest = {
    to : User;
    method : MintMethod;
  };

  public type Listing = {
    seller : Principal;
    price : Nat64;
    locked : ?Time;
  };

  public type ListRequest = {
    token : TokenIdentifier;
    from_subaccount : ?SubAccount;
    price : ?Nat64;
  };

  public type LockVariant = {
    #Service  : ServiceLock;
    #Market   : MarketLock;
    #User     : Principal;
    #Frozen;
    #Unlocked;
  };

  public type LockRequest = {
    token      : TokenIdentifier;
    lock       : LockVariant;
    ttl        : Nat;
  };

  public type MarketLock = {
    seller     : Principal;
    buyer      : AccountIdentifier;
    escrow     : AccountIdentifier;
    subaccount : SubAccount;
    price      : Nat64;
    var status : { #locked; #settled; #busy };
    fees       : [(AccountIdentifier, Nat64)];
  };

  public type Settlement = {
    seller : Principal;
    price : Nat64;
    subaccount : SubAccount;
    buyer : AccountIdentifier;
  };

  public type ServiceLock = {
    service : Principal;
    purpose : ?Text;
  };

  public type LockRecord = {
    token : TokenIndex;
    time  : Time.Time;
    ttl   : Nat;
  };

  public type LockHistory = List.List<LockRecord>;

  public type LockResponse = Result.Result<(),{
    #AlreadyLocked : LockVariant;
    #InvalidToken  : TokenIndex;
    #Unauthorized  : AccountIdentifier;
    #BadArgument;
  }>;

  public type TempState = {
    var operators  : [AccountIdentifier];
    var owner      : AccountIdentifier;
    var asset      : ?AssetIndex;
    var metadata   : ?Blob;
    var lock       : ?LockVariant;
    var license    : ?Text;
    var listing    : ?Listing;
  };

  public type TokenState = {
    operators  : [AccountIdentifier];
    owner      : AccountIdentifier;
    asset      : ?AssetIndex;
    metadata   : ?Blob;
    lock       : ?LockVariant;
    license    : ?Text;
    listing    : ?Listing;
  };

  public type TransferResponse = Result.Result<(),{#InvalidToken}>;
  public type TransferRequest = {
    token : TokenIndex;
    receiver : AccountIdentifier;
  };

  public module TokenIndex = {
    public func toText( x : TokenIndex ) : Text {Nat32.toText(x)};
    public func equal( x : TokenIndex, y : TokenIndex ) : Bool {Nat32.equal(x,y)};
    public func hash( x : TokenIndex ) : Hash.Hash {Int.hash(Nat32.toNat(x))};
  };

  public module AssetIndex = {
    public func toText( x : AssetIndex ) : Text {Nat32.toText(x)};
    public func equal( x : AssetIndex, y : AssetIndex ) : Bool {Nat32.equal(x,y)};
    public func hash( x : AssetIndex ) : Hash.Hash {Int.hash(Nat32.toNat(x))};
  };

  public module LockRecord = {
    public func hash( x : LockRecord ) : Hash.Hash {
      let h1 : Nat = Nat32.toNat(x.token);
      let h2 : Nat = Int.abs(x.time);
      let h3 : Nat = x.ttl;
      return Int.hash( h1 + h2 + h3 );
    };
    public func equal( x : LockRecord, y : LockRecord ) : Bool {
      let b1 : Bool = TokenIndex.equal(x.token, y.token);
      let b2 : Bool = Int.equal(x.time, y.time);
      let b3 : Bool = Nat.equal(x.ttl, y.ttl);
      return ( b1 and b2 and b3 );
    };
  };

};