export const idlFactory = ({ IDL }) => {
  const StreamingToken = IDL.Rec();
  const Index = IDL.Nat;
  const AccountId__1 = IDL.Text;
  const SubAccount__1 = IDL.Vec(IDL.Nat8);
  const StableLock = IDL.Record({
    'status' : IDL.Variant({ 'busy' : IDL.Null, 'idle' : IDL.Null }),
    'fees' : IDL.Vec(IDL.Tuple(AccountId__1, IDL.Nat64)),
    'subaccount' : SubAccount__1,
    'seller' : IDL.Principal,
    'buyer' : AccountId__1,
    'price' : IDL.Nat64,
    'firesale' : IDL.Bool,
  });
  const TokenIndex = IDL.Nat32;
  const SubAccount = IDL.Vec(IDL.Nat8);
  const AccountIdentifier = IDL.Text;
  const Settlement = IDL.Record({
    'subaccount' : SubAccount,
    'seller' : IDL.Principal,
    'buyer' : AccountIdentifier,
    'price' : IDL.Nat64,
  });
  const TokenIdentifier = IDL.Text;
  const User = IDL.Variant({
    'principal' : IDL.Principal,
    'address' : AccountIdentifier,
  });
  const BalanceRequest = IDL.Record({
    'token' : TokenIdentifier,
    'user' : User,
  });
  const CommonError = IDL.Variant({
    'InvalidToken' : TokenIdentifier,
    'Other' : IDL.Text,
  });
  const Return_9 = IDL.Variant({ 'ok' : IDL.Nat, 'err' : CommonError });
  const TokenId__1 = IDL.Text;
  const Return_7 = IDL.Variant({ 'ok' : AccountId__1, 'err' : CommonError });
  const Time = IDL.Int;
  const Fee = IDL.Nat64;
  const Listing = IDL.Record({
    'locked' : IDL.Opt(Time),
    'seller' : IDL.Principal,
    'allowance' : Fee,
    'price' : IDL.Nat64,
    'royalty' : Fee,
  });
  const Return_8 = IDL.Variant({
    'ok' : IDL.Tuple(AccountId__1, IDL.Opt(Listing)),
    'err' : CommonError,
  });
  const Extension = IDL.Text;
  const Index__1 = IDL.Nat;
  const AccountId = IDL.Text;
  const Disbursement = IDL.Tuple(
    Index__1,
    AccountId,
    IDL.Vec(IDL.Nat8),
    IDL.Nat64,
  );
  const Metadata = IDL.Variant({
    'nonfungible' : IDL.Record({ 'metadata' : IDL.Opt(IDL.Vec(IDL.Nat8)) }),
  });
  const HeaderField = IDL.Tuple(IDL.Text, IDL.Text);
  const Request = IDL.Record({
    'url' : IDL.Text,
    'method' : IDL.Text,
    'body' : IDL.Vec(IDL.Nat8),
    'headers' : IDL.Vec(HeaderField),
  });
  const StreamingResponse = IDL.Record({
    'token' : IDL.Opt(StreamingToken),
    'body' : IDL.Vec(IDL.Nat8),
  });
  const StreamingCallback = IDL.Func(
      [StreamingToken],
      [StreamingResponse],
      ['query'],
    );
  StreamingToken.fill(
    IDL.Record({
      'key' : IDL.Text,
      'stop' : IDL.Tuple(IDL.Nat, IDL.Nat),
      'nested' : IDL.Vec(IDL.Tuple(StreamingCallback, StreamingToken)),
      'start' : IDL.Tuple(IDL.Nat, IDL.Nat),
    })
  );
  const StreamingStrategy = IDL.Variant({
    'Callback' : IDL.Record({
      'token' : StreamingToken,
      'callback' : StreamingCallback,
    }),
  });
  const Response = IDL.Record({
    'body' : IDL.Vec(IDL.Nat8),
    'headers' : IDL.Vec(HeaderField),
    'streaming_strategy' : IDL.Opt(StreamingStrategy),
    'status_code' : IDL.Nat16,
  });
  const InitConfig = IDL.Record({
    'base_fee' : IDL.Nat64,
    'initial_supply' : IDL.Nat,
    'minter' : IDL.Principal,
    'markets' : IDL.Vec(AccountId__1),
    'firesale_threshold' : IDL.Nat,
    'heartbeat' : IDL.Principal,
    'admins' : IDL.Vec(IDL.Principal),
    'royalty_address' : AccountId__1,
    'mountpath' : IDL.Text,
    'max_fee' : IDL.Nat64,
    'fileshare' : IDL.Principal,
  });
  const Error = IDL.Variant({
    'LockExpired' : IDL.Null,
    'Busy' : IDL.Null,
    'DelistingRequested' : IDL.Null,
    'NotLocked' : IDL.Null,
    'FeeTooHigh' : IDL.Nat64,
    'UnauthorizedMarket' : AccountId,
    'Locked' : IDL.Null,
    'Fatal' : IDL.Text,
    'FeeTooSmall' : IDL.Nat64,
    'ConfigError' : IDL.Text,
    'PriceChange' : IDL.Nat64,
    'NoListing' : IDL.Null,
    'InsufficientFunds' : IDL.Null,
  });
  const Return_5 = IDL.Variant({ 'ok' : IDL.Null, 'err' : Error });
  const Time__2 = IDL.Int;
  const Result = IDL.Variant({ 'ok' : IDL.Text, 'err' : CommonError });
  const ListRequest = IDL.Record({
    'token' : TokenIdentifier,
    'from_subaccount' : IDL.Opt(SubAccount),
    'price' : IDL.Opt(IDL.Nat64),
  });
  const Return_4 = IDL.Variant({ 'ok' : IDL.Null, 'err' : CommonError });
  const Time__1 = IDL.Int;
  const Listing__1 = IDL.Record({
    'locked' : IDL.Opt(Time__1),
    'seller' : IDL.Principal,
    'price' : IDL.Nat64,
  });
  const Metadata__1 = IDL.Variant({
    'nonfungible' : IDL.Record({ 'metadata' : IDL.Opt(IDL.Vec(IDL.Nat8)) }),
  });
  const SubAccount__2 = IDL.Vec(IDL.Nat8);
  const Lock = IDL.Record({
    'status' : IDL.Variant({ 'busy' : IDL.Null, 'idle' : IDL.Null }),
    'fees' : IDL.Opt(IDL.Vec(IDL.Tuple(AccountId, IDL.Nat64))),
    'subaccount' : IDL.Opt(SubAccount__2),
    'buyer' : IDL.Opt(AccountId),
    'firesale' : IDL.Bool,
  });
  const Allowance = IDL.Nat64;
  const Price = IDL.Nat64;
  const MarketListRequest = IDL.Record({
    'token' : TokenId__1,
    'from_subaccount' : IDL.Opt(SubAccount__1),
    'allowance' : Allowance,
    'price' : IDL.Opt(Price),
  });
  const Attributes = IDL.Record({ 'firesale' : IDL.Bool });
  const MarketLockRequest = IDL.Record({
    'token' : TokenId__1,
    'fees' : IDL.Vec(IDL.Tuple(AccountId__1, IDL.Nat64)),
    'subaccount' : SubAccount__1,
    'buyer' : AccountId__1,
    'price' : IDL.Nat64,
  });
  const Return_6 = IDL.Variant({ 'ok' : Metadata, 'err' : CommonError });
  const Path = IDL.Text;
  const MintRequest = IDL.Record({ 'path' : Path, 'receiver' : IDL.Principal });
  const Balance__1 = IDL.Nat;
  const Return_3 = IDL.Variant({ 'ok' : Balance__1, 'err' : CommonError });
  const Return_2 = IDL.Variant({
    'ok' : IDL.Vec(TokenIndex),
    'err' : CommonError,
  });
  const Return_1 = IDL.Variant({
    'ok' : IDL.Vec(
      IDL.Tuple(TokenIndex, IDL.Opt(Listing), IDL.Opt(IDL.Vec(IDL.Nat8)))
    ),
    'err' : CommonError,
  });
  const TokenId = IDL.Text;
  const Transaction = IDL.Record({
    'token' : TokenId,
    'time' : Time,
    'seller' : IDL.Principal,
    'buyer' : AccountId,
    'price' : IDL.Nat64,
  });
  const Memo = IDL.Vec(IDL.Nat8);
  const Balance = IDL.Nat;
  const TransferRequest = IDL.Record({
    'to' : User,
    'token' : TokenIdentifier,
    'notify' : IDL.Bool,
    'from' : User,
    'memo' : Memo,
    'subaccount' : IDL.Opt(SubAccount),
    'amount' : Balance,
  });
  const TransferError = IDL.Variant({
    'CannotNotify' : AccountIdentifier,
    'InsufficientBalance' : IDL.Null,
    'InvalidToken' : TokenIdentifier,
    'Rejected' : IDL.Null,
    'Unauthorized' : AccountIdentifier,
    'Other' : IDL.Text,
  });
  const Return = IDL.Variant({ 'ok' : Balance__1, 'err' : TransferError });
  const BulkTransferRequest = IDL.Record({
    'to' : User,
    'notify' : IDL.Bool,
    'from' : User,
    'memo' : Memo,
    'subaccount' : IDL.Opt(SubAccount),
    'tokens' : IDL.Vec(TokenIdentifier),
    'amount' : Balance,
  });
  const TokenAttributes = IDL.Record({
    'attributes' : IDL.Opt(IDL.Vec(IDL.Nat8)),
    'index' : Index,
  });
  const NFT_Registry = IDL.Service({
    'acceptCycles' : IDL.Func([], [], []),
    'admin_query_settlement' : IDL.Func(
        [Index],
        [IDL.Opt(StableLock)],
        ['query'],
      ),
    'admins' : IDL.Func([], [IDL.Vec(IDL.Principal)], ['query']),
    'allSettlements' : IDL.Func(
        [],
        [IDL.Vec(IDL.Tuple(TokenIndex, Settlement))],
        ['query'],
      ),
    'balance' : IDL.Func([BalanceRequest], [Return_9], ['query']),
    'bearer' : IDL.Func([TokenId__1], [Return_7], ['query']),
    'details' : IDL.Func([TokenId__1], [Return_8], ['query']),
    'extensions' : IDL.Func([], [IDL.Vec(Extension)], ['query']),
    'getDisbursements' : IDL.Func([], [IDL.Vec(Disbursement)], ['query']),
    'getRegistry' : IDL.Func(
        [],
        [IDL.Vec(IDL.Tuple(TokenIndex, AccountId__1))],
        ['query'],
      ),
    'getTokenId' : IDL.Func([Index], [TokenId__1], ['query']),
    'getTokens' : IDL.Func(
        [],
        [IDL.Vec(IDL.Tuple(TokenIndex, Metadata))],
        ['query'],
      ),
    'heartbeat_disable' : IDL.Func([], [], []),
    'heartbeat_enable' : IDL.Func([], [], []),
    'http_request' : IDL.Func([Request], [Response], ['query']),
    'init' : IDL.Func([InitConfig], [Return_5], []),
    'lastUpdate' : IDL.Func([], [Time__2], ['query']),
    'lastbeat' : IDL.Func([], [IDL.Text], ['query']),
    'license' : IDL.Func([TokenId__1], [Result], ['query']),
    'list' : IDL.Func([ListRequest], [Return_4], []),
    'listings' : IDL.Func(
        [],
        [IDL.Vec(IDL.Tuple(TokenIndex, Listing__1, Metadata__1))],
        ['query'],
      ),
    'lock' : IDL.Func(
        [TokenId__1, IDL.Nat64, AccountId__1, SubAccount__1],
        [Return_7],
        [],
      ),
    'locks' : IDL.Func([], [IDL.Vec(IDL.Tuple(Index, Lock))], ['query']),
    'market_list' : IDL.Func([MarketListRequest], [Return_4], []),
    'market_listings' : IDL.Func(
        [],
        [IDL.Vec(IDL.Tuple(TokenIndex, Listing, Attributes, Metadata__1))],
        ['query'],
      ),
    'market_lock' : IDL.Func([MarketLockRequest], [Return_7], []),
    'metadata' : IDL.Func([TokenId__1], [Return_6], ['query']),
    'mint_nft' : IDL.Func([MintRequest], [IDL.Opt(Index)], []),
    'minter' : IDL.Func([], [IDL.Principal], ['query']),
    'mount' : IDL.Func([Path], [Return_5], []),
    'process_disbursements' : IDL.Func([], [], ['oneway']),
    'process_refunds' : IDL.Func([], [], ['oneway']),
    'report_balance' : IDL.Func([], [], ['oneway']),
    'reschedule' : IDL.Func([], [Return_5], []),
    'set_admins' : IDL.Func(
        [IDL.Vec(IDL.Principal)],
        [IDL.Vec(IDL.Principal)],
        [],
      ),
    'set_minter' : IDL.Func([IDL.Principal], [], []),
    'set_revealed' : IDL.Func([IDL.Bool], [], []),
    'settle' : IDL.Func([TokenId__1], [Return_4], []),
    'settle_all' : IDL.Func([], [], ['oneway']),
    'settlements' : IDL.Func(
        [],
        [IDL.Vec(IDL.Tuple(TokenIndex, AccountId__1, IDL.Nat64))],
        ['query'],
      ),
    'stats' : IDL.Func(
        [],
        [IDL.Nat64, IDL.Nat64, IDL.Nat64, IDL.Nat64, IDL.Nat, IDL.Nat, IDL.Nat],
        ['query'],
      ),
    'supply' : IDL.Func([TokenId__1], [Return_3], ['query']),
    'tokens' : IDL.Func([AccountId__1], [Return_2], ['query']),
    'tokens_ext' : IDL.Func([AccountId__1], [Return_1], ['query']),
    'transactions' : IDL.Func([], [IDL.Vec(Transaction)], ['query']),
    'transfer' : IDL.Func([TransferRequest], [Return], []),
    'transferBulk' : IDL.Func([BulkTransferRequest], [Return], []),
    'update_assets' : IDL.Func([IDL.Nat], [IDL.Opt(IDL.Nat)], []),
    'update_attributes' : IDL.Func([IDL.Vec(TokenAttributes)], [], []),
  });
  return NFT_Registry;
};
export const init = ({ IDL }) => { return []; };
