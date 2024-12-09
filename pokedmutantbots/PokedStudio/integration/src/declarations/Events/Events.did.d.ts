import type { Principal } from '@dfinity/principal';
import type { ActorMethod } from '@dfinity/agent';

export type AccountIdentifier = string;
export type AccountIdentifier__1 = string;
export type AccountIdentifier__2 = string;
export type Balance = bigint;
export type Balance__1 = bigint;
export interface BulkTransferRequest {
  'to' : User,
  'notify' : boolean,
  'from' : User,
  'memo' : Memo,
  'subaccount' : [] | [SubAccount],
  'tokens' : Array<TokenIdentifier>,
  'amount' : Balance,
}
export interface BurnInstruction {
  'request' : BulkTransferRequest,
  'reference' : Index__1,
  'transfer' : [Principal, string],
}
export interface BurnRequest {
  'subaccount' : [] | [SubAccount],
  'tokens' : Array<TokenIdentifier>,
  'category' : Category,
}
export type Category = { 'cat1' : null } |
  { 'cat2' : null } |
  { 'cat3' : null } |
  { 'cat4' : null } |
  { 'cat5' : null };
export type Category__1 = { 'cat1' : null } |
  { 'cat2' : null } |
  { 'cat3' : null } |
  { 'cat4' : null } |
  { 'cat5' : null };
export type ClaimRequest = { 'burn' : Index__1 } |
  { 'drop' : SubAccount };
export interface Configuration {
  'snapshot' : [] | [Principal],
  'mapping' : Array<[TokenIndex__1, TokenIndex__1]>,
  'inventory' : Array<[Category, Uint32Array]>,
  'event' : ServiceState__1,
  'recipients' : Array<
    [AccountIdentifier, [bigint, bigint, bigint, bigint, bigint]]
  >,
  'requirements' : [
    [] | [bigint],
    [] | [bigint],
    [] | [bigint],
    [] | [bigint],
    [] | [bigint],
  ],
  'registry' : Principal,
  'burn_registry' : [] | [Principal],
}
export type Error = { 'BadCategory' : Category } |
  { 'ProcessingRequest' : null } |
  { 'NotWhitelisted' : AccountIdentifier } |
  { 'RequestCancelled' : null } |
  { 'AlreadySettled' : null } |
  { 'ActiveRequest' : SharedRequest } |
  { 'TokenIsLocked' : TokenIdentifier } |
  { 'InsufficientCredits' : null } |
  { 'UnknownState' : null } |
  { 'AlreadyClaimed' : null } |
  { 'NothingToRefund' : null } |
  { 'InvalidToken' : TokenIdentifier } |
  { 'InsufficientTokens' : bigint } |
  { 'Unauthorized' : AccountIdentifier } |
  { 'AlreadyBurned' : TokenIdentifier } |
  { 'AlreadyRefunded' : null } |
  { 'Other' : string } |
  { 'ConfigError' : string } |
  { 'DoesNotExist' : null } |
  { 'TransferFailed' : null } |
  { 'RefundFailed' : null } |
  { 'BeingProcessed' : null } |
  { 'ConditionsNotMet' : null };
