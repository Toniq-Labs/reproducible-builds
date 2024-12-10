import AID "./motoko/util/AccountIdentifier";
import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Canistergeek "mo:canistergeek/canistergeek";
import Cap "mo:cap/Cap";
import Cycles "mo:base/ExperimentalCycles";
import Encoding "mo:encoding/Binary";
import ExtAllowance "./motoko/ext/Allowance";
import ExtCommon "./motoko/ext/Common";
import ExtCore "./motoko/ext/Core";
import ExtNonFungible "./motoko/ext/NonFungible";
import HashMap "mo:base/HashMap";
import Int64 "mo:base/Int64";
import Iter "mo:base/Iter";
import List "mo:base/List";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Nat8 "mo:base/Nat8";
import Option "mo:base/Option";
import Prelude "mo:base/Prelude";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";
import TrieMap "mo:base/TrieMap";

module {
  // Types
  public type Time = Time.Time;
  public type AccountIdentifier = ExtCore.AccountIdentifier;
  public type SubAccount = ExtCore.SubAccount;
  public type User = ExtCore.User;
  public type Balance = ExtCore.Balance;
  public type TokenIdentifier = ExtCore.TokenIdentifier;
  public type TokenIndex = ExtCore.TokenIndex;
  public type Extension = ExtCore.Extension;
  public type CommonError = ExtCore.CommonError;
  public type BalanceRequest = ExtCore.BalanceRequest;
  public type BalanceResponse = ExtCore.BalanceResponse;
  public type TransferRequest = ExtCore.TransferRequest;
  public type TransferResponse = ExtCore.TransferResponse;
  public type AllowanceRequest = ExtAllowance.AllowanceRequest;
  public type ApproveRequest = ExtAllowance.ApproveRequest;
  public type Metadata = ExtCommon.Metadata;
  public type NotifyService = ExtCore.NotifyService;

  public type MintingRequest = {
    to : AccountIdentifier;
    asset : Nat32;
  };

  private type CyclesReport = {
    balance : Nat;
    transfer : shared () -> async ();
  };

  //Marketplace
  public type Transaction = {
    token : TokenIdentifier;
    seller : Principal;
    price : Nat64;
    buyer : AccountIdentifier;
    time : Time;
  };
  public type Settlement = {
    seller : Principal;
    price : Nat64;
    subaccount : SubAccount;
    buyer : AccountIdentifier;
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
  public type AccountBalanceArgs = { account : AccountIdentifier };
  public type ICPTs = { e8s : Nat64 };
  public type SendArgs = {
    memo : Nat64;
    amount : ICPTs;
    fee : ICPTs;
    from_subaccount : ?SubAccount;
    to : AccountIdentifier;
    created_at_time : ?Time;
  };
  public type File = {
    ctype : Text; //"image/jpeg"
    data : [Blob];
  };
  public type Asset = {
    name : Text;
    thumbnail : ?File;
    payload : File;
  };
  public type UpdateRequest = {
    assetID : Nat;
    payload : File;
  };

  public let LEDGER_CANISTER = actor "ryjl3-tyaaa-aaaaa-aaaba-cai" : actor {
    send_dfx : shared SendArgs -> async Nat64;
    account_balance_dfx : shared query AccountBalanceArgs -> async ICPTs;
  };

  //Cap
  public type CapDetailValue = {
    #I64 : Int64;
    #U64 : Nat64;
    #Vec : [CapDetailValue];
    #Slice : [Nat8];
    #Text : Text;
    #True;
    #False;
    #Float : Float;
    #Principal : Principal;
  };
  public type CapEvent = {
    time : Nat64;
    operation : Text;
    details : [(Text, CapDetailValue)];
    caller : Principal;
  };
  public type CapIndefiniteEvent = {
    operation : Text;
    details : [(Text, CapDetailValue)];
    caller : Principal;
  };

};
