import type { Principal } from '@dfinity/principal';
import type { ActorMethod } from '@dfinity/agent';

export type AccountIdentifier = string;
export type AccountIdentifier__1 = string;
export interface Asset {
  'thumbnail' : [] | [File],
  'name' : string,
  'payload' : File,
}
export type Balance = bigint;
export interface BalanceRequest { 'token' : TokenIdentifier, 'user' : User }
export type BalanceResponse = { 'ok' : Balance } |
  { 'err' : CommonError__1 };
export type Balance__1 = bigint;
export type CanisterCyclesAggregatedData = BigUint64Array | bigint[];
export type CanisterHeapMemoryAggregatedData = BigUint64Array | bigint[];
export type CanisterLogFeature = { 'filterMessageByContains' : null } |
  { 'filterMessageByRegex' : null };
export interface CanisterLogMessages {
  'data' : Array<LogMessagesData>,
  'lastAnalyzedMessageTimeNanos' : [] | [Nanos],
}
export interface CanisterLogMessagesInfo {
  'features' : Array<[] | [CanisterLogFeature]>,
  'lastTimeNanos' : [] | [Nanos],
  'count' : number,
  'firstTimeNanos' : [] | [Nanos],
}
export type CanisterLogRequest = { 'getMessagesInfo' : null } |
  { 'getMessages' : GetLogMessagesParameters } |
  { 'getLatestMessages' : GetLatestLogMessagesParameters };
export type CanisterLogResponse = { 'messagesInfo' : CanisterLogMessagesInfo } |
  { 'messages' : CanisterLogMessages };
export type CanisterMemoryAggregatedData = BigUint64Array | bigint[];
export interface CanisterMetrics { 'data' : CanisterMetricsData }
export type CanisterMetricsData = { 'hourly' : Array<HourlyMetricsData> } |
  { 'daily' : Array<DailyMetricsData> };
export type CommonError = { 'InvalidToken' : TokenIdentifier } |
  { 'Other' : string };
export type CommonError__1 = { 'InvalidToken' : TokenIdentifier } |
  { 'Other' : string };
export interface DailyMetricsData {
  'updateCalls' : bigint,
  'canisterHeapMemorySize' : NumericEntity,
  'canisterCycles' : NumericEntity,
  'canisterMemorySize' : NumericEntity,
  'timeMillis' : bigint,
}
export type Extension = string;
export interface File {
  'data' : Array<Uint8Array | number[]>,
  'ctype' : string,
}
export interface GetLatestLogMessagesParameters {
  'upToTimeNanos' : [] | [Nanos],
  'count' : number,
  'filter' : [] | [GetLogMessagesFilter],
}
export interface GetLogMessagesFilter {
  'analyzeCount' : number,
  'messageRegex' : [] | [string],
  'messageContains' : [] | [string],
}
export interface GetLogMessagesParameters {
  'count' : number,
  'filter' : [] | [GetLogMessagesFilter],
  'fromTimeNanos' : [] | [Nanos],
}
export interface GetMetricsParameters {
  'dateToMillis' : bigint,
  'granularity' : MetricsGranularity,
  'dateFromMillis' : bigint,
}
export type HeaderField = [string, string];
export interface HourlyMetricsData {
  'updateCalls' : UpdateCallsAggregatedData,
  'canisterHeapMemorySize' : CanisterHeapMemoryAggregatedData,
  'canisterCycles' : CanisterCyclesAggregatedData,
  'canisterMemorySize' : CanisterMemoryAggregatedData,
  'timeMillis' : bigint,
}
export interface HttpRequest {
  'url' : string,
  'method' : string,
  'body' : Uint8Array | number[],
  'headers' : Array<HeaderField>,
}
export interface HttpResponse {
  'body' : Uint8Array | number[],
  'headers' : Array<HeaderField>,
  'streaming_strategy' : [] | [HttpStreamingStrategy],
  'status_code' : number,
}
export interface HttpStreamingCallbackResponse {
  'token' : [] | [HttpStreamingCallbackToken],
  'body' : Uint8Array | number[],
}
export interface HttpStreamingCallbackToken {
  'key' : string,
  'sha256' : [] | [Uint8Array | number[]],
  'index' : bigint,
  'content_encoding' : string,
}
export type HttpStreamingStrategy = {
    'Callback' : {
      'token' : HttpStreamingCallbackToken,
      'callback' : [Principal, string],
    }
  };