export interface Event {
  'memo' : Uint8Array,
  'claimed' : Array<TokenIdentifier>,
  'address' : AccountIdentifier,
  'timestamp' : Time,
  'burned' : Array<TokenIdentifier>,
}
export interface ExtSwap {
  'add_admin' : ActorMethod<[Principal], undefined>,
  'admins' : ActorMethod<[], Array<Principal>>,
  'aid' : ActorMethod<[Principal], AccountIdentifier__1>,
  'all_candidates' : ActorMethod<[], Array<[TokenIdentifier__1, TokenState]>>,
  'bulkTokenTransferNotification' : ActorMethod<
    [Array<TokenIdentifier__1>, User__1, Balance__1, Memo__1],
    [] | [Balance__1]
  >,
  'burn' : ActorMethod<[BurnRequest], Return_2>,
  'burn_registry' : ActorMethod<[], Principal>,
  'burn_tokenid' : ActorMethod<[number], TokenIdentifier__1>,
  'burned' : ActorMethod<[], bigint>,
  'cancel' : ActorMethod<[Index], Return>,
  'candidates' : ActorMethod<[], Array<TokenIdentifier__1>>,
  'claim' : ActorMethod<[ClaimRequest], Return_1>,
  'claim_registry' : ActorMethod<[], Principal>,
  'claimed' : ActorMethod<[Principal], Array<[TokenIndex, Index]>>,
  'configure' : ActorMethod<[Configuration], Return>,
  'credits' : ActorMethod<[AccountIdentifier__1], [] | [StableCredits__1]>,
  'del_admin' : ActorMethod<[Principal], undefined>,
  'event_by_id' : ActorMethod<[Index], [] | [Event]>,
  'holdings' : ActorMethod<[], Array<[AccountIdentifier__1, Uint32Array]>>,
  'init' : ActorMethod<[], undefined>,
  'inventory' : ActorMethod<
    [],
    Array<[Category__1, Array<TokenIdentifier__1>]>
  >,
  'pulse' : ActorMethod<[], undefined>,
  'rand_cache' : ActorMethod<[], bigint>,
  'rand_size' : ActorMethod<[], bigint>,
  'refund' : ActorMethod<[Index], Return>,
  'reset' : ActorMethod<[], Return>,
  'reset_test' : ActorMethod<[], undefined>,
  'self_aid' : ActorMethod<[], AccountIdentifier__1>,
  'service_state' : ActorMethod<[], [ServiceState, boolean]>,
  'set_admins' : ActorMethod<[Array<Principal>], undefined>,
  'start' : ActorMethod<[], undefined>,
  'stop' : ActorMethod<[], undefined>,
  'tid' : ActorMethod<[Principal, number], TokenIdentifier__1>,
  'user_events' : ActorMethod<[AccountIdentifier__1], Array<Event>>,
  'whitelist' : ActorMethod<[], StableWhitelist>,
}
export type Index = bigint;
export type Index__1 = bigint;
export type Memo = Uint8Array;
export type Memo__1 = Uint8Array;
export type RequestStatus = { 'cancelled' : null } |
  { 'settled' : null } |
  { 'submitted' : null } |
  { 'busy' : null } |
  { 'refunded' : null } |
  { 'claimed' : null };
export type Return = { 'ok' : null } |
  { 'err' : Error };
export type Return_1 = { 'ok' : Array<TokenIdentifier__1> } |
  { 'err' : Error };
export type Return_2 = { 'ok' : BurnInstruction } |
  { 'err' : Error };
export type ServiceState = { 'burn' : null } |
  { 'drop' : null } |
  { 'swap' : null } |
  { 'inactive' : null };
export type ServiceState__1 = { 'burn' : null } |
  { 'drop' : null } |
  { 'swap' : null } |
  { 'inactive' : null };
export interface SharedRequest {
  'status' : RequestStatus,
  'owner' : Principal,
  'subaccount' : [] | [SubAccount],
  'category' : Category,
  'candidates' : Array<TokenIdentifier>,
}
export type StableCredits = [bigint, bigint, bigint, bigint, bigint];
export type StableCredits__1 = [bigint, bigint, bigint, bigint, bigint];
export type StableWhitelist = Array<StableWhitelistEntry>;
export type StableWhitelistEntry = [AccountIdentifier, StableCredits];
export type SubAccount = Uint8Array;
export type Time = bigint;
export type TokenIdentifier = string;
export type TokenIdentifier__1 = string;
export type TokenIndex = number;
export type TokenIndex__1 = number;
export type TokenState = { 'locked' : null } |
  { 'unlocked' : null } |
  { 'burned' : null };
export type TransferResponse = { 'ok' : Balance } |
  {
    'err' : { 'CannotNotify' : AccountIdentifier } |
      { 'InsufficientBalance' : null } |
      { 'InvalidToken' : TokenIdentifier } |
      { 'Rejected' : null } |
      { 'Unauthorized' : AccountIdentifier } |
      { 'Other' : string }
  };
export type User = { 'principal' : Principal } |
  { 'address' : AccountIdentifier };
export type User__1 = { 'principal' : Principal } |
  { 'address' : AccountIdentifier__2 };
export interface _SERVICE extends ExtSwap {}
