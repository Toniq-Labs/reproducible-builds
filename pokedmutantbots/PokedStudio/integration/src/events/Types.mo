import Text "../../../../Motley-Base/src/base/Text";
import Index "../../../../Motley-Base/src/base/Index";
import Ext "../../../../Motley/src/ext/Core";
import Result "mo:base/Result";

module {

  public type StableCredits = (Nat,Nat,Nat,Nat,Nat);
  public type StableWhitelist = [StableWhitelistEntry];
  public type StableWhitelistEntry = (Ext.AccountIdentifier,StableCredits);
  public type WhitelistEntry = (Ext.AccountIdentifier, [var Nat]);
  public type Inventory = [var [Ext.TokenIdentifier]];
  public type BurnReqs = [?Nat];
  public type Whitelist = Text.Tree<Credits>;
  public type Candidates = Text.Tree<TokenState>;
  public type Credits = [var Nat];
  public type Return<T> = Result.Result<T,Error>;
  public type Categories = [Text];

  public type ClaimRequest = {
    #drop : Ext.SubAccount;
    #burn : Index.Index;
  };

  type SnapshotFunc = shared () -> async Snapshot;
  public type SnapshotSvc = actor { snapshot : SnapshotFunc };

  public type Snapshot = {
    registry   : Principal;
    candidates : [Ext.TokenIndex];
    whitelist  : [(Ext.AccountIdentifier,(Nat,Nat,Nat,Nat,Nat))];
    owners : [(Ext.AccountIdentifier,[Ext.TokenIndex])];
  };

  public type Configuration = {
    event         : ServiceState;
    registry      : Principal;
    snapshot      : ?Principal;
    burn_registry : ?Principal;
    inventory     : [(Category,[Ext.TokenIndex])];
    requirements  : (?Nat,?Nat,?Nat,?Nat,?Nat);
    recipients    : [(Ext.AccountIdentifier,(Nat,Nat,Nat,Nat,Nat))];
    mapping       : [(Ext.TokenIndex,Ext.TokenIndex)];    
  };

  public type Request = {
    owner      : Principal;
    subaccount : ?Ext.SubAccount;
    category   : Category;
    candidates : [Ext.TokenIdentifier];
    var status : RequestStatus;
  };

  public type SharedRequest = {
    owner      : Principal;
    subaccount : ?Ext.SubAccount;
    category   : Category;
    candidates : [Ext.TokenIdentifier];
    status     : RequestStatus;
  };

  public type BurnRequest = {
    category   : Category;
    subaccount : ?Ext.SubAccount;
    tokens     : [Ext.TokenIdentifier];
  };

  public type BurnInstruction = {
    reference : Index.Index;
    request   : Ext.BulkTransferRequest;
    transfer  : shared (Ext.BulkTransferRequest) -> async Ext.TransferResponse;
  };

  public type Category = {
    #cat1;
    #cat2;
    #cat3;
    #cat4;
    #cat5;
  };

  // public type Categories = {
  //   #cat0 : Text;
  //   #cat1 : Text;
  //   #cat2 : Text;
  //   #cat3 : Text;
  //   #cat4 : Text;
  // };

  public type TokenState = {
    #unlocked;
    #locked;
    #burned;
  };

  public type ServiceState = {
    #burn;
    #drop;
    #swap;
    #inactive;
  };

  public type RequestStatus = {
    #submitted;
    #settled;
    #claimed;
    #cancelled;
    #refunded;
    #busy;
  };

  public type Error = {
    #ActiveRequest : SharedRequest;
    #AlreadyBurned : Ext.TokenIdentifier;
    #TokenIsLocked : Ext.TokenIdentifier;
    #InvalidToken : Ext.TokenIdentifier;
    #Unauthorized : Ext.AccountIdentifier;
    #NotWhitelisted : Ext.AccountIdentifier;
    #InsufficientTokens : Nat;
    #BadCategory : Category;
    #InsufficientCredits;
    #ConfigError : Text;
    #ConditionsNotMet;
    #ProcessingRequest;
    #UnknownState;
    #AlreadyClaimed;
    #DoesNotExist;
    #AlreadySettled;
    #RequestCancelled;
    #AlreadyRefunded;
    #RefundFailed;
    #TransferFailed;
    #NothingToRefund;
    #BeingProcessed;
    #Other : Text;
  };

};