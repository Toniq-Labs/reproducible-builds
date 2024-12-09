export const idlFactory = ({ IDL }) => {
  const AccountIdentifier__1 = IDL.Text;
  const TokenIdentifier__1 = IDL.Text;
  const TokenState = IDL.Variant({
    'locked' : IDL.Null,
    'unlocked' : IDL.Null,
    'burned' : IDL.Null,
  });
  const AccountIdentifier__2 = IDL.Text;
  const User__1 = IDL.Variant({
    'principal' : IDL.Principal,
    'address' : AccountIdentifier__2,
  });
  const Balance__1 = IDL.Nat;
  const Memo__1 = IDL.Vec(IDL.Nat8);
  const SubAccount = IDL.Vec(IDL.Nat8);
  const TokenIdentifier = IDL.Text;
  const Category = IDL.Variant({
    'cat1' : IDL.Null,
    'cat2' : IDL.Null,
    'cat3' : IDL.Null,
    'cat4' : IDL.Null,
    'cat5' : IDL.Null,
  });
  const BurnRequest = IDL.Record({
    'subaccount' : IDL.Opt(SubAccount),
    'tokens' : IDL.Vec(TokenIdentifier),
    'category' : Category,
  });
  const AccountIdentifier = IDL.Text;
  const User = IDL.Variant({
    'principal' : IDL.Principal,
    'address' : AccountIdentifier,
  });
  const Memo = IDL.Vec(IDL.Nat8);
  const Balance = IDL.Nat;
  const BulkTransferRequest = IDL.Record({
    'to' : User,
    'notify' : IDL.Bool,
    'from' : User,
    'memo' : Memo,
    'subaccount' : IDL.Opt(SubAccount),
    'tokens' : IDL.Vec(TokenIdentifier),
    'amount' : Balance,
  });
  const Index__1 = IDL.Nat;
  const TransferResponse = IDL.Variant({
    'ok' : Balance,
    'err' : IDL.Variant({
      'CannotNotify' : AccountIdentifier,
      'InsufficientBalance' : IDL.Null,
      'InvalidToken' : TokenIdentifier,
      'Rejected' : IDL.Null,
      'Unauthorized' : AccountIdentifier,
      'Other' : IDL.Text,
    }),
  });
  const BurnInstruction = IDL.Record({
    'request' : BulkTransferRequest,
    'reference' : Index__1,
    'transfer' : IDL.Func([BulkTransferRequest], [TransferResponse], []),
  });
  const RequestStatus = IDL.Variant({
    'cancelled' : IDL.Null,
    'settled' : IDL.Null,
    'submitted' : IDL.Null,
    'busy' : IDL.Null,
    'refunded' : IDL.Null,
    'claimed' : IDL.Null,
  });
  const SharedRequest = IDL.Record({
    'status' : RequestStatus,
    'owner' : IDL.Principal,
    'subaccount' : IDL.Opt(SubAccount),
    'category' : Category,
    'candidates' : IDL.Vec(TokenIdentifier),
  });
  const Error = IDL.Variant({
    'BadCategory' : Category,
    'ProcessingRequest' : IDL.Null,
    'NotWhitelisted' : AccountIdentifier,
    'RequestCancelled' : IDL.Null,
    'AlreadySettled' : IDL.Null,
    'ActiveRequest' : SharedRequest,
    'TokenIsLocked' : TokenIdentifier,
    'InsufficientCredits' : IDL.Null,
    'UnknownState' : IDL.Null,
    'AlreadyClaimed' : IDL.Null,
    'NothingToRefund' : IDL.Null,
    'InvalidToken' : TokenIdentifier,
    'InsufficientTokens' : IDL.Nat,
    'Unauthorized' : AccountIdentifier,
    'AlreadyBurned' : TokenIdentifier,
    'AlreadyRefunded' : IDL.Null,
    'Other' : IDL.Text,
    'ConfigError' : IDL.Text,
    'DoesNotExist' : IDL.Null,
    'TransferFailed' : IDL.Null,
    'RefundFailed' : IDL.Null,
    'BeingProcessed' : IDL.Null,
    'ConditionsNotMet' : IDL.Null,
  });
  const Return_2 = IDL.Variant({ 'ok' : BurnInstruction, 'err' : Error });
  const Index = IDL.Nat;
  const Return = IDL.Variant({ 'ok' : IDL.Null, 'err' : Error });
  const ClaimRequest = IDL.Variant({ 'burn' : Index__1, 'drop' : SubAccount });
  const Return_1 = IDL.Variant({
    'ok' : IDL.Vec(TokenIdentifier__1),
    'err' : Error,
  });
  const TokenIndex = IDL.Nat32;
  const TokenIndex__1 = IDL.Nat32;
  const ServiceState__1 = IDL.Variant({
    'burn' : IDL.Null,
    'drop' : IDL.Null,
    'swap' : IDL.Null,
    'inactive' : IDL.Null,
  });
  const Configuration = IDL.Record({
    'snapshot' : IDL.Opt(IDL.Principal),
    'mapping' : IDL.Vec(IDL.Tuple(TokenIndex__1, TokenIndex__1)),
    'inventory' : IDL.Vec(IDL.Tuple(Category, IDL.Vec(TokenIndex__1))),
    'event' : ServiceState__1,
    'recipients' : IDL.Vec(
      IDL.Tuple(
        AccountIdentifier,
        IDL.Tuple(IDL.Nat, IDL.Nat, IDL.Nat, IDL.Nat, IDL.Nat),
      )
    ),
    'requirements' : IDL.Tuple(
      IDL.Opt(IDL.Nat),
      IDL.Opt(IDL.Nat),
      IDL.Opt(IDL.Nat),
      IDL.Opt(IDL.Nat),
      IDL.Opt(IDL.Nat),
    ),
    'registry' : IDL.Principal,
    'burn_registry' : IDL.Opt(IDL.Principal),
  });
  const StableCredits__1 = IDL.Tuple(
    IDL.Nat,
    IDL.Nat,
    IDL.Nat,
    IDL.Nat,
    IDL.Nat,
  );
  const Time = IDL.Int;
  const Event = IDL.Record({
    'memo' : IDL.Vec(IDL.Nat8),
    'claimed' : IDL.Vec(TokenIdentifier),
    'address' : AccountIdentifier,
    'timestamp' : Time,
    'burned' : IDL.Vec(TokenIdentifier),
  });
  const Category__1 = IDL.Variant({
    'cat1' : IDL.Null,
    'cat2' : IDL.Null,
    'cat3' : IDL.Null,
    'cat4' : IDL.Null,
    'cat5' : IDL.Null,
  });
  const ServiceState = IDL.Variant({
    'burn' : IDL.Null,
    'drop' : IDL.Null,
    'swap' : IDL.Null,
    'inactive' : IDL.Null,
  });
  const StableCredits = IDL.Tuple(IDL.Nat, IDL.Nat, IDL.Nat, IDL.Nat, IDL.Nat);
  const StableWhitelistEntry = IDL.Tuple(AccountIdentifier, StableCredits);
  const StableWhitelist = IDL.Vec(StableWhitelistEntry);
  const ExtSwap = IDL.Service({
    'add_admin' : IDL.Func([IDL.Principal], [], []),
    'admins' : IDL.Func([], [IDL.Vec(IDL.Principal)], ['query']),
    'aid' : IDL.Func([IDL.Principal], [AccountIdentifier__1], ['query']),
    'all_candidates' : IDL.Func(
        [],
        [IDL.Vec(IDL.Tuple(TokenIdentifier__1, TokenState))],
        ['query'],
      ),
    'bulkTokenTransferNotification' : IDL.Func(
        [IDL.Vec(TokenIdentifier__1), User__1, Balance__1, Memo__1],
        [IDL.Opt(Balance__1)],
        [],
      ),
    'burn' : IDL.Func([BurnRequest], [Return_2], []),
    'burn_registry' : IDL.Func([], [IDL.Principal], ['query']),
    'burn_tokenid' : IDL.Func([IDL.Nat32], [TokenIdentifier__1], ['query']),
    'burned' : IDL.Func([], [IDL.Nat], ['query']),
    'cancel' : IDL.Func([Index], [Return], []),
    'candidates' : IDL.Func([], [IDL.Vec(TokenIdentifier__1)], ['query']),
    'claim' : IDL.Func([ClaimRequest], [Return_1], []),
    'claim_registry' : IDL.Func([], [IDL.Principal], ['query']),
    'claimed' : IDL.Func(
        [IDL.Principal],
        [IDL.Vec(IDL.Tuple(TokenIndex, Index))],
        ['query'],
      ),
    'configure' : IDL.Func([Configuration], [Return], []),
    'credits' : IDL.Func(
        [AccountIdentifier__1],
        [IDL.Opt(StableCredits__1)],
        ['query'],
      ),
    'del_admin' : IDL.Func([IDL.Principal], [], []),
    'event_by_id' : IDL.Func([Index], [IDL.Opt(Event)], ['query']),
    'holdings' : IDL.Func(
        [],
        [IDL.Vec(IDL.Tuple(AccountIdentifier__1, IDL.Vec(TokenIndex)))],
        ['query'],
      ),
    'init' : IDL.Func([], [], []),
    'inventory' : IDL.Func(
        [],
        [IDL.Vec(IDL.Tuple(Category__1, IDL.Vec(TokenIdentifier__1)))],
        ['query'],
      ),
    'pulse' : IDL.Func([], [], ['oneway']),
    'rand_cache' : IDL.Func([], [IDL.Nat], ['query']),
    'rand_size' : IDL.Func([], [IDL.Nat], ['query']),
    'refund' : IDL.Func([Index], [Return], []),
    'reset' : IDL.Func([], [Return], []),
    'reset_test' : IDL.Func([], [], []),
    'self_aid' : IDL.Func([], [AccountIdentifier__1], ['query']),
    'service_state' : IDL.Func([], [ServiceState, IDL.Bool], ['query']),
    'set_admins' : IDL.Func([IDL.Vec(IDL.Principal)], [], []),
    'start' : IDL.Func([], [], []),
    'stop' : IDL.Func([], [], []),
    'tid' : IDL.Func(
        [IDL.Principal, IDL.Nat32],
        [TokenIdentifier__1],
        ['query'],
      ),
    'user_events' : IDL.Func(
        [AccountIdentifier__1],
        [IDL.Vec(Event)],
        ['query'],
      ),
    'whitelist' : IDL.Func([], [StableWhitelist], ['query']),
  });
  return ExtSwap;
};
export const init = ({ IDL }) => { return []; };