export interface ListRequest {
  'token' : TokenIdentifier__1,
  'from_subaccount' : [] | [SubAccount__1],
  'price' : [] | [bigint],
}
export interface Listing {
  'locked' : [] | [Time],
  'seller' : Principal,
  'price' : bigint,
}
export interface LogMessagesData { 'timeNanos' : Nanos, 'message' : string }
export type Memo = Uint8Array | number[];
export type Metadata = {
    'fungible' : {
      'decimals' : number,
      'metadata' : [] | [Uint8Array | number[]],
      'name' : string,
      'symbol' : string,
    }
  } |
  { 'nonfungible' : { 'metadata' : [] | [Uint8Array | number[]] } };
export type MetricsGranularity = { 'hourly' : null } |
  { 'daily' : null };
export interface MintingRequest {
  'to' : AccountIdentifier__1,
  'asset' : number,
}
export type Nanos = bigint;
export interface NumericEntity {
  'avg' : bigint,
  'max' : bigint,
  'min' : bigint,
  'first' : bigint,
  'last' : bigint,
}
export interface PixelCollection {
  'acceptCycles' : ActorMethod<[], undefined>,
  'addAsset' : ActorMethod<[Asset], bigint>,
  'add_license' : ActorMethod<[string, string], undefined>,
  'allPayments' : ActorMethod<[], Array<[Principal, Array<SubAccount__1>]>>,
  'allSettlements' : ActorMethod<[], Array<[TokenIndex, Settlement]>>,
  'availableCycles' : ActorMethod<[], bigint>,
  'balance' : ActorMethod<[BalanceRequest], BalanceResponse>,
  'bearer' : ActorMethod<[TokenIdentifier__1], Result_5>,
  'clearPayments' : ActorMethod<[Principal, Array<SubAccount__1>], undefined>,
  'collectCanisterMetrics' : ActorMethod<[], undefined>,
  'cronCapEvents' : ActorMethod<[], undefined>,
  'cronDisbursements' : ActorMethod<[], undefined>,
  'cronSettlements' : ActorMethod<[], undefined>,
  'details' : ActorMethod<[TokenIdentifier__1], Result_7>,
  'extensions' : ActorMethod<[], Array<Extension>>,
  'getCanisterLog' : ActorMethod<
    [[] | [CanisterLogRequest]],
    [] | [CanisterLogResponse]
  >,
  'getCanisterMetrics' : ActorMethod<
    [GetMetricsParameters],
    [] | [CanisterMetrics]
  >,
  'getMinter' : ActorMethod<[], Principal>,
  'getRegistry' : ActorMethod<[], Array<[TokenIndex, AccountIdentifier__1]>>,
  'getTokens' : ActorMethod<[], Array<[TokenIndex, Metadata]>>,
  'get_token_identifier' : ActorMethod<[TokenIndex], TokenIdentifier__1>,
  'get_transaction_count' : ActorMethod<[], bigint>,
  'heartbeat_external' : ActorMethod<[], undefined>,
  'heartbeat_pending' : ActorMethod<[], Array<[string, bigint]>>,
  'heartbeat_start' : ActorMethod<[], undefined>,
  'heartbeat_stop' : ActorMethod<[], undefined>,
  'historicExport' : ActorMethod<[], boolean>,
  'http_request' : ActorMethod<[HttpRequest], HttpResponse>,
  'http_request_streaming_callback' : ActorMethod<
    [HttpStreamingCallbackToken],
    HttpStreamingCallbackResponse
  >,
  'init' : ActorMethod<[string], Result_3>,
  'isHeartbeatRunning' : ActorMethod<[], boolean>,
  'lastbeat' : ActorMethod<[], bigint>,
  'license' : ActorMethod<[TokenIdentifier__1], Result_6>,
  'list' : ActorMethod<[ListRequest], Result_3>,
  'listings' : ActorMethod<[], Array<[TokenIndex, Listing, Metadata]>>,
  'lock' : ActorMethod<
    [TokenIdentifier__1, bigint, AccountIdentifier__1, SubAccount__1],
    Result_5
  >,
  'map_license' : ActorMethod<[TokenIndex, string], undefined>,
  'metadata' : ActorMethod<[TokenIdentifier__1], Result_4>,
  'mintNFT' : ActorMethod<[MintingRequest], TokenIndex>,
  'payments' : ActorMethod<[], [] | [Array<SubAccount__1>]>,
  'pulse' : ActorMethod<[], undefined>,
  'setLogLevel' : ActorMethod<[number], undefined>,
  'setMinter' : ActorMethod<[Principal], undefined>,
  'settle' : ActorMethod<[TokenIdentifier__1], Result_3>,
  'settlements' : ActorMethod<
    [],
    Array<[TokenIndex, AccountIdentifier__1, bigint]>
  >,
  'startHeartbeat' : ActorMethod<[], undefined>,
  'stats' : ActorMethod<
    [],
    [bigint, bigint, bigint, bigint, bigint, bigint, bigint]
  >,
  'stopHeartbeat' : ActorMethod<[], undefined>,
  'streamAsset' : ActorMethod<
    [bigint, boolean, Uint8Array | number[]],
    undefined
  >,
  'supply' : ActorMethod<[TokenIdentifier__1], Result_2>,
  'tokens' : ActorMethod<[AccountIdentifier__1], Result_1>,
  'tokens_ext' : ActorMethod<[AccountIdentifier__1], Result>,
  'transactions' : ActorMethod<[], Array<Transaction>>,
  'transfer' : ActorMethod<[TransferRequest], TransferResponse>,
  'updateAsset' : ActorMethod<[UpdateRequest], bigint>,
  'updateThumb' : ActorMethod<[string, File], [] | [bigint]>,
}
export type Result = {
    'ok' : Array<[TokenIndex, [] | [Listing], [] | [Uint8Array | number[]]]>
  } |
  { 'err' : CommonError };
