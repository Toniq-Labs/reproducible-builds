export const idlFactory = ({ IDL }) => {
  const StreamingToken = IDL.Rec();
  const AccountId__1 = IDL.Text;
  const Index = IDL.Nat;
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
  const CommonError = IDL.Variant({
    'InvalidToken' : TokenIdentifier,
    'Other' : IDL.Text,
  });
  const Return_12 = IDL.Variant({ 'ok' : IDL.Vec(Index), 'err' : CommonError });
  const User = IDL.Variant({
    'principal' : IDL.Principal,
    'address' : AccountIdentifier,
  });
  const BalanceRequest = IDL.Record({
    'token' : TokenIdentifier,
    'user' : User,
  });
  const Return_11 = IDL.Variant({ 'ok' : IDL.Nat, 'err' : CommonError });
  const TokenId__1 = IDL.Text;
  const Return_8 = IDL.Variant({ 'ok' : AccountId__1, 'err' : CommonError });
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
  const Stream = IDL.Record({
    'ftype' : IDL.Text,
    'name' : IDL.Text,
    'pointer' : IDL.Record({
      'token' : StreamingToken,
      'callback' : StreamingCallback,
    }),
  });
  const Value = IDL.Variant({
    'url' : IDL.Text,
    'stream' : Stream,
    'blob' : IDL.Vec(IDL.Nat8),
    'none' : IDL.Null,
  });
  const Time = IDL.Int;
  const Fee = IDL.Nat64;
  const Listing = IDL.Record({
    'locked' : IDL.Opt(Time),
    'seller' : IDL.Principal,
    'allowance' : Fee,
    'price' : IDL.Nat64,
    'royalty' : Fee,
  });
  const Return_10 = IDL.Variant({
    'ok' : IDL.Tuple(AccountId__1, IDL.Opt(Listing)),
    'err' : CommonError,
  });
  const MimeType = IDL.Text;
  const Priv = IDL.Variant({
    'NO' : IDL.Null,
    'RO' : IDL.Null,
    'RW' : IDL.Null,
    'WO' : IDL.Null,
  });
  const Mode = IDL.Tuple(Priv, Priv);
  const Handle = IDL.Text;
  const Bytes = IDL.Nat;
  const Time__3 = IDL.Int;
  const File = IDL.Record({
    'ftype' : MimeType,
    'owner' : IDL.Principal,
    'mode' : Mode,
    'name' : Handle,
    'size' : Bytes,
    'pointer' : IDL.Record({
      'token' : StreamingToken,
      'callback' : StreamingCallback,
    }),
    'group' : IDL.Vec(IDL.Principal),
    'timestamp' : Time__3,
  });
  const Index__2 = IDL.Nat;
  const DState = IDL.Variant({ 'Hidden' : IDL.Null, 'Valid' : IDL.Null });
  const Dentry = IDL.Tuple(Index__2, Index__2, Handle, DState);
  const Directory = IDL.Record({
    'contents' : IDL.Vec(Dentry),
    'owner' : IDL.Principal,
    'mode' : Mode,
    'name' : Handle,
    'group' : IDL.Vec(IDL.Principal),
    'inode' : Index__2,
    'parent' : Index__2,
  });
  const Inode = IDL.Variant({
    'Reserved' : IDL.Principal,
    'File' : File,
    'Directory' : Directory,
  });
  const Mount = IDL.Vec(Inode);
  const Path__1 = IDL.Text;
  const Error__1 = IDL.Variant({
    'NotFile' : Path__1,
    'Invalid' : Path__1,
    'IncompatibleInode' : IDL.Null,
    'Busy' : IDL.Null,
    'TryAgain' : IDL.Null,
    'NotPermitted' : IDL.Null,
    'NotFound' : Path__1,
    'Unauthorized' : IDL.Null,
    'AlreadyExists' : Path__1,
    'EmptyPath' : Path__1,
    'FailedInit' : IDL.Text,
    'NotDirectory' : Path__1,
    'Corrupted' : IDL.Null,
    'FatalFault' : IDL.Null,
    'ServiceLimit' : IDL.Null,
  });
  const Return_9 = IDL.Variant({ 'ok' : Mount, 'err' : Error__1 });
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
  const Return_6 = IDL.Variant({ 'ok' : IDL.Null, 'err' : Error });
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
  const Return_7 = IDL.Variant({ 'ok' : Metadata, 'err' : CommonError });
  const Path = IDL.Text;
  const MintRequest = IDL.Record({ 'path' : Path, 'receiver' : IDL.Principal });
  const Return_5 = IDL.Variant({ 'ok' : IDL.Null, 'err' : IDL.Text });
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
  const Keyword = IDL.Variant({ 'wild' : IDL.Null, 'word' : IDL.Text });
  const TokenAttributes = IDL.Record({
    'attributes' : IDL.Opt(IDL.Vec(IDL.Nat8)),
    'index' : Index,
  });
  const NFT_Registry = IDL.Service({
    'acceptCycles' : IDL.Func([], [], []),
    'add_affiliate' : IDL.Func([AccountId__1], [], []),
    'admin_query_settlement' : IDL.Func(
        [Index],
        [IDL.Opt(StableLock)],
        ['query'],
      ),
    'admins' : IDL.Func([], [IDL.Vec(IDL.Principal)], ['query']),
    'affiliates' : IDL.Func([], [IDL.Vec(AccountId__1)], ['query']),
    'allSettlements' : IDL.Func(
        [],
        [IDL.Vec(IDL.Tuple(TokenIndex, Settlement))],
        ['query'],
      ),
    'areTokensLocked' : IDL.Func([IDL.Vec(Index)], [Return_12], ['query']),
    'balance' : IDL.Func([BalanceRequest], [Return_11], ['query']),
    'bearer' : IDL.Func([TokenId__1], [Return_8], ['query']),
    'check_listing' : IDL.Func([], [IDL.Bool], []),
    'check_metadata' : IDL.Func([Index, IDL.Text], [Value], ['query']),
    'details' : IDL.Func([TokenId__1], [Return_10], ['query']),
    'export_filesystem' : IDL.Func([], [Return_9], ['query']),
    'extensions' : IDL.Func([], [IDL.Vec(Extension)], ['query']),
    'fees' : IDL.Func([], [IDL.Nat64, IDL.Nat64, IDL.Nat64], ['query']),
    'fileshareId' : IDL.Func([], [IDL.Principal], ['query']),
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
    'get_royalty_address' : IDL.Func([], [AccountId__1], []),
    'heartbeat_disable' : IDL.Func([], [], []),
    'heartbeat_enable' : IDL.Func([], [], []),
    'heartbeat_external' : IDL.Func([], [], []),
    'heartbeat_pending' : IDL.Func(
        [],
        [IDL.Vec(IDL.Tuple(IDL.Text, IDL.Nat))],
        ['query'],
      ),
    'heartbeat_start' : IDL.Func([], [], []),
    'heartbeat_stop' : IDL.Func([], [], []),
    'http_request' : IDL.Func([Request], [Response], ['query']),
    'init' : IDL.Func([InitConfig], [Return_6], []),
    'isHeartbeatRunning' : IDL.Func([], [IDL.Bool], ['query']),
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
        [Return_8],
        [],
      ),
    'locks' : IDL.Func([], [IDL.Vec(IDL.Tuple(Index, Lock))], ['query']),
    'market_list' : IDL.Func([MarketListRequest], [Return_4], []),
    'market_listings' : IDL.Func(
        [],
        [IDL.Vec(IDL.Tuple(TokenIndex, Listing, Attributes, Metadata__1))],
        ['query'],
      ),
    'market_lock' : IDL.Func([MarketLockRequest], [Return_8], []),
    'metadata' : IDL.Func([TokenId__1], [Return_7], ['query']),
    'mint_nft' : IDL.Func([MintRequest], [IDL.Opt(Index)], []),
    'minter' : IDL.Func([], [IDL.Principal], ['query']),
    'mount' : IDL.Func([Path], [Return_6], []),
    'process_disbursements' : IDL.Func([], [], ['oneway']),
    'process_refunds' : IDL.Func([], [], ['oneway']),
    'report_balance' : IDL.Func([], [], ['oneway']),
    'reschedule' : IDL.Func([], [Return_6], []),
    'set_admins' : IDL.Func(
        [IDL.Vec(IDL.Principal)],
        [IDL.Vec(IDL.Principal)],
        [],
      ),
    'set_fees' : IDL.Func([IDL.Tuple(IDL.Nat64, IDL.Nat64, IDL.Nat64)], [], []),
    'set_minter' : IDL.Func([IDL.Principal], [], []),
    'set_revealed' : IDL.Func([IDL.Bool], [], []),
    'set_royalty_address' : IDL.Func([AccountId__1], [Return_5], []),
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
    'update_assets' : IDL.Func(
        [IDL.Tuple(IDL.Nat, IDL.Nat), Keyword],
        [IDL.Opt(IDL.Nat)],
        [],
      ),
    'update_attributes' : IDL.Func([IDL.Vec(TokenAttributes)], [], []),
  });
  return NFT_Registry;
};
export const init = ({ IDL }) => { return []; };
