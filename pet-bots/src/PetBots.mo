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

actor class Canister() = this {

  // Types
  type Time = Time.Time;
  type AccountIdentifier = ExtCore.AccountIdentifier;
  type SubAccount = ExtCore.SubAccount;
  type User = ExtCore.User;
  type Balance = ExtCore.Balance;
  type TokenIdentifier = ExtCore.TokenIdentifier;
  type TokenIndex = ExtCore.TokenIndex;
  type Extension = ExtCore.Extension;
  type CommonError = ExtCore.CommonError;
  type BalanceRequest = ExtCore.BalanceRequest;
  type BalanceResponse = ExtCore.BalanceResponse;
  type TransferRequest = ExtCore.TransferRequest;
  type TransferResponse = ExtCore.TransferResponse;
  type AllowanceRequest = ExtAllowance.AllowanceRequest;
  type ApproveRequest = ExtAllowance.ApproveRequest;
  type Metadata = ExtCommon.Metadata;
  type NotifyService = ExtCore.NotifyService;
  type MintingRequest = {
    to : AccountIdentifier;
    asset : Nat32;
  };

  //Marketplace
  type Transaction = {
    token : TokenIdentifier;
    seller : Principal;
    price : Nat64;
    buyer : AccountIdentifier;
    time : Time;
  };
  type Settlement = {
    seller : Principal;
    price : Nat64;
    subaccount : SubAccount;
    buyer : AccountIdentifier;
  };
  type Listing = {
    seller : Principal;
    price : Nat64;
    locked : ?Time;
  };
  type ListRequest = {
    token : TokenIdentifier;
    from_subaccount : ?SubAccount;
    price : ?Nat64;
  };
  type AccountBalanceArgs = { account : AccountIdentifier };
  type ICPTs = { e8s : Nat64 };
  type SendArgs = {
    memo : Nat64;
    amount : ICPTs;
    fee : ICPTs;
    from_subaccount : ?SubAccount;
    to : AccountIdentifier;
    created_at_time : ?Time;
  };
  type File = {
    ctype : Text; //"image/jpeg"
    data : [Blob];
  };
  type Asset = {
    name : Text;
    thumbnail : ?File;
    payload : File;
  };
  type UpdateRequest = {
    assetID : Nat;
    payload : File;
  };

  let LEDGER_CANISTER = actor "ryjl3-tyaaa-aaaaa-aaaba-cai" : actor {
    send_dfx : shared SendArgs -> async Nat64;
    account_balance_dfx : shared query AccountBalanceArgs -> async ICPTs;
  };

  //Cap
  type CapDetailValue = {
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
  type CapEvent = {
    time : Nat64;
    operation : Text;
    details : [(Text, CapDetailValue)];
    caller : Principal;
  };
  type CapIndefiniteEvent = {
    operation : Text;
    details : [(Text, CapDetailValue)];
    caller : Principal;
  };

  private let EXTENSIONS : [Extension] = ["@ext/common", "@ext/nonfungible"];

  //State work
  private stable var _registryState : [(TokenIndex, AccountIdentifier)] = [];
  private stable var _tokenMetadataState : [(TokenIndex, Metadata)] = [];
  private stable var _ownersState : [(AccountIdentifier, [TokenIndex])] = [];

  private stable var _hbsvc : Principal = Principal.fromText("aaaaa-aa");

  private stable var _HB_ : Bool = false;
  private stable var _INIT_ : Bool = false;

  //Log State
  private stable var _pushLog : Bool = false;
  private stable var _log_level : Nat8 = 0;
  private stable let _max_log_level : Nat8 = 7;
  private stable let level_0 : Nat8 = 0;
  private stable let level_1 : Nat8 = 1;
  private stable let level_2 : Nat8 = 2;
  private stable let level_3 : Nat8 = 4;

  //For marketplace
  private stable var _tokenListingState : [(TokenIndex, Listing)] = [];
  private stable var _tokenSettlementState : [(TokenIndex, Settlement)] = [];
  private stable var _paymentsState : [(Principal, [SubAccount])] = [];
  private stable var _refundsState : [(Principal, [SubAccount])] = [];
  private stable var _transactionState : [Transaction] = [];

  private var _registry : TrieMap.TrieMap<TokenIndex, AccountIdentifier> = TrieMap.fromEntries(_registryState.vals(), ExtCore.TokenIndex.equal, ExtCore.TokenIndex.hash);
  private var _tokenMetadata : TrieMap.TrieMap<TokenIndex, Metadata> = TrieMap.fromEntries(_tokenMetadataState.vals(), ExtCore.TokenIndex.equal, ExtCore.TokenIndex.hash);
  private var _owners : TrieMap.TrieMap<AccountIdentifier, [TokenIndex]> = TrieMap.fromEntries(_ownersState.vals(), AID.equal, AID.hash);

  //For marketplace
  private var _transactionBuffer = Buffer.Buffer<Transaction>(0);
  private var _tokenListing : TrieMap.TrieMap<TokenIndex, Listing> = TrieMap.fromEntries(_tokenListingState.vals(), ExtCore.TokenIndex.equal, ExtCore.TokenIndex.hash);
  private var _tokenSettlement : TrieMap.TrieMap<TokenIndex, Settlement> = TrieMap.fromEntries(_tokenSettlementState.vals(), ExtCore.TokenIndex.equal, ExtCore.TokenIndex.hash);
  private var _payments : TrieMap.TrieMap<Principal, [SubAccount]> = TrieMap.fromEntries(_paymentsState.vals(), Principal.equal, Principal.hash);
  private var _refunds : TrieMap.TrieMap<Principal, [SubAccount]> = TrieMap.fromEntries(_refundsState.vals(), Principal.equal, Principal.hash);
  private var ESCROWDELAY : Time = 2 * 60 * 1_000_000_000;
  private stable var _usedPaymentAddressess : [(AccountIdentifier, Principal, SubAccount)] = [];
  private stable var _transactions : [Transaction] = [];
  private stable var _supply : Balance = 0;
  private stable var _minter : Principal = Principal.fromText("yna3j-sjqp7-a444w-muwct-udocp-rw7yh-iuofd-ua7jp-hhupo-fv5xl-7ae");
  private stable var _nextTokenId : TokenIndex = 0;
  private stable var _assets : [Asset] = [];
  //_assets := [];

  //EXTv2 SALE
  private stable var _disbursementsState : [(TokenIndex, AccountIdentifier, SubAccount, Nat64)] = [];
  private stable var _nextSubAccount : Nat = 0;
  private var _disbursements : List.List<(TokenIndex, AccountIdentifier, SubAccount, Nat64)> = List.fromArray(_disbursementsState);
  private var salesFees : [(AccountIdentifier, Nat64)] = [
    ("07ed96a84229a40439a68054bf8d6ac4e9fb472ea6c01520cb46a68eb2faf6f4", 5000), //Royalty Fee 5% PokedStudio
    ("c7e461041c0c5800a56b64bb7cefc247abc0bbbb99bd46ff71c64e92d9f5c2f9", 1000), //Entrepot Fee 1%
  ];

  //CAP
  private stable var capRootBucketId : ?Text = null;
  let CapService = Cap.Cap(?"lj532-6iaaa-aaaah-qcc7a-cai", capRootBucketId);
  private stable var _capEventsState : [CapIndefiniteEvent] = [];
  private var _capEvents : List.List<CapIndefiniteEvent> = List.fromArray(_capEventsState);
  private stable var _runHeartbeat : Bool = true;

  //CanisterGeek
  private stable var _canistergeekLoggerUD : ?Canistergeek.LoggerUpgradeData = null;
  private stable var _canistergeekMonitorUD : ?Canistergeek.UpgradeData = null;
  private let canistergeekLogger = Canistergeek.Logger();
  private let canistergeekMonitor = Canistergeek.Monitor();

  //UpgradeToggle
  private let toggle : Nat8 = 1;

  private var _lastbeat : Int = 0;
  public shared query func lastbeat() : async Int { _lastbeat };

  public shared ({ caller }) func stopHeartbeat() : async () {};
  public shared ({ caller }) func startHeartbeat() : async () {};

  public shared ({ caller }) func pulse() : () {

  };

  public shared ({ caller }) func report_balance() : () {

  };

  public shared ({ caller }) func reschedule(hb : ?Text) : async Result.Result<(), CommonError> {
    return #ok();
  };

  //State functions
  system func preupgrade() {
    _registryState := Iter.toArray(_registry.entries());
    _tokenMetadataState := Iter.toArray(_tokenMetadata.entries());
    _ownersState := Iter.toArray(_owners.entries());
    _tokenListingState := Iter.toArray(_tokenListing.entries());
    _tokenSettlementState := Iter.toArray(_tokenSettlement.entries());
    _paymentsState := Iter.toArray(_payments.entries());
    _refundsState := Iter.toArray(_refunds.entries());
    _transactionState := _transactionBuffer.toArray();

    //EXTv2 SALE
    _disbursementsState := List.toArray(_disbursements);

    //Cap
    _capEventsState := List.toArray(_capEvents);

    //CanisterGeek
    _canistergeekLoggerUD := ?canistergeekLogger.preupgrade();
    _canistergeekMonitorUD := ?canistergeekMonitor.preupgrade();
  };
  system func postupgrade() {
    for (x in _transactionState.vals()) {
      _transactionBuffer.add(x);
    };
    _transactionState := [];
    _transactions := [];
    _registryState := [];
    _tokenMetadataState := [];
    _ownersState := [];
    _tokenListingState := [];
    _tokenSettlementState := [];
    _paymentsState := [];
    _refundsState := [];

    //EXTv2 SALE
    _disbursementsState := [];

    //Cap
    _capEventsState := [];

    //CanisterGeek
    canistergeekLogger.postupgrade(_canistergeekLoggerUD);
    canistergeekMonitor.postupgrade(_canistergeekMonitorUD);
    _canistergeekLoggerUD := null;
    _canistergeekMonitorUD := null;
    canistergeekLogger.setMaxMessagesCount(3000);
    logEvent(level_0, "postupgrade");
  };

  //LOGGING ON/OFF
  public shared (msg) func setLogLevel(level : Nat8) : async () {
    assert (msg.caller == _minter);
    if (Nat8.lessOrEqual(level, _max_log_level)) {
      _log_level := level;
    };
  };
  private func logEvent(level : Nat8, message : Text) : () {
    if (Nat8.equal(Nat8.bitand(_log_level, level), level)) {
      canistergeekLogger.logMessage(message);
    };
  };

  //EXTv2 SALE
  private var _delayHeartbeat : Nat32 = 0;
  // system func heartbeat() : async () {
  //   if (Nat32.less(_delayHeartbeat, 8)) {
  //     _delayHeartbeat += 1;
  //   } else {
  //     _delayHeartbeat := 0;
  //     if (_runHeartbeat == true) {
  //       await cronDisbursements();
  //       await cronSettlements();
  //       await cronCapEvents();
  //     };
  //   };
  // };

  public shared (msg) func heartbeat_external() : async () {
    if (_runHeartbeat == true) {
      try {
        await cronDisbursements();
        await cronSettlements();
        await cronCapEvents();
      } catch (e) {
        _runHeartbeat := false;
      };
    };
  };

  public query func isHeartbeatRunning() : async Bool {
    _runHeartbeat;
  };

  public query func heartbeat_pending() : async [(Text, Nat)] {
    [
      ("Disbursements", List.size(_disbursements)),
      ("CAP Events", List.size(_capEvents)),
      //  ("Expired Payment Settlements",  unlockedSettlements().size())
    ];
  };

  public query func get_transaction_count() : async Nat {
    Iter.size(_transactionBuffer.vals());
  };

  //Listings
  //EXTv2 SALE
  func _natToSubAccount(n : Nat) : SubAccount {
    let n_byte = func(i : Nat) : Nat8 {
      assert (i < 32);
      let shift : Nat = 8 * (32 - 1 - i);
      Nat8.fromIntWrap(n / 2 ** shift);
    };
    Array.tabulate<Nat8>(32, n_byte);
  };
  func _getNextSubAccount() : SubAccount {
    var _saOffset = 4294967296;
    _nextSubAccount += 1;
    return _natToSubAccount(_saOffset + _nextSubAccount);
  };
  func _addDisbursement(d : (TokenIndex, AccountIdentifier, SubAccount, Nat64)) : () {
    _disbursements := List.push(d, _disbursements);
  };
  public shared (msg) func lock(tokenid : TokenIdentifier, price : Nat64, address : AccountIdentifier, _subaccountNOTUSED : SubAccount) : async Result.Result<AccountIdentifier, CommonError> {
    canistergeekMonitor.collectMetrics();
    logEvent(level_1, "lock");
    if (ExtCore.TokenIdentifier.isPrincipal(tokenid, Principal.fromActor(this)) == false) {
      return #err(#InvalidToken(tokenid));
    };
    let token = ExtCore.TokenIdentifier.getIndex(tokenid);
    if (_isLocked(token)) {
      return #err(#Other("Listing is locked"));
    };
    let subaccount = _getNextSubAccount();
    switch (_tokenListing.get(token)) {
      case (?listing) {
        if (listing.price != price) {
          return #err(#Other("Price has changed!"));
        } else {
          let paymentAddress : AccountIdentifier = AID.fromPrincipal(Principal.fromActor(this), ?subaccount);
          _tokenListing.put(
            token,
            {
              seller = listing.seller;
              price = listing.price;
              locked = ?(Time.now() + ESCROWDELAY);
            },
          );
          switch (_tokenSettlement.get(token)) {
            case (?settlement) {
              let resp : Result.Result<(), CommonError> = await settle(tokenid);
              logEvent(level_2, "settle : lock()");
              switch (resp) {
                case (#ok) {
                  return #err(#Other("Listing has sold"));
                };
                case (#err _) {
                  //Atomic protection
                  if (Option.isNull(_tokenListing.get(token))) return #err(#Other("Listing has sold"));
                };
              };
            };
            case (_) {};
          };
          _tokenSettlement.put(
            token,
            {
              seller = listing.seller;
              price = listing.price;
              subaccount = subaccount;
              buyer = address;
            },
          );
          return #ok(paymentAddress);
        };
      };
      case (_) {
        return #err(#Other("No listing!"));
      };
    };
  };
  public shared (msg) func settle(tokenid : TokenIdentifier) : async Result.Result<(), CommonError> {
    canistergeekMonitor.collectMetrics();
    logEvent(level_1, "settle()");
    if (ExtCore.TokenIdentifier.isPrincipal(tokenid, Principal.fromActor(this)) == false) {
      return #err(#InvalidToken(tokenid));
    };
    let token = ExtCore.TokenIdentifier.getIndex(tokenid);
    switch (_tokenSettlement.get(token)) {
      case (?settlement) {
        let response : ICPTs = await LEDGER_CANISTER.account_balance_dfx({
          account = AID.fromPrincipal(Principal.fromActor(this), ?settlement.subaccount);
        });
        switch (_tokenSettlement.get(token)) {
          case (?settlement) {
            if (response.e8s >= settlement.price) {
              switch (_registry.get(token)) {
                case (?token_owner) {
                  var bal : Nat64 = settlement.price - (10000 * Nat64.fromNat(salesFees.size() + 1));
                  var rem = bal;
                  for (f in salesFees.vals()) {
                    var _fee : Nat64 = bal * f.1 / 100000;
                    _addDisbursement((token, f.0, settlement.subaccount, _fee));
                    rem := rem - _fee : Nat64;
                  };
                  _addDisbursement((token, token_owner, settlement.subaccount, rem));
                  _capAddSale(token, token_owner, settlement.buyer, settlement.price);
                  _transferTokenToUser(token, settlement.buyer);
                  _transactionBuffer.add({
                    token : TokenIdentifier = tokenid;
                    seller = settlement.seller;
                    price = settlement.price;
                    buyer = settlement.buyer;
                    time : Time = Time.now();
                  });
                  _tokenListing.delete(token);
                  _tokenSettlement.delete(token);
                  return #ok();
                };
                case (_) {
                  return #err(#InvalidToken(tokenid));
                };
              };
            } else {
              if (_isLocked(token)) {
                return #err(#Other("Insufficient funds sent"));
              } else {
                _tokenSettlement.delete(token);
                return #err(#Other("Nothing to settle"));
              };
            };
          };
          case (_) return #err(#Other("Nothing to settle"));
        };
      };
      case (_) return #err(#Other("Nothing to settle"));
    };
  };
  public shared (msg) func list(request : ListRequest) : async Result.Result<(), CommonError> {
    canistergeekMonitor.collectMetrics();
    logEvent(level_1, "list()");
    if (ExtCore.TokenIdentifier.isPrincipal(request.token, Principal.fromActor(this)) == false) {
      return #err(#InvalidToken(request.token));
    };
    let token = ExtCore.TokenIdentifier.getIndex(request.token);
    if (_isLocked(token)) {
      return #err(#Other("Listing is locked"));
    };
    switch (_tokenSettlement.get(token)) {
      case (?settlement) {
        let resp : Result.Result<(), CommonError> = await settle(request.token);
        logEvent(level_2, "settle : list()");
        switch (resp) {
          case (#ok) return #err(#Other("Listing has sold"));
          case (#err _) {};
        };
      };
      case (_) {};
    };
    let owner = AID.fromPrincipal(msg.caller, request.from_subaccount);
    switch (_registry.get(token)) {
      case (?token_owner) {
        if (AID.equal(owner, token_owner) == false) {
          return #err(#Other("Not authorized"));
        };
        switch (request.price) {
          case (?price) {
            _tokenListing.put(
              token,
              {
                seller = msg.caller;
                price = price;
                locked = null;
              },
            );
          };
          case (_) {
            _tokenListing.delete(token);
          };
        };
        if (Option.isSome(_tokenSettlement.get(token))) {
          _tokenSettlement.delete(token);
        };
        return #ok;
      };
      case (_) {
        return #err(#InvalidToken(request.token));
      };
    };
  };
  public shared (msg) func cronDisbursements() : async () {
    canistergeekMonitor.collectMetrics();
    logEvent(level_3, "cronDisbursements");
    var _cont : Bool = true;
    while (_cont) {
      var last = List.pop(_disbursements);
      switch (last.0) {
        case (?d) {
          _disbursements := last.1;
          try {
            var bh = await LEDGER_CANISTER.send_dfx({
              memo = Encoding.BigEndian.toNat64(Blob.toArray(Principal.toBlob(Principal.fromText(ExtCore.TokenIdentifier.fromPrincipal(Principal.fromActor(this), d.0)))));
              amount = { e8s = d.3 };
              fee = { e8s = 10000 };
              from_subaccount = ?d.2;
              to = d.1;
              created_at_time = null;
            });
            logEvent(level_2, "send_dfx-SUCCESS : cronDisbursements()");
          } catch (e) {
            _disbursements := List.push(d, _disbursements);
            logEvent(level_2, "send_dfx-FAILED : cronDisbursements()");
          };
        };
        case (_) {
          _cont := false;
        };
      };
    };
  };
  public shared (msg) func cronSettlements() : async () {
    canistergeekMonitor.collectMetrics();
    logEvent(level_3, "cronSettlements");
    for (settlement in _tokenSettlement.entries()) {
      ignore (settle(ExtCore.TokenIdentifier.fromPrincipal(Principal.fromActor(this), settlement.0)));
      logEvent(level_2, "settle : cronSettlements()");
    };
  };

  //Cap
  func _capAddTransfer(token : TokenIndex, from : AccountIdentifier, to : AccountIdentifier) : () {
    let event : CapIndefiniteEvent = {
      operation = "transfer";
      details = [
        ("to", #Text(to)),
        ("from", #Text(from)),
        ("token", #Text(ExtCore.TokenIdentifier.fromPrincipal(Principal.fromActor(this), token))),
        ("balance", #U64(1)),
      ];
      caller = Principal.fromActor(this);
    };
    _capAdd(event);
  };
  func _capAddSale(token : TokenIndex, from : AccountIdentifier, to : AccountIdentifier, amount : Nat64) : () {
    let event : CapIndefiniteEvent = {
      operation = "sale";
      details = [
        ("to", #Text(to)),
        ("from", #Text(from)),
        ("token", #Text(ExtCore.TokenIdentifier.fromPrincipal(Principal.fromActor(this), token))),
        ("balance", #U64(1)),
        ("price_decimals", #U64(8)),
        ("price_currency", #Text("ICP")),
        ("price", #U64(amount)),
      ];
      caller = Principal.fromActor(this);
    };
    _capAdd(event);
  };
  func _capAddMint(token : TokenIndex, from : AccountIdentifier, to : AccountIdentifier, amount : ?Nat64) : () {
    let event : CapIndefiniteEvent = switch (amount) {
      case (?a) {
        {
          operation = "mint";
          details = [
            ("to", #Text(to)),
            ("from", #Text(from)),
            ("token", #Text(ExtCore.TokenIdentifier.fromPrincipal(Principal.fromActor(this), token))),
            ("balance", #U64(1)),
            ("price_decimals", #U64(8)),
            ("price_currency", #Text("ICP")),
            ("price", #U64(a)),
          ];
          caller = Principal.fromActor(this);
        };
      };
      case (_) {
        {
          operation = "mint";
          details = [
            ("to", #Text(to)),
            ("from", #Text(from)),
            ("token", #Text(ExtCore.TokenIdentifier.fromPrincipal(Principal.fromActor(this), token))),
            ("balance", #U64(1)),
          ];
          caller = Principal.fromActor(this);
        };
      };
    };
    _capAdd(event);
  };
  func _capAdd(event : CapIndefiniteEvent) : () {
    _capEvents := List.push(event, _capEvents);
  };
  public shared (msg) func cronCapEvents() : async () {
    canistergeekMonitor.collectMetrics();
    logEvent(level_3, "cronCapEvents()");
    var _cont : Bool = true;
    while (_cont) {
      var last = List.pop(_capEvents);
      switch (last.0) {
        case (?event) {
          _capEvents := last.1;
          try {
            ignore await CapService.insert(event);
          } catch (e) {
            _capEvents := List.push(event, _capEvents);
            logEvent(level_2, "CapService Error : cronCapEvents()");
          };
        };
        case (_) {
          _cont := false;
        };
      };
    };
  };
  public shared (msg) func initCap() : async () {
    canistergeekMonitor.collectMetrics();
    logEvent(level_1, "initCap()");
    if (Option.isNull(capRootBucketId)) {
      try {
        capRootBucketId := await CapService.handshake(Principal.toText(Principal.fromActor(this)), 1_000_000_000_000);
      } catch e {};
    };
  };

  // CanisterGeek - MONITORING & LOGGING
  private let geekPrincipal : Text = "awmdx-onrpv-kzwjt-jggtq-t3idz-sbrq2-72c6r-7ajlg-5txoj-4ifwe-dqe"; // LL
  public query ({ caller }) func getCanisterMetrics(parameters : Canistergeek.GetMetricsParameters) : async ?Canistergeek.CanisterMetrics {
    validateCaller(caller);
    canistergeekMonitor.getMetrics(parameters);
  };
  public shared ({ caller }) func collectCanisterMetrics() : async () {
    validateCaller(caller);
    canistergeekMonitor.collectMetrics();
  };
  public query ({ caller }) func getCanisterLog(request : ?Canistergeek.CanisterLogRequest) : async ?Canistergeek.CanisterLogResponse {
    validateCaller(caller);
    canistergeekLogger.getLog(request);
  };
  private func validateCaller(principal : Principal) : () {
    if (not (Principal.toText(principal) == geekPrincipal)) {
      Prelude.unreachable();
    };
  };

  private stable var historicExportHasRun : Bool = false;
  public shared (msg) func historicExport() : async Bool {
    canistergeekMonitor.collectMetrics();
    logEvent(level_1, "historicExport()");
    if (historicExportHasRun == false) {
      var events : [CapEvent] = [];
      for (tx in _transactionBuffer.vals()) {
        let event : CapEvent = {
          time = Int64.toNat64(Int64.fromInt(tx.time));
          operation = "sale";
          details = [
            ("to", #Text(tx.buyer)),
            ("from", #Text(Principal.toText(tx.seller))),
            ("token", #Text(tx.token)),
            ("balance", #U64(1)),
            ("price_decimals", #U64(8)),
            ("price_currency", #Text("ICP")),
            ("price", #U64(tx.price)),
          ];
          caller = Principal.fromActor(this);
        };
        events := Array.append(events, [event]);
      };
      try {
        ignore (await CapService.migrate(events));
        historicExportHasRun := true;
      } catch (e) {};
    };
    historicExportHasRun;
  };
  public shared (msg) func adminKillHeartbeat() : async () {
    canistergeekMonitor.collectMetrics();
    logEvent(level_1, "adminKillHeartbeat");
    assert (msg.caller == _minter);
    _runHeartbeat := false;
  };
  public shared (msg) func adminStartHeartbeat() : async () {
    canistergeekMonitor.collectMetrics();
    logEvent(level_1, "adminStarHeartbeat");
    assert (msg.caller == _minter);
    _runHeartbeat := true;
  };

  public shared (msg) func heartbeat_start() : async () {
    assert (msg.caller == Principal.fromText("yna3j-sjqp7-a444w-muwct-udocp-rw7yh-iuofd-ua7jp-hhupo-fv5xl-7ae"));
    _runHeartbeat := true;
  };

  public shared (msg) func heartbeat_stop() : async () {
    assert (msg.caller == Principal.fromText("yna3j-sjqp7-a444w-muwct-udocp-rw7yh-iuofd-ua7jp-hhupo-fv5xl-7ae"));
    _runHeartbeat := false;
  };

  public shared (msg) func setMinter(minter : Principal) : async () {
    canistergeekMonitor.collectMetrics();
    logEvent(level_1, "setMinter");
    assert (msg.caller == _minter);
    _minter := minter;
  };
  public shared (msg) func streamAsset(id : Nat, isThumb : Bool, payload : Blob) : async () {
    canistergeekMonitor.collectMetrics();
    logEvent(level_1, "streamAsset");
    assert (msg.caller == _minter);
    var tassets : [var Asset] = Array.thaw<Asset>(_assets);
    var asset : Asset = tassets[id];
    if (isThumb) {
      switch (asset.thumbnail) {
        case (?t) {
          asset := {
            name = asset.name;
            thumbnail = ?{
              ctype = t.ctype;
              data = Array.append(t.data, [payload]);
            };
            payload = asset.payload;
          };
        };
        case (_) {};
      };
    } else {
      asset := {
        name = asset.name;
        thumbnail = asset.thumbnail;
        payload = {
          ctype = asset.payload.ctype;
          data = Array.append(asset.payload.data, [payload]);
        };
      };
    };
    tassets[id] := asset;
    _assets := Array.freeze(tassets);
  };
  public shared (msg) func updateThumb(name : Text, file : File) : async ?Nat {
    canistergeekMonitor.collectMetrics();
    logEvent(level_1, "updateThumb()");
    assert (msg.caller == _minter);
    var i : Nat = 0;
    for (a in _assets.vals()) {
      if (a.name == name) {
        var tassets : [var Asset] = Array.thaw<Asset>(_assets);
        var asset : Asset = tassets[i];
        asset := {
          name = asset.name;
          thumbnail = ?file;
          payload = asset.payload;
        };
        tassets[i] := asset;
        _assets := Array.freeze(tassets);
        return ?i;
      };
      i += 1;
    };
    return null;
  };
  public shared (msg) func updateAsset(request : UpdateRequest) : async Nat {
    canistergeekMonitor.collectMetrics();
    logEvent(level_1, "updateAsset()");
    assert (msg.caller == _minter);
    var i : Nat = request.assetID;
    var tassets : [var Asset] = Array.thaw<Asset>(_assets);
    var asset : Asset = tassets[i];
    asset := {
      name = asset.name;
      thumbnail = asset.thumbnail;
      payload = request.payload;
    };
    tassets[i] := asset;
    _assets := Array.freeze(tassets);
    return i;
  };
  public shared (msg) func addAsset(asset : Asset) : async Nat {
    canistergeekMonitor.collectMetrics();
    logEvent(level_1, "addAsset()");
    assert (msg.caller == _minter);
    _assets := Array.append(_assets, [asset]);
    _assets.size() - 1;
  };
  public shared (msg) func mintNFT(request : MintingRequest) : async TokenIndex {
    canistergeekMonitor.collectMetrics();
    logEvent(level_1, "mintNFT()");
    assert (msg.caller == _minter);
    let receiver = request.to;
    let token = _nextTokenId;
    let md : Metadata = #nonfungible({
      metadata = ?_nat32ToBlob(request.asset);
    });
    _tokenMetadata.put(token, md);
    _transferTokenToUser(token, receiver);
    _supply := _supply + 1;
    _nextTokenId := _nextTokenId + 1;
    token;
  };
  func _nat32ToBlob(n : Nat32) : Blob {
    if (n < 256) {
      return Blob.fromArray([0, 0, 0, Nat8.fromNat(Nat32.toNat(n))]);
    } else if (n < 65536) {
      return Blob.fromArray([
        0,
        0,
        Nat8.fromNat(Nat32.toNat((n >> 8) & 0xFF)),
        Nat8.fromNat(Nat32.toNat((n) & 0xFF)),
      ]);
    } else if (n < 16777216) {
      return Blob.fromArray([
        0,
        Nat8.fromNat(Nat32.toNat((n >> 16) & 0xFF)),
        Nat8.fromNat(Nat32.toNat((n >> 8) & 0xFF)),
        Nat8.fromNat(Nat32.toNat((n) & 0xFF)),
      ]);
    } else {
      return Blob.fromArray([
        Nat8.fromNat(Nat32.toNat((n >> 24) & 0xFF)),
        Nat8.fromNat(Nat32.toNat((n >> 16) & 0xFF)),
        Nat8.fromNat(Nat32.toNat((n >> 8) & 0xFF)),
        Nat8.fromNat(Nat32.toNat((n) & 0xFF)),
      ]);
    };
  };

  func _blobToNat32(b : Blob) : Nat32 {
    var index : Nat32 = 0;
    Array.foldRight<Nat8, Nat32>(
      Blob.toArray(b),
      0,
      func(u8, accum) {
        index += 1;
        accum + Nat32.fromNat(Nat8.toNat(u8)) << ((index - 1) * 8);
      },
    );
  };

  public shared (msg) func transfer(request : TransferRequest) : async TransferResponse {
    canistergeekMonitor.collectMetrics();
    logEvent(level_1, "transfer");
    if (request.amount != 1) {
      return #err(#Other("Must use amount of 1"));
    };
    if (ExtCore.TokenIdentifier.isPrincipal(request.token, Principal.fromActor(this)) == false) {
      return #err(#InvalidToken(request.token));
    };
    let token = ExtCore.TokenIdentifier.getIndex(request.token);
    if (Option.isSome(_tokenListing.get(token))) {
      return #err(#Other("This token is currently listed for sale!"));
    };
    let owner = ExtCore.User.toAID(request.from);
    let spender = AID.fromPrincipal(msg.caller, request.subaccount);
    let receiver = ExtCore.User.toAID(request.to);
    if (AID.equal(owner, spender) == false) {
      return #err(#Unauthorized(spender));
    };
    switch (_registry.get(token)) {
      case (?token_owner) {
        if (AID.equal(owner, token_owner) == false) {
          return #err(#Unauthorized(owner));
        };
        if (request.notify) {
          switch (ExtCore.User.toPrincipal(request.to)) {
            case (?canisterId) {
              //Do this to avoid atomicity issue
              _removeTokenFromUser(token);
              let notifier : NotifyService = actor (Principal.toText(canisterId));
              switch (await notifier.tokenTransferNotification(request.token, request.from, request.amount, request.memo)) {
                case (?balance) {
                  if (balance == 1) {
                    _transferTokenToUser(token, receiver);
                    _capAddTransfer(token, owner, receiver);
                    return #ok(request.amount);
                  } else {
                    //Refund
                    _transferTokenToUser(token, owner);
                    return #err(#Rejected);
                  };
                };
                case (_) {
                  //Refund
                  _transferTokenToUser(token, owner);
                  return #err(#Rejected);
                };
              };
            };
            case (_) {
              return #err(#CannotNotify(receiver));
            };
          };
        } else {
          _transferTokenToUser(token, receiver);
          _capAddTransfer(token, owner, receiver);
          return #ok(request.amount);
        };
      };
      case (_) {
        return #err(#InvalidToken(request.token));
      };
    };
  };

  public query func getMinter() : async Principal {
    _minter;
  };
  public query func extensions() : async [Extension] {
    EXTENSIONS;
  };
  public query func balance(request : BalanceRequest) : async BalanceResponse {
    if (ExtCore.TokenIdentifier.isPrincipal(request.token, Principal.fromActor(this)) == false) {
      return #err(#InvalidToken(request.token));
    };
    let token = ExtCore.TokenIdentifier.getIndex(request.token);
    let aid = ExtCore.User.toAID(request.user);
    switch (_registry.get(token)) {
      case (?token_owner) {
        if (AID.equal(aid, token_owner) == true) {
          return #ok(1);
        } else {
          return #ok(0);
        };
      };
      case (_) {
        return #err(#InvalidToken(request.token));
      };
    };
  };
  public query func bearer(token : TokenIdentifier) : async Result.Result<AccountIdentifier, CommonError> {
    if (ExtCore.TokenIdentifier.isPrincipal(token, Principal.fromActor(this)) == false) {
      return #err(#InvalidToken(token));
    };
    let tokenind = ExtCore.TokenIdentifier.getIndex(token);
    switch (_getBearer(tokenind)) {
      case (?token_owner) {
        return #ok(token_owner);
      };
      case (_) {
        return #err(#InvalidToken(token));
      };
    };
  };
  public query func supply(token : TokenIdentifier) : async Result.Result<Balance, CommonError> {
    #ok(_supply);
  };
  public query func getRegistry() : async [(TokenIndex, AccountIdentifier)] {
    Iter.toArray(_registry.entries());
  };
  public query func getTokens() : async [(TokenIndex, Metadata)] {
    var resp : [(TokenIndex, Metadata)] = [];
    for (e in _tokenMetadata.entries()) {
      resp := Array.append(resp, [(e.0, #nonfungible({ metadata = null }))]);
    };
    resp;
  };
  public query func tokens(aid : AccountIdentifier) : async Result.Result<[TokenIndex], CommonError> {
    switch (_owners.get(aid)) {
      case (?tokens) return #ok(tokens);
      case (_) return #err(#Other("No tokens"));
    };
  };

  public query func tokens_ext(aid : AccountIdentifier) : async Result.Result<[(TokenIndex, ?Listing, ?Blob)], CommonError> {
    switch (_owners.get(aid)) {
      case (?tokens) {
        var resp : [(TokenIndex, ?Listing, ?Blob)] = [];
        for (a in tokens.vals()) {
          resp := Array.append(resp, [(a, _tokenListing.get(a), null)]);
        };
        return #ok(resp);
      };
      case (_) return #err(#Other("No tokens"));
    };
  };
  public query func metadata(token : TokenIdentifier) : async Result.Result<Metadata, CommonError> {
    if (ExtCore.TokenIdentifier.isPrincipal(token, Principal.fromActor(this)) == false) {
      return #err(#InvalidToken(token));
    };
    let tokenind = ExtCore.TokenIdentifier.getIndex(token);
    switch (_tokenMetadata.get(tokenind)) {
      case (?token_metadata) {
        return #ok(token_metadata);
      };
      case (_) {
        return #err(#InvalidToken(token));
      };
    };
  };
  public query func details(token : TokenIdentifier) : async Result.Result<(AccountIdentifier, ?Listing), CommonError> {
    if (ExtCore.TokenIdentifier.isPrincipal(token, Principal.fromActor(this)) == false) {
      return #err(#InvalidToken(token));
    };
    let tokenind = ExtCore.TokenIdentifier.getIndex(token);
    switch (_getBearer(tokenind)) {
      case (?token_owner) {
        return #ok((token_owner, _tokenListing.get(tokenind)));
      };
      case (_) {
        return #err(#InvalidToken(token));
      };
    };
  };

  //Listings
  public query func transactions() : async [Transaction] {
    _transactionBuffer.toArray();
  };
  public query func settlements() : async [(TokenIndex, AccountIdentifier, Nat64)] {
    //Lock to admin?
    var result : [(TokenIndex, AccountIdentifier, Nat64)] = [];
    for ((token, listing) in _tokenListing.entries()) {
      if (_isLocked(token)) {
        switch (_tokenSettlement.get(token)) {
          case (?settlement) {
            result := Array.append(result, [(token, AID.fromPrincipal(settlement.seller, ?settlement.subaccount), settlement.price)]);
          };
          case (_) {};
        };
      };
    };
    result;
  };
  public query (msg) func payments() : async ?[SubAccount] {
    _payments.get(msg.caller);
  };
  public query func listings() : async [(TokenIndex, Listing, Metadata)] {
    var results : [(TokenIndex, Listing, Metadata)] = [];
    for (a in _tokenListing.entries()) {
      results := Array.append(results, [(a.0, a.1, #nonfungible({ metadata = null }))]);
    };
    results;
  };
  public query (msg) func allSettlements() : async [(TokenIndex, Settlement)] {
    Iter.toArray(_tokenSettlement.entries());
  };
  public query (msg) func allPayments() : async [(Principal, [SubAccount])] {
    Iter.toArray(_payments.entries());
  };
  public shared (msg) func clearPayments(seller : Principal, payments : [SubAccount]) : async () {
    canistergeekMonitor.collectMetrics();
    logEvent(level_1, "clearPayments()");
    var removedPayments : [SubAccount] = [];
    for (p in payments.vals()) {
      let response : ICPTs = await LEDGER_CANISTER.account_balance_dfx({
        account = AID.fromPrincipal(seller, ?p);
      });
      if (response.e8s < 10_000) {
        removedPayments := Array.append(removedPayments, [p]);
      };
    };
    switch (_payments.get(seller)) {
      case (?sellerPayments) {
        var newPayments : [SubAccount] = [];
        for (p in sellerPayments.vals()) {
          if (
            Option.isNull(
              Array.find(
                removedPayments,
                func(a : SubAccount) : Bool {
                  Array.equal(a, p, Nat8.equal);
                },
              )
            )
          ) {
            newPayments := Array.append(newPayments, [p]);
          };
        };
        _payments.put(seller, newPayments);
      };
      case (_) {};
    };
  };

  //HTTP
  type HeaderField = (Text, Text);
  type HttpResponse = {
    status_code : Nat16;
    headers : [HeaderField];
    body : Blob;
    streaming_strategy : ?HttpStreamingStrategy;
  };
  type HttpRequest = {
    method : Text;
    url : Text;
    headers : [HeaderField];
    body : Blob;
  };
  type HttpStreamingCallbackToken = {
    content_encoding : Text;
    index : Nat;
    key : Text;
    sha256 : ?Blob;
  };

  type HttpStreamingStrategy = {
    #Callback : {
      callback : query (HttpStreamingCallbackToken) -> async (HttpStreamingCallbackResponse);
      token : HttpStreamingCallbackToken;
    };
  };

  type HttpStreamingCallbackResponse = {
    body : Blob;
    token : ?HttpStreamingCallbackToken;
  };
  let NOT_FOUND : HttpResponse = {
    status_code = 404;
    headers = [];
    body = Blob.fromArray([]);
    streaming_strategy = null;
  };
  let BAD_REQUEST : HttpResponse = {
    status_code = 400;
    headers = [];
    body = Blob.fromArray([]);
    streaming_strategy = null;
  };

  public query func http_request(request : HttpRequest) : async HttpResponse {
    logEvent(level_1, "http_request()");
    let path = Iter.toArray(Text.tokens(request.url, #text("/")));
    switch (_getParam(request.url, "tokenid")) {
      case (?tokenid) {
        switch (_getTokenData(tokenid)) {
          case (?metadata) {
            let assetid : Nat = Nat32.toNat(_blobToNat32(metadata));
            let asset : Asset = _assets[assetid];
            switch (_getParam(request.url, "type")) {
              case (?t) {
                if (t == "thumbnail") {
                  switch (asset.thumbnail) {
                    case (?thumb) {
                      return {
                        status_code = 200;
                        headers = [("content-type", thumb.ctype)];
                        body = thumb.data[0];
                        streaming_strategy = null;
                      };
                    };
                    case (_) {};
                  };
                };
              };
              case (_) {};
            };
            return _processFile(Nat.toText(assetid), asset.payload);
          };
          case (_) {};
        };
      };
      case (_) {};
    };
    switch (_getParam(request.url, "asset")) {
      case (?atext) {
        switch (_getAssetId(atext)) {
          case (?assetid) {
            let asset : Asset = _assets[assetid];
            switch (_getParam(request.url, "type")) {
              case (?t) {
                if (t == "thumbnail") {
                  switch (asset.thumbnail) {
                    case (?thumb) {
                      return {
                        status_code = 200;
                        headers = [("content-type", thumb.ctype)];
                        body = thumb.data[0];
                        streaming_strategy = null;
                      };
                    };
                    case (_) {};
                  };
                };
              };
              case (_) {};
            };
            return _processFile(Nat.toText(assetid), asset.payload);
          };
          case (_) {};
        };
      };
      case (_) {};
    };

    //Just show index
    let t_transactions : [Transaction] = _transactionBuffer.toArray();
    var soldValue : Nat = Nat64.toNat(Array.foldLeft<Transaction, Nat64>(t_transactions, 0, func(b : Nat64, a : Transaction) : Nat64 { b + a.price }));
    var avg : Nat = if (t_transactions.size() > 0) {
      soldValue / t_transactions.size();
    } else {
      0;
    };
    return {
      status_code = 200;
      headers = [("content-type", "text/plain")];
      body = Text.encodeUtf8(
        "Cycle Balance:                            ~" # debug_show (Cycles.balance() / 1000000000000) # "T\n" #
        "Minted NFTs:                              " # debug_show (_nextTokenId) # "\n" #
        "Marketplace Listings:                     " # debug_show (_tokenListing.size()) # "\n" #
        "Sold via Marketplace:                     " # debug_show (t_transactions.size()) # "\n" #
        "Sold via Marketplace in ICP:              " # _displayICP(soldValue) # "\n" #
        "Average Price ICP Via Marketplace:        " # _displayICP(avg) # "\n" #
        "Admin:                                    " # debug_show (_minter) # "\n"
      );
      streaming_strategy = null;
    };
  };
  public query func http_request_streaming_callback(token : HttpStreamingCallbackToken) : async HttpStreamingCallbackResponse {
    switch (_getAssetId(token.key)) {
      case null return { body = Blob.fromArray([]); token = null };
      case (?assetid) {
        let asset : Asset = _assets[assetid];
        let res = _streamContent(token.key, token.index, asset.payload.data);
        return {
          body = res.0;
          token = res.1;
        };
      };
    };
  };
  private func _getAssetId(t : Text) : ?Nat {
    var n : Nat = 0;
    while (n < _assets.size()) {
      if (t == Nat.toText(n)) {
        return ?n;
      } else {
        n += 1;
      };
    };
    return null;
  };
  private func _processFile(tokenid : TokenIdentifier, file : File) : HttpResponse {
    if (file.data.size() > 1) {
      let (payload, token) = _streamContent(tokenid, 0, file.data);
      return {
        status_code = 200;
        headers = [("Content-Type", file.ctype), ("cache-control", "public, max-age=15552000")];
        body = payload;
        streaming_strategy = ? #Callback({
          token = Option.unwrap(token);
          callback = http_request_streaming_callback;
        });
      };
    } else {
      return {
        status_code = 200;
        headers = [("content-type", file.ctype), ("cache-control", "public, max-age=15552000")];
        body = file.data[0];
        streaming_strategy = null;
      };
    };
  };

  private func _getTokenData(token : Text) : ?Blob {
    if (ExtCore.TokenIdentifier.isPrincipal(token, Principal.fromActor(this)) == false) {
      return null;
    };
    let tokenind = ExtCore.TokenIdentifier.getIndex(token);
    switch (_tokenMetadata.get(tokenind)) {
      case (?token_metadata) {
        switch (token_metadata) {
          case (#fungible data) return null;
          case (#nonfungible data) return data.metadata;
        };
      };
      case (_) {
        return null;
      };
    };
    return null;
  };
  private func _getParam(url : Text, param : Text) : ?Text {
    var _s : Text = url;
    Iter.iterate<Text>(
      Text.split(_s, #text("/")),
      func(x, _i) {
        _s := x;
      },
    );
    Iter.iterate<Text>(
      Text.split(_s, #text("?")),
      func(x, _i) {
        if (_i == 1) _s := x;
      },
    );
    var t : ?Text = null;
    var found : Bool = false;
    Iter.iterate<Text>(
      Text.split(_s, #text("&")),
      func(x, _i) {
        if (found == false) {
          Iter.iterate<Text>(
            Text.split(x, #text("=")),
            func(y, _ii) {
              if (_ii == 0) {
                if (Text.equal(y, param)) found := true;
              } else if (found == true) t := ?y;
            },
          );
        };
      },
    );
    return t;
  };
  private func _streamContent(id : Text, idx : Nat, data : [Blob]) : (Blob, ?HttpStreamingCallbackToken) {
    let payload = data[idx];
    let size = data.size();

    if (idx + 1 == size) {
      return (payload, null);
    };

    return (
      payload,
      ?{
        content_encoding = "gzip";
        index = idx + 1;
        sha256 = null;
        key = id;
      },
    );
  };

  //Internal cycle management - good general case
  public func acceptCycles() : async () {
    canistergeekMonitor.collectMetrics();
    logEvent(level_1, "acceptCycles()");
    let available = Cycles.available();
    let accepted = Cycles.accept(available);
    assert (accepted == available);
  };
  public query func availableCycles() : async Nat {
    return Cycles.balance();
  };

  //Private
  func _removeTokenFromUser(tindex : TokenIndex) : () {
    let owner : ?AccountIdentifier = _getBearer(tindex);
    _registry.delete(tindex);
    switch (owner) {
      case (?o) _removeFromUserTokens(tindex, o);
      case (_) {};
    };
  };
  func _transferTokenToUser(tindex : TokenIndex, receiver : AccountIdentifier) : () {
    let owner : ?AccountIdentifier = _getBearer(tindex);
    _registry.put(tindex, receiver);
    switch (owner) {
      case (?o) _removeFromUserTokens(tindex, o);
      case (_) {};
    };
    _addToUserTokens(tindex, receiver);
  };
  func _removeFromUserTokens(tindex : TokenIndex, owner : AccountIdentifier) : () {
    switch (_owners.get(owner)) {
      case (?ownersTokens) _owners.put(owner, Array.filter(ownersTokens, func(a : TokenIndex) : Bool { (a != tindex) }));
      case (_) ();
    };
  };
  func _addToUserTokens(tindex : TokenIndex, receiver : AccountIdentifier) : () {
    let ownersTokensNew : [TokenIndex] = switch (_owners.get(receiver)) {
      case (?ownersTokens) Array.append(ownersTokens, [tindex]);
      case (_) [tindex];
    };
    _owners.put(receiver, ownersTokensNew);
  };
  func _getBearer(tindex : TokenIndex) : ?AccountIdentifier {
    _registry.get(tindex);
  };
  func _isLocked(token : TokenIndex) : Bool {
    switch (_tokenListing.get(token)) {
      case (?listing) {
        switch (listing.locked) {
          case (?time) {
            if (time > Time.now()) {
              return true;
            } else {
              return false;
            };
          };
          case (_) {
            return false;
          };
        };
      };
      case (_) return false;
    };
  };
  func _displayICP(amt : Nat) : Text {
    debug_show (amt / 100000000) # "." # debug_show ((amt % 100000000) / 1000000) # " ICP";
  };
  public query func stats() : async (Nat64, Nat64, Nat64, Nat64, Nat, Nat, Nat) {
    let t_transactions : [Transaction] = _transactionBuffer.toArray();
    var res : (Nat64, Nat64, Nat64) = Array.foldLeft<Transaction, (Nat64, Nat64, Nat64)>(
      t_transactions,
      (0, 0, 0),
      func(b : (Nat64, Nat64, Nat64), a : Transaction) : (Nat64, Nat64, Nat64) {
        var total : Nat64 = b.0 + a.price;
        var high : Nat64 = b.1;
        var low : Nat64 = b.2;
        if (high == 0 or a.price > high) high := a.price;
        if (low == 0 or a.price < low) low := a.price;
        (total, high, low);
      },
    );
    var floor : Nat64 = 0;
    for (a in _tokenListing.entries()) {
      if (floor == 0 or a.1.price < floor) floor := a.1.price;
    };
    (res.0, res.1, res.2, floor, _tokenListing.size(), _registry.size(), t_transactions.size());
  };
  public shared (msg) func transfer_bulk(dist : [(TokenIndex, AccountIdentifier)]) : async [(TokenIndex, AccountIdentifier)] {
    canistergeekMonitor.collectMetrics();
    logEvent(level_1, "transfer_bulk");
    assert (msg.caller == _minter);
    var ret : [(TokenIndex, AccountIdentifier)] = [];
    let spender = AID.fromPrincipal(msg.caller, null);
    for ((t, a) in dist.vals()) {
      switch (_registry.get(t)) {
        case (?token_owner) {
          if (spender == token_owner) {
            _transferTokenToUser(t, a);
          } else {
            ret := Array.append(ret, [(t, a)]);
          };
        };
        case (_) {
          ret := Array.append(ret, [(t, a)]);
        };
      };
    };
    ret;
  };
  public shared (msg) func list_bulk(dist : [(TokenIndex, Nat64)]) : async [(TokenIndex, Nat64)] {
    canistergeekMonitor.collectMetrics();
    logEvent(level_1, "list_bulk");
    assert (msg.caller == _minter);
    var ret : [(TokenIndex, Nat64)] = [];
    let spender = AID.fromPrincipal(msg.caller, null);
    for ((t, p) in dist.vals()) {
      switch (_registry.get(t)) {
        case (?token_owner) {
          if (spender == token_owner) {
            _tokenListing.put(
              t,
              {
                seller = msg.caller;
                price = p;
                locked = null;
              },
            );
          } else {
            ret := Array.append(ret, [(t, p)]);
          };
        };
        case (_) {
          ret := Array.append(ret, [(t, p)]);
        };
      };
    };
    ret;
  };

};