export type Result_1 = { 'ok' : Uint32Array | number[] } |
  { 'err' : CommonError };
export type Result_2 = { 'ok' : Balance__1 } |
  { 'err' : CommonError };
export type Result_3 = { 'ok' : null } |
  { 'err' : CommonError };
export type Result_4 = { 'ok' : Metadata } |
  { 'err' : CommonError };
export type Result_5 = { 'ok' : AccountIdentifier__1 } |
  { 'err' : CommonError };
export type Result_6 = { 'ok' : string } |
  { 'err' : CommonError };
export type Result_7 = { 'ok' : [AccountIdentifier__1, [] | [Listing]] } |
  { 'err' : CommonError };
export interface Settlement {
  'subaccount' : SubAccount__1,
  'seller' : Principal,
  'buyer' : AccountIdentifier__1,
  'price' : bigint,
}
export type SubAccount = Uint8Array | number[];
export type SubAccount__1 = Uint8Array | number[];
export type Time = bigint;
export type TokenIdentifier = string;
export type TokenIdentifier__1 = string;
export type TokenIndex = number;
export interface Transaction {
  'token' : TokenIdentifier__1,
  'time' : Time,
  'seller' : Principal,
  'buyer' : AccountIdentifier__1,
  'price' : bigint,
}
export interface TransferRequest {
  'to' : User,
  'token' : TokenIdentifier,
  'notify' : boolean,
  'from' : User,
  'memo' : Memo,
  'subaccount' : [] | [SubAccount],
  'amount' : Balance,
}
export type TransferResponse = { 'ok' : Balance } |
  {
    'err' : { 'CannotNotify' : AccountIdentifier } |
      { 'InsufficientBalance' : null } |
      { 'InvalidToken' : TokenIdentifier } |
      { 'Rejected' : null } |
      { 'Unauthorized' : AccountIdentifier } |
      { 'Other' : string }
  };
export type UpdateCallsAggregatedData = BigUint64Array | bigint[];
export interface UpdateRequest { 'assetID' : bigint, 'payload' : File }
export type User = { 'principal' : Principal } |
  { 'address' : AccountIdentifier };
export interface _SERVICE extends PixelCollection {}
