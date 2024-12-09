import type { Principal } from '@dfinity/principal';
import type { ActorMethod } from '@dfinity/agent';

export type AccountId = string;
export type AccountId__1 = string;
export type AccountIdentifier = string;
export type Allowance = bigint;
export interface Attributes { 'firesale' : boolean }
export type Balance = bigint;
export interface BalanceRequest { 'token' : TokenIdentifier, 'user' : User }
export type Balance__1 = bigint;
export type Bytes = bigint;
export type CommonError = { 'InvalidToken' : TokenIdentifier } |
  { 'Other' : string };
export type DState = { 'Hidden' : null } |
  { 'Valid' : null };
export type Dentry = [Index__2, Index__2, Handle, DState];
export interface Directory {
  'contents' : Array<Dentry>,
  'owner' : Principal,
  'mode' : Mode,
  'name' : Handle,
  'group' : Array<Principal>,
  'inode' : Index__2,
  'parent' : Index__2,
}
export type Disbursement = [Index__1, AccountId, Uint8Array | number[], bigint];
export type Error = { 'LockExpired' : null } |
  { 'Busy' : null } |
  { 'DelistingRequested' : null } |
  { 'NotLocked' : null } |
  { 'FeeTooHigh' : bigint } |
  { 'UnauthorizedMarket' : AccountId } |
  { 'Locked' : null } |
  { 'Fatal' : string } |
  { 'FeeTooSmall' : bigint } |
  { 'ConfigError' : string } |
  { 'PriceChange' : bigint } |
  { 'NoListing' : null } |
  { 'InsufficientFunds' : null };
export type Error__1 = { 'NotFile' : Path__1 } |
  { 'Invalid' : Path__1 } |
  { 'IncompatibleInode' : null } |
  { 'Busy' : null } |
  { 'TryAgain' : null } |
  { 'NotPermitted' : null } |
  { 'NotFound' : Path__1 } |
  { 'Unauthorized' : null } |
  { 'AlreadyExists' : Path__1 } |
  { 'EmptyPath' : Path__1 } |
  { 'FailedInit' : string } |
  { 'NotDirectory' : Path__1 } |
  { 'Corrupted' : null } |
  { 'FatalFault' : null } |
  { 'ServiceLimit' : null };
export type Extension = string;
export type Fee = bigint;
export interface File {
  'ftype' : MimeType,
  'owner' : Principal,
  'mode' : Mode,
  'name' : Handle,
  'size' : Bytes,
  'pointer' : { 'token' : StreamingToken, 'callback' : StreamingCallback },
  'group' : Array<Principal>,
  'timestamp' : Time__3,
}
export type Handle = string;
export type HeaderField = [string, string];
export type Index = bigint;
export type Index__1 = bigint;
export type Index__2 = bigint;
export interface InitConfig {
  'base_fee' : bigint,
  'initial_supply' : bigint,
  'minter' : Principal,
  'markets' : Array<AccountId__1>,
  'firesale_threshold' : bigint,
  'heartbeat' : Principal,
  'admins' : Array<Principal>,
  'royalty_address' : AccountId__1,
  'mountpath' : string,
  'max_fee' : bigint,
  'fileshare' : Principal,
}
export type Inode = { 'Reserved' : Principal } |
  { 'File' : File } |
  { 'Directory' : Directory };
export type Keyword = { 'wild' : null } |
  { 'word' : string };
export interface ListRequest {
  'token' : TokenIdentifier,
  'from_subaccount' : [] | [SubAccount],
  'price' : [] | [bigint],
}
export interface Listing {
  'locked' : [] | [Time],
  'seller' : Principal,
  'allowance' : Fee,
  'price' : bigint,
  'royalty' : Fee,
}
export interface Listing__1 {
  'locked' : [] | [Time__1],
  'seller' : Principal,
  'price' : bigint,
}
export interface Lock {
  'status' : { 'busy' : null } |
    { 'idle' : null },
  'fees' : [] | [Array<[AccountId, bigint]>],
  'subaccount' : [] | [SubAccount__2],
  'buyer' : [] | [AccountId],
  'firesale' : boolean,
}
export interface MarketListRequest {
  'token' : TokenId__1,
  'from_subaccount' : [] | [SubAccount__1],
  'allowance' : Allowance,
  'price' : [] | [Price],
}
export interface MarketLockRequest {
  'token' : TokenId__1,
  'fees' : Array<[AccountId__1, bigint]>,
  'subaccount' : SubAccount__1,
  'buyer' : AccountId__1,
  'price' : bigint,
}
export type Memo = Uint8Array | number[];
export type Metadata = {
    'nonfungible' : { 'metadata' : [] | [Uint8Array | number[]] }
  };
export type Metadata__1 = {
    'nonfungible' : { 'metadata' : [] | [Uint8Array | number[]] }
  };
