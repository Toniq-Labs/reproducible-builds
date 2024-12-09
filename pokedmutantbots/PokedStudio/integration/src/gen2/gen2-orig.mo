import DQ "mo:base/Deque";
import Time "mo:base/Time";
import Buffer "mo:base/Buffer";
import Result "mo:base/Result";
import Tokens "../../../../Motley-Base/src/nft/Tokens";
import Principal "../../../../Motley-Base/src/base/Principal";
import Ext "../../../../Motley-Base/src/nft/ext/Core";
import Nft "../../../../Motley-Base/src/nft/Types";
import AID "../../../../Motley-Base/src/nft/ext/util/AccountIdentifier";
import FS "../../Motley/src/storage/FileSystem/Filesystem";
import LH "../../Motley/src/tokens/nonfungible/LockHistory";
import TR "../../Motley/src/tokens/nonfungible/TokenRegistry";
import OR "../../Motley/src/tokens/nonfungible/OwnerRegistry";
import TB "../../Motley/src/tokens/nonfungible/TransactionBuffer";

shared ({ caller = _installer }) actor class NFT_Registry() = this {

  // =============================================================== //
  // Type Definitions                                                // 
  // =============================================================== //

  // Motley NFT Type(s)
  private type User = Nft.User;
  private type TokenState = Nft.TokenState;
  private type MintRequest = Nft.MintRequest;
  private type LockVariant = Nft.LockVariant;
  private type ServiceLock = Nft.ServiceLock;
  private type LockResponse = Nft.LockResponse;
  private type LockRequest = Nft.LockRequest;
  private type LockRecord = Nft.LockRecord;
  private type AssetIndex = Nft.AssetIndex;
  private type AssetList = Nft.AssetList;
  private type Disbursement = Nft.Disbursement;
  private type LockHistory = Nft.LockHistory;
  private type Listing = Nft.Listing;
  private type Transaction = Nft.Transaction;
  private type Metadata = Nft.Metadata;
  private type OwnerRegistry = OR.OwnerRegistry;
  private type TokenRegistry = TR.TokenRegistry;
  private type TransactionBuffer = TB.TransactionBuffer;

  // EXT Type(s)
  private type Extension = Ext.Extension;
  private type TokenIdentifier = Ext.TokenIdentifier;
  private type AccountIdentifier = Ext.AccountIdentifier;
  private type TokenIndex = Ext.TokenIndex;
  private type CommonError = Ext.CommonError;
  private type TransferRequest = Ext.TransferRequest;
  private type TransferResponse = Ext.TransferResponse;
  private type BalanceRequest = Ext.BalanceRequest;
  private type BalanceResponse = Ext.BalanceResponse;

  // Motley Filesystem Type(s)
  private type Filesystem = FS.Filesystem;

  // =============================================================== //
  // Stable Memory                                                   //
  // =============================================================== //
  stable var _supply : Nat = 0;
  stable var _lastbeat : Int = 0;
  stable var _init : Bool = false;
  stable var _heartbeat : Bool = false;
  stable var _next_token_id : Nat32 = 1;
  stable var _admins : Principal.Set = Principal.Set.init();
  stable var _assets : Filesystem = FS.init();
  stable var _locked_tokens : LockHistory = LH.init();
  stable var _token_registry : TokenRegistry = TR.init();
  stable var _owner_registry : OwnerRegistry = OR.init();
  stable var _transactions : TransactionBuffer = TB.init();
  stable var _disbursements : AccountsPayable = DQ.empty<Disbursement>();
  stable var _fileshare : Principal = Principal.placeholder();
  stable var _minter : Principal = Principal.placeholder();
  stable var _hbsvc : Principal = Principal.placeholder();
  stable var _self : Principal = Principal.placeholder();

  stable let _base_fee : [(AccountIdentififer, Nat64)] = [
    ("e17dacad8e8ccb289a0d5e7266b387eaa994d763789190510873e88cbda02386", 5000), //PokedStudio
  ];

  // =============================================================== //
  // Heap Memory                                                     //
  // =============================================================== // 

  // =============================================================== //
  // Public Registry Interface                                       //
  // =============================================================== //
  //
  public shared query func lastbeat() : async Int { _lastbeat };
  public shared query func get_minter() : async Principal { _minter };
  public shared query func admins() : async [Text] { admins_to_array() }; 
  public shared query func supply() : async Nat { _supply };
  public shared query func transactions() : async [Transaction] { TB.toArray(_transactions) };

  public shared query func getRegistry() : async [(TokenIndex,AccountIdentifier)] {
    TR.map_token_owners(_token_registry);
  };

  public shared query func getTokens() : async [(TokenIndex,Metadata)] {
    TR.map_token_metadata(_token_registry);
  };

  public shared query func get_token_identifier( t : TokenIndex ) : async TokenIdentifier {
    Ext.TokenIdentifier.fromPrincipal(Principal.fromActor(this), t);
  };

  public shared query func extensions() : async [Extension] {
    return ["@ext/common","@ext/nonfungible"];
  };
  
  public shared query func balance( request : BalanceRequest ) : async BalanceResponse {
    let token_index : TokenIndex = Ext.TokenIdentifier.getIndex(request.token);
    let wallet : AccountIdentifier = Ext.User.toAID(request.user);
    if ( is_token_owner(wallet, token_index) ){ return #ok(1) } else { return #ok(0) };
  };

  public shared query func bearer( token : TokenIdentifier ) : async Result.Result<AccountIdentifier,CommonError> {
    let token_index : TokenIndex = Ext.TokenIdentifier.getIndex(token);
    if ( Ext.TokenIdentifier.isPrincipal( token, _self ) == false ){
      return #err(#InvalidToken(token));
    };
    switch( get_token_owner( token_index ) : ?AccountIdentifier ){
      case(?account_id){ return #ok(account_id) };
      case(_){ return #err( #InvalidToken(token) )};
    };
  };

  public shared query func tokens( aid : AccountIdentifier ) : async Result.Result<[TokenIndex], CommonError> {
    switch( get_owner_tokens(aid) ){
      case( null ){ return #err(#Other("No Tokens"))};
      case( ?ta ){ return #ok(ta) };
    };
  };

  private type TokensExtResult = Result.Result<[(TokenIndex, ?Listing, ?Blob)], CommonError>;
  public shared query func tokens_ext( aid : AccountIdentifier ) : async TokensExtResult {
    let buff = Buffer.Buffer<(TokenIndex, ?Listing, ?Blob)>(0);
    switch( get_owner_tokens(aid) ){
      case( null ){ return #err(#Other("No Tokens")) };
      case( ?ta ){
        for ( tindex in ta.vals() ){
          switch ( get_token_state(tindex) ){
            case( ?state ){ buff.add((tindex, state.listing, state.metadata)) };
            case( null ){};
      }}}};
    #ok( buff.toArray() );
  };

  public shared query func metadata( tid : TokenIdentifier ) : async Result.Result<Metadata, CommonError> {
    if (Ext.TokenIdentifier.isPrincipal(tid, _self) == false) {return #err(#InvalidToken(tid))};
    let tindex : TokenIndex = Ext.TokenIdentifier.getIndex(tid);
    switch( get_token_metadata(tindex) ){
      case( null ){ return #err(#Other("Metadata not found")) };
      case( ?md ){ return #ok(md) };
    };
  };

  type DetailsResult = Result.Result<( AccountIdentifier, ?Listing),  CommonError>;
  public shared query func details( tid : TokenIdentifier ) : async DetailsResult {
    if (Ext.TokenIdentifier.isPrincipal(tid, _self) == false) {return #err(#InvalidToken(tid))};
    let tindex : TokenIndex = Ext.TokenIdentifier.getIndex(tid);
    switch( get_token_state(tindex) ){
      case( ?state ){ return #ok((state.owner, state.listing)) };
      case( null ){ return #err(#InvalidToken(tid)) };
    };
  };

  public shared ({caller}) func transfer( request : TransferRequest ) : async TransferResponse {
    if ( request.amount != 1){return #err(#Other("must use amount of 1")) };
    let token_index : TokenIndex = Ext.TokenIdentifier.getIndex(request.token);
    let sender : AccountIdentifier = AID.fromPrincipal(caller, request.subaccount);
    if ( is_token_owner(sender, token_index) == false ){return #err(#Unauthorized(sender)) };
    let receiver : AccountIdentifier = Ext.User.toAID(request.to);
    switch( get_token_lock( token_index ) ){
      case( null ){ return #err(#InvalidToken(request.token)) }; 
      case( ?lock ){
        switch( lock ){
          case( #Unlocked ){
            transfer_token(sender, receiver, token_index);
            return #ok(0) };
          case(_){
            return #err(#Other("Token is locked"));
          };
        };
      };
    };
  };

  // =============================================================== //
  // Marketplace Methods                                             //
  // =============================================================== //
  //
  public shared query ({caller}) func settlements() : async [(TokenIndex, AccountIdentifier, Nat64)] {
    TR.settlements(_token_registry);
  };

  public query func allSettlements() : async [(TokenIndex, Settlement)] {
    TR.token_settlements(_token_registry);
  };

  public query func listings() : [(TokenIndex, Listing, Metadata)] {
    TR.map_listing_metadata(_token_registry);
  };

  public shared ({caller}) func list( request : ListRequest ) : async ListResponse {
    if ( Ext.TokenIdentifier.isPrincipal( request.token, _self ) == false ){
      return #err(#InvalidToken(token)) };
    let tindex : TokenIndex = Ext.TokenIdentifier.getIndex(tid);
    let seller : AccountIdentifier = AID.fromPrincipal(caller, request.from_subaccount);
    if ( is_token_owner(seller, tindex) == false ){return #err(#Other("Unauthorized seller")) };
    if ( is_locked(tindex) == true ){ return #err(#Other("Listing is locked")) };
    list_token( tindex, seller, request.price );
  };

  public shared ({caller}) func lock(tid : TokenIdentifier, price : Nat64,
    address : AccountIdentifier, _subaccountNOTUSED : SubAccount ) : async LockResponse {
      if ( Ext.TokenIdentifier.isPrincipal( request.token, _self ) == false ){
        return #err(#InvalidToken(token)) };
      let tindex : TokenIndex = Ext.TokenIdentifier.getIndex(tid);
      switch( get_token_listing(tindex) ){
        case( null ){ #err(#Other("No Listing!")) };
        case( ?listing ){
          if ( listing.price != price ){ #err(#Other("Price has changed")) };
          if ( is_locked(tindex) ){ #err(#Other("Listing is locked")) };
          let subaccount : Subaccount = get_next_subaccount();
          let payment_address : AccountIdentifier = AID.fromPrincipal(_self, ?subaccount);
          let fee_buffer = Buffer.fromArray<(AccountIdentifier,Nat64)>(_base_fee);
          fee_buffer.add(( "c7e461041c0c5800a56b64bb7cefc247abc0bbbb99bd46ff71c64e92d9f5c2f9", 1000)); // Standard Entrepot Fee
          set_token_lock(
            tindex,
            #Market({
              seller = listing.seller;
              buyer = address;
              escrow = payment_address;
              subaccount = subaccount;
              price = listing.price;
              fee = Buffer.toArray(fee_buffer);
            })
          );
          add_locked_token({
            token = tindex;
            time = Time.now();
            ttl = 2 * 60 * 1_000_000_000;
          });
          #ok(payment_address);
        };
      };
    };

  public shared ({caller}) func settle(tokenid : TokenIdentifier) : async SettleResponse {
    if ( Ext.TokenIdentifier.isPrincipal( request.token, _self ) == false ){
      return #err(#InvalidToken(tokenid)) };
    let tindex : TokenIndex = Ext.TokenIdentifier.getIndex(tokenid);
    switch( get_token_state(tindex) ){
      case( null ){ #err(#InvalidToken(tokenid)) };
      case( ?state ){
        if( Option.isSome(state.listing) == false ){ #err(#Other("Nothing to settle")) };
        switch( state.lock ){
          case( #Frozen ){ #err(#Other("Duplicate request")) };
          case( #Market(settlement) ){
            set_token_lock(tindex, #Frozen);
            let escrow_account : AccountIdentifier = settlement.escrow;
            let escrow_fees = Buffer.fromArray<Fees>(settlement.fees).add(_creator_fee);
            let escrow_balance : ICPTs = await LEDGER_CANISTER.account_balance_dfx({account=escrow_account});
            if( escrow_balance.e8s >= settlement.price ){
              var bal : Nat64 = settlement.price - (10000 * Nat64.fromNat(salesFees.size() + 1));
              var rem : Nat65 = bal;
              for ( f in escrow_fees.vals() ){
                let fee : Nat64 = bal * f.1 / 100000;
                add_disbursement((tindex, f.0, settlement.subaccount, fee));
                rem := rem - fee;
              };
              add_disbursement((tindex, state.owner, settlement.subaccount, rem));
              delete_token_listing(tindex);
              set_token_lock(tindex, #Unlocked);
              transfer_token(state.owner, settlement.buyer, tindex);
              add_transaction({
                token = tokenid;
                seller = state.owner;
                price = settlement.price;
                buyer = settlement.buyer;
                time = Time.now();
              });
            } else {
              set_token_lock(tindex, #Market(settlement));
              release_expired_locks();
              return #err(#Other("Insufficient funds sent"));
            }};
          case(_){ #err(#Other("Nothing to settle")) };
        };
      };
    };
  };

  func cronDisbursement() : () {
    var processing : Bool = true;
    while( processing ){
      switch( next_disbursement() ){
        case( null ){ processing := false };
        case(?d) {
          try {
            var bh = await T.LEDGER_CANISTER.send_dfx({
              memo = Encoding.BigEndian.toNat64(Blob.toArray(Principal.toBlob(Principal.fromText(ExtCore.TokenIdentifier.fromPrincipal(Principal.fromActor(this), d.0)))));
              amount = { e8s = d.3 };
              fee = { e8s = 10000 };
              from_subaccount = ?d.2;
              to = d.1;
              created_at_time = null;
            });
          } catch (e) {
            _disbursements := DQ.pushBack<Disbursement>(_disbursements, d);
          };
        };
      };
    };
  };

  func cronSettlements() : () {
    for( settlement in TR.token_settlements(_token_registry) ){
      ignore settle(Ext.TokenIdentifier.fromPrincipal(Principal.fromActor(this), settlement.0));
    };
  };

  // =============================================================== //
  // Minting Interface                                               //
  // =============================================================== //
  //
  public shared ({caller}) func mint_nft( request : MintRequest ) : async ?TokenIndex {
    assert Principal.equal(_minter, caller);
    switch( request.method ){
      case( #Path(path) ){
        switch( FS.traverse(_assets, path) ){
          case( null ){ null };
          case( ?dentry ){
            let receiver : AccountIdentifier = Ext.User.toAID(request.to);
            let tindex : TokenIndex = next_token_id();
            let metadata : Metadata = #nonfungible( { metadata = null } );
            mint_token(tindex, dentry.inode, receiver, metadata);
            add_owner_tokens(receiver, [tindex]);
            _supply += 1;
            ?tindex;
          };
        };
      };
      case(_){ null };
    };
  };

  // =============================================================== //
  // Admin Interface                                                 //
  // =============================================================== //
  //
  public shared ({caller}) func init( hb : Text ) : async Result.Result<(), CommonError> {
    assert Principal.equal(caller, _installer) and not _init;
    _minter := _installer;
    set_admins_from_array([Principal.toText(_installer)]);
    try {
      _hbsvc := Principal.fromText(hb);
    } catch (e) {
      return #err(#Other("Failed to convert text to principal"));
    };
    let hbsvc : HeartbeatService = actor(hb);
    try {
      await hbsvc.schedule([{interval = HB.Intervals._15beats; tasks = [pulse]}]);
    } catch (e) {
      return #err(#Other("Failed to schedule heartbeat task"));
    };
    if (Option.isNull(capRootBucketId)){
      try {
        capRootBucketId := await CapService.handshake(Principal.toText(Principal.fromActor(this)), 1_000_000_000_000);
      } catch e {
        return #err(#Other("Failed to initialize CAP service"));
      };
    };
    _heartbeat := true;
    _init := true;
    return #ok();
  };

  public shared ({caller}) func reschedule( hb : ?Text ) : async Result.Result<(), CommonError> {
    assert Principal.Set.match(_admins, caller) and _init;
    switch(hb){
      case( null ){};
      case( ?address ){ 
        try {
          _hbsvc := Principal.fromText(address);
        } catch (e) {
          return #err(#Other("Failed to convert text to principal"));
      }}};
    let hbsvc :  HeartbeatService = actor(Principal.toText(_hbsvc));
    try {
      await hbsvc.schedule([
        {interval = HB.Intervals._15beats; tasks = [pulse]},
        {interval = HB.Intervals._30beats; tasks = [report_balance]},
        ]);
    } catch (e) {
      return #err(#Other("Failed to schedule heartbeat task"));
    };
    _heartbeat := true;
    return #ok();
  };

  public shared ({caller}) func mount( path : Path ) : FSReturn<()> {
    assert Principal.equal(caller, _installer) and _init;
    let filesvc = actor(Principal.toText(_fileshare)) : actor {
      export_path : shared(Path) -> async FSReturn<Filesystem> };
    try {
      switch( await filesvc.export_path(path) ){
        case( #err(val) ){ #err(val) };
        case( #ok(newfs) ){ _assets := newfs };
      };
    } catch (e) {
      #err(#Failure("Trapped while calling fileshare service"));
    };
  };

	public shared ({caller}) func set_minter( a : Text) : async () {
    assert Principal.Set.match(_admins, caller);
		_minter := Principal.fromText(a);
	};

  public shared ({caller}) func add_admin( admin : Text ) : async [Text] {
    assert Principal.Set.match(_admins, caller) and _init;
    put_admin(admin);
    admins_to_array();
  };

  public shared ({caller}) func remove_admin( admin : Text ) : async [Text] {
    assert Principal.Set.match(_admins, caller) and _init;
    delete_admin(admin);
    admins_to_array();
  };

  public shared ({caller}) func set_admins( ta : [Text] ) : async [Text] {
    assert Principal.Set.match(_admins, caller) and _init;
    set_admins_from_array(ta);
    admins_to_array();
  };

  // =============================================================== //
  // Callback Methods                                                //
  // =============================================================== //
  //
  public shared ({caller}) func pulse() : () {
    assert Principal.equal(caller, _hbsvc);
    _lastbeat := Time.now();
    if _heartbeat {
        await cronDisbursements();
        await cronSettlements();
    };
  };

  public shared ({caller}) func report_balance() : () {
    assert Principal.equal(caller, _hbsvc);
    let bal = Cycles.balance();
    let hbsvc :  HeartbeatService = actor(Principal.toText(_hbsvc));
    hbsvc.report_balance({balance = bal; transfer = acceptCycles});
  };

  // =============================================================== //
  // HTTP Interface                                                  //
  // =============================================================== //
  //
  public shared query func http_request( request : Http.Request ) : async Http.Response {
    var embed : Bool = false;
    var elems : [Text] = Iter.toArray(Text.split(request.url, #text("/?")));
    let path : Text = elems[0];
    if ( elems.size() > 1 ){ embed := true };
    if ( Path.is_valid(path) == false ){ return Http.BAD_REQUEST() };
    switch( FS.traverse(_files, path) ){
      case( #err(val) ){ Debug.print("not found"); Http.NOT_FOUND() };
      case( #ok(dentry) ){
        Debug.print("Dentry found");
        Debug.print("Inode: " # Nat.toText(dentry.inode));
        if( not dentry.global ){ return Http.UNAUTHORIZED() };
        switch( dentry.validity ){
          case( #Blacklisted ){ Http.LEGAL() };
          case( #Valid ){
            switch( FS.get_inode(_files, dentry.inode) ){
              case( null ){ Debug.print("Bad Request"); Http.BAD_REQUEST() };
              case( ?inode ){
                Debug.print("Inode found");
                switch( inode ){
                  case( #Directory(val) ){ http_process_directory(val, path) };
                  case( #File(file) ){
                    Debug.print("Found File");
                    if embed { return Http.generic(file.ftype, Blob.fromArray([]), ?#Callback(file.pointer)) };
                    if ( Text.contains(file.ftype, #text("video")) ){ return http_process_video(file, path) };
                    Http.generic( file.ftype, Blob.fromArray([]), ?#Callback(file.pointer) );
                    };
                  };
                };
              };
            };
          case(_){ Http.NOT_FOUND() };
        };
      };
    };
  };

  // =============================================================== //
  // Private Methods                                                 //
  // =============================================================== //
  //
  func admins_to_array() : [Text] { Principal.Set.toArray(_admins) };
  func is_minter( p : Principal ) : Bool {
    Principal.equal(p, _minter);
  };
  func mint_token( ti : TokenIndex, as : AssetIndex, ai : AccountIdentifier, md : Metadata ) : () {
    _token_registry := TR.mint_token(_token_registry, ti, as, ai, md);
    _supply := _supply + 1;
  };
  func get_token_state( ti : TokenIndex ) : ?TokenState {
    TR.get_token_state(_token_registry, ti);
  }; 
  func set_token_owner( ti : TokenIndex, ai : AccountIdentifier ) : () {
    _token_registry := TR.set_token_owner(_token_registry, ti, ai);
  };
  func get_token_owner( ti : TokenIndex ) : ?AccountIdentifier {
    TR.get_token_owner(_token_registry, ti);
  };
  func add_token_operators( ti : TokenIndex, aia : [AccountIdentifier] ) : () {
    _token_registry := TR.add_token_operators(_token_registry, ti, aia);
  };
  func set_token_operators( ti : TokenIndex, aia : [AccountIdentifier] ) : () {
    _token_registry := TR.set_token_operators(_token_registry, ti, aia);
  };
  func get_token_operators( ti : TokenIndex ) : ?[AccountIdentifier] {
    TR.get_token_operators(_token_registry, ti);
  };
  func set_token_asset( ti : TokenIndex, asset : AssetIndex ) : () {
    _token_registry := TR.set_token_asset(_token_registry, ti, asset);
  };
  func get_token_asset( ti : TokenIndex ) : ?AssetIndex {
    TR.get_token_asset(_token_registry, ti);
  };
  func set_token_metadata( ti : TokenIndex, md : Metadata ) : () {
    _token_registry := TR.set_token_metadata(_token_registry, ti, md);
  };
  func get_token_metadata( ti : TokenIndex ) : ?Metadata {
    TR.get_token_metadata(_token_registry, ti);
  };
  func set_token_lock( ti : TokenIndex, lock : LockVariant ) : () {
    _token_registry := TR.set_token_lock(_token_registry, ti, lock);
  };
  func get_token_lock( ti : TokenIndex ) : ?LockVariant {
    TR.get_token_lock(_token_registry, ti);
  };
  func add_operator_tokens( ai : AccountIdentifier, tia : [TokenIndex] ) : () {
    _owner_registry := OR.add_operator_tokens(_owner_registry, ai, tia);
  };
  func remove_operator_tokens( ai : AccountIdentifier, tia : [TokenIndex] ) : () {
    _owner_registry := OR.remove_operator_tokens(_owner_registry, ai, tia);
    _owner_registry := OR.prune_owner_record(_owner_registry, ai );
  };
  func get_operator_tokens( ai : AccountIdentifier ) : ?[TokenIndex] {
    OR.get_operator_tokens(_owner_registry, ai);
  };
  func add_owner_tokens( ai : AccountIdentifier, tia : [TokenIndex] ) : () {
    _owner_registry := OR.add_owner_tokens(_owner_registry, ai, tia);
  };
  func remove_owner_tokens( ai : AccountIdentifier, tia : [TokenIndex] ) : () {
    _owner_registry := OR.remove_owner_tokens(_owner_registry, ai, tia);
    _owner_registry := OR.prune_owner_record(_owner_registry, ai );
  };
  func get_owner_tokens( ai : AccountIdentifier ) : ?[TokenIndex] {
    OR.get_owner_tokens(_owner_registry, ai);
  };
  func add_locked_token( lr : LockRecord ) : () {
    _locked_tokens := LH.add_lock(_locked_tokens, lr);
  };
  func put_admin( p : Principal ) : () {
    _admins := Principal.Set.insert(_admins, p);
  };
  func delete_admin( p : Principal ) : () {
    _admins := Principal.Set.delete(_admins, t);
  };
  func set_admins_from_array( pa : [Principal] ) : () {
    _admins := Principal.Set.fromArray(pa);
  };
  func http_process_directory( dir : Directory, cwd : Path ) : Http.Response {
    var html : Text = Html.html_w_header(cwd);
    let dotdot : Text = Path.to_url(Path.dirname(cwd), _self);
    let href_buffer = Buffer.Buffer<Text>(dir.contents.size());
    href_buffer.add( Html.href(dotdot, "[BACK]..") );
    for ( ref in dir.contents.vals() ){
      let url : Text = Path.to_url(Path.join(cwd, ref.name), _self);
      let href : Text = Html.href(url, ref.name);
      href_buffer.add(href);
    };
    let body : Text = Text.join("", href_buffer.vals());
    html := Html.add_body_elements(html, body);
    let payload : Blob = Text.encodeUtf8(html);
    Http.generic("text/html", payload, null);
  };

  func http_process_video( file : File, cwd : Path ) : Http.Response {
    var html : Text = Html.html_w_header(cwd);
    let body_buffer : Buffer.Buffer<Text> = Buffer.Buffer(0);
    let back_element : Text = Html.href(Path.to_url(Path.dirname(cwd), _self), "[BACK]..");
    let video_url : Text = Path.to_url(cwd #"/?embed", _self);
    let video_element : Text = Html.video_element(video_url, file.ftype, null, null);
    body_buffer.add(back_element);
    body_buffer.add(video_element);
    html := Html.add_body_elements(html, Text.join("", body_buffer.vals()));
    Http.generic("text/html", Text.encodeUtf8(html), null);
  };
  func add_disbursement( disbursement : Disbursement ) : () {
    _disbursements := DQ.pushFront<Disbursement>(_disbursements, disbursement);
  };
  func next_disbursement() : ?Disbursement {
    switch( DQ.popBack<Disbursement>(_disbursements) ){
      case( null ){ null };
      case( ?(dq, val) ){ 
        _disbursements := dq;
        ?val;
      };
    };
  };
  func transfer_token( s : AccountIdentifier, r : AccountIdentifier, ti : TokenIndex ) : () {
    remove_owner_tokens( s, [ti] );
    add_owner_tokens( r, [ti] );
    set_token_owner( ti, r );
    set_token_operators( ti, [] );
   };
  func next_token_id() : TokenIndex {
    let output : Nat32 = _next_token_id;
    _next_token_id += 1;
    return output;
  };
  func is_token_owner( ai : AccountIdentifier, ti: TokenIndex ) : Bool {
    switch( get_token_owner( ti ) ){
      case(?owner){ return AID.equal(ai, owner) };
      case(null){ return false };
    };
  };
  func is_token_locked( ti : TokenIndex ) : ?Bool {
    switch(get_token_lock(ti)){
      case(?lock_variant){switch(lock_variant){
        case(#Unlocked){return ?false};
        case(_){return ?true}}};
      case(null){return null};
    };
  };
  func nat_to_subaccount( n : Nat ) : SubAccount {
    let n_byte = func(i : Nat) : Nat8 {
      assert(i < 32);
      let shift : Nat = 8 * (32 - 1 - i);
      Nat8.fromIntWrap(n / 2**shift)
    };
    Array.tabulate<Nat8>(32, n_byte)
  };
  func get_next_subaccount() : SubAccount {
    let sa : Nat = _next_subaccount;
    let sa_offset : Nat = 4294967296;
    _next_subaccount += 1;
    nat_to_subaccount( sa_offeset + sa );
  };
  func lock_token( request : LockRequest ) : () {
    set_token_lock( request.token, request.lock );
    add_locked_token({
      token = request.token;
      time = Time.now();
      ttl = request.ttl;
    });
  };
  func release_expired_locks() : () {
    let (expired, filtered) : ([LockRecord], LockHistory) = LH.filter_expired(_locked_tokens);
    var temp : LockHistory = filtered;
    for ( record in expired.vals() ){ 
      switch( get_token_lock(record.token) ){
        case( null ){};
        case( ?lv ){
          switch( lv ){
            case( #Frozen ){ temp := LH.add_lock(_locked_tokens, record) };
            case(_){ set_token_lock(record.token, #Unlocked) };
      }}}};
    _locked_tokens := temp;
  };

};