export type MimeType = string;
export interface MintRequest { 'path' : Path, 'receiver' : Principal }
export type Mode = [Priv, Priv];
export type Mount = Array<Inode>;
export interface NFT_Registry {
  'acceptCycles' : ActorMethod<[], undefined>,
  'add_affiliate' : ActorMethod<[AccountId__1], undefined>,
  'admin_query_settlement' : ActorMethod<[Index], [] | [StableLock]>,
  'admins' : ActorMethod<[], Array<Principal>>,
  'affiliates' : ActorMethod<[], Array<AccountId__1>>,
  'allSettlements' : ActorMethod<[], Array<[TokenIndex, Settlement]>>,
  'areTokensLocked' : ActorMethod<[Array<Index>], Return_12>,
  'balance' : ActorMethod<[BalanceRequest], Return_11>,
  'bearer' : ActorMethod<[TokenId__1], Return_8>,
  'check_listing' : ActorMethod<[], boolean>,
  'check_metadata' : ActorMethod<[Index, string], Value>,
  'details' : ActorMethod<[TokenId__1], Return_10>,
  'export_filesystem' : ActorMethod<[], Return_9>,
  'extensions' : ActorMethod<[], Array<Extension>>,
  'fees' : ActorMethod<[], [bigint, bigint, bigint]>,
  'fileshareId' : ActorMethod<[], Principal>,
  'getDisbursements' : ActorMethod<[], Array<Disbursement>>,
  'getRegistry' : ActorMethod<[], Array<[TokenIndex, AccountId__1]>>,
  'getTokenId' : ActorMethod<[Index], TokenId__1>,
  'getTokens' : ActorMethod<[], Array<[TokenIndex, Metadata]>>,
  'get_royalty_address' : ActorMethod<[], AccountId__1>,
  'heartbeat_disable' : ActorMethod<[], undefined>,
  'heartbeat_enable' : ActorMethod<[], undefined>,
  'heartbeat_external' : ActorMethod<[], undefined>,
  'heartbeat_pending' : ActorMethod<[], Array<[string, bigint]>>,
  'heartbeat_start' : ActorMethod<[], undefined>,
  'heartbeat_stop' : ActorMethod<[], undefined>,
  'http_request' : ActorMethod<[Request], Response>,
  'init' : ActorMethod<[InitConfig], Return_6>,
  'isHeartbeatRunning' : ActorMethod<[], boolean>,
  'lastUpdate' : ActorMethod<[], Time__2>,
  'lastbeat' : ActorMethod<[], string>,
  'license' : ActorMethod<[TokenId__1], Result>,
  'list' : ActorMethod<[ListRequest], Return_4>,
  'listings' : ActorMethod<[], Array<[TokenIndex, Listing__1, Metadata__1]>>,
  'lock' : ActorMethod<
    [TokenId__1, bigint, AccountId__1, SubAccount__1],
    Return_8
  >,
  'locks' : ActorMethod<[], Array<[Index, Lock]>>,
  'market_list' : ActorMethod<[MarketListRequest], Return_4>,
  'market_listings' : ActorMethod<
    [],
    Array<[TokenIndex, Listing, Attributes, Metadata__1]>
  >,
  'market_lock' : ActorMethod<[MarketLockRequest], Return_8>,
  'metadata' : ActorMethod<[TokenId__1], Return_7>,
  'mint_nft' : ActorMethod<[MintRequest], [] | [Index]>,
  'minter' : ActorMethod<[], Principal>,
  'mount' : ActorMethod<[Path], Return_6>,
  'process_disbursements' : ActorMethod<[], undefined>,
  'process_refunds' : ActorMethod<[], undefined>,
  'report_balance' : ActorMethod<[], undefined>,
  'reschedule' : ActorMethod<[], Return_6>,
  'set_admins' : ActorMethod<[Array<Principal>], Array<Principal>>,
  'set_fees' : ActorMethod<[[bigint, bigint, bigint]], undefined>,
  'set_minter' : ActorMethod<[Principal], undefined>,
  'set_revealed' : ActorMethod<[boolean], undefined>,
  'set_royalty_address' : ActorMethod<[AccountId__1], Return_5>,
  'settle' : ActorMethod<[TokenId__1], Return_4>,
  'settle_all' : ActorMethod<[], undefined>,
  'settlements' : ActorMethod<[], Array<[TokenIndex, AccountId__1, bigint]>>,
  'stats' : ActorMethod<
    [],
    [bigint, bigint, bigint, bigint, bigint, bigint, bigint]
  >,
  'supply' : ActorMethod<[TokenId__1], Return_3>,
  'tokens' : ActorMethod<[AccountId__1], Return_2>,
  'tokens_ext' : ActorMethod<[AccountId__1], Return_1>,
  'transactions' : ActorMethod<[], Array<Transaction>>,
  'transfer' : ActorMethod<[TransferRequest], Return>,
  'update_assets' : ActorMethod<[[bigint, bigint], Keyword], [] | [bigint]>,
  'update_attributes' : ActorMethod<[Array<TokenAttributes>], undefined>,
}
export type Path = string;
export type Path__1 = string;
export type Price = bigint;
export type Priv = { 'NO' : null } |
  { 'RO' : null } |
  { 'RW' : null } |
  { 'WO' : null };
export interface Request {
  'url' : string,
  'method' : string,
  'body' : Uint8Array | number[],
  'headers' : Array<HeaderField>,
}
export interface Response {
  'body' : Uint8Array | number[],
  'headers' : Array<HeaderField>,
  'streaming_strategy' : [] | [StreamingStrategy],
  'status_code' : number,
}
export type Result = { 'ok' : string } |
  { 'err' : CommonError };
export type Return = { 'ok' : Balance__1 } |
  { 'err' : TransferError };
export type Return_1 = {
    'ok' : Array<[TokenIndex, [] | [Listing], [] | [Uint8Array | number[]]]>
  } |
  { 'err' : CommonError };
export type Return_10 = { 'ok' : [AccountId__1, [] | [Listing]] } |
  { 'err' : CommonError };
export type Return_11 = { 'ok' : bigint } |
  { 'err' : CommonError };
export type Return_12 = { 'ok' : Array<Index> } |
  { 'err' : CommonError };
export type Return_2 = { 'ok' : Uint32Array | number[] } |
  { 'err' : CommonError };
export type Return_3 = { 'ok' : Balance__1 } |
  { 'err' : CommonError };
export type Return_4 = { 'ok' : null } |
  { 'err' : CommonError };
export type Return_5 = { 'ok' : null } |
  { 'err' : string };
export type Return_6 = { 'ok' : null } |
  { 'err' : Error };
export type Return_7 = { 'ok' : Metadata } |
  { 'err' : CommonError };
export type Return_8 = { 'ok' : AccountId__1 } |
  { 'err' : CommonError };
export type Return_9 = { 'ok' : Mount } |
  { 'err' : Error__1 };
export interface Settlement {
  'subaccount' : SubAccount,
  'seller' : Principal,
  'buyer' : AccountIdentifier,
  'price' : bigint,
}
export interface StableLock {
  'status' : { 'busy' : null } |
    { 'idle' : null },
  'fees' : Array<[AccountId__1, bigint]>,
  'subaccount' : SubAccount__1,
  'seller' : Principal,
  'buyer' : AccountId__1,
  'price' : bigint,
  'firesale' : boolean,
}
export interface Stream {
  'ftype' : string,
  'name' : string,
  'pointer' : { 'token' : StreamingToken, 'callback' : StreamingCallback },
}
export type StreamingCallback = ActorMethod<
  [StreamingToken],
  StreamingResponse
>;
export interface StreamingResponse {
  'token' : [] | [StreamingToken],
  'body' : Uint8Array | number[],
}
export type StreamingStrategy = {
    'Callback' : { 'token' : StreamingToken, 'callback' : StreamingCallback }
  };
export interface StreamingToken {
  'key' : string,
  'stop' : [bigint, bigint],
  'nested' : Array<[StreamingCallback, StreamingToken]>,
  'start' : [bigint, bigint],
}
export type SubAccount = Uint8Array | number[];
export type SubAccount__1 = Uint8Array | number[];
export type SubAccount__2 = Uint8Array | number[];
export type Time = bigint;
export type Time__1 = bigint;
export type Time__2 = bigint;
export type Time__3 = bigint;
export interface TokenAttributes {
  'attributes' : [] | [Uint8Array | number[]],
  'index' : Index,
}
export type TokenId = string;
export type TokenId__1 = string;
export type TokenIdentifier = string;
export type TokenIndex = number;
export interface Transaction {
  'token' : TokenId,
  'time' : Time,
  'seller' : Principal,
  'buyer' : AccountId,
  'price' : bigint,
}
export type TransferError = { 'CannotNotify' : AccountIdentifier } |
  { 'InsufficientBalance' : null } |
  { 'InvalidToken' : TokenIdentifier } |
  { 'Rejected' : null } |
  { 'Unauthorized' : AccountIdentifier } |
  { 'Other' : string };
export interface TransferRequest {
  'to' : User,
  'token' : TokenIdentifier,
  'notify' : boolean,
  'from' : User,
  'memo' : Memo,
  'subaccount' : [] | [SubAccount],
  'amount' : Balance,
}
export type User = { 'principal' : Principal } |
  { 'address' : AccountIdentifier };
export type Value = { 'url' : string } |
  { 'stream' : Stream } |
  { 'blob' : Uint8Array | number[] } |
  { 'none' : null };
export interface _SERVICE extends NFT_Registry {}
