import Nat "mo:base/Nat";
import Char "mo:base/Char";
import Iter "mo:base/Iter";
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Result "mo:base/Result";
import Blob "mo:base/Blob";
import Debug "mo:base/Debug";
import Option "mo:base/Option";
import Nat64 "mo:base/Nat64";
import Int "mo:base/Int";
import SHA224 "../../../Motley-Base/src/encoding/sha224";
import Hex "../../../Motley-Base/src/encoding/Hex";
import Cycles "mo:base/ExperimentalCycles";
import FSTypes "../../../Motley-Base/src/asset/Types";
import Filesystem "../../../Motley-Base/src/asset/Filesystem";
import Http "../../../Motley-Base/src/asset/Http";
import HB "../../../Motley-Base/src/heartbeat/Types";
import Time "../../../Motley-Base/src/base/Time";
import Path "../../../Motley-Base/src/asset/Path";
import Text "../../../Motley-Base/src/base/Text";
import AccountId "../../../Motley-Base/src/base/AccountId";
import Principal "../../../Motley-Base/src/base/Principal";
import Ext "../../../Motley-Base/src/nft/ext/Core";
import Index "../../../Motley-Base/src/base/Index";
import Tokens "../../../Motley-Base/src/nft/Tokens";
import Owners "../../../Motley-Base/src/nft/Owners";
import Market "../../../Motley-Base/src/nft/Markets/MarketV4";
import TokenId "../../../Motley-Base/src/nft/TokenId";

shared ({ caller = _installer }) actor class NFT_Registry() = this {

  // =============================================================== //
  // Type Definitions                                                // 
  // =============================================================== //

  type FileshareService = FSTypes.FileshareService;
  type Metadata = Ext.Metadata;
  type Balance = Ext.Balance;
  type CommonError = Ext.CommonError;
  type TransferError = Ext.TransferError;
  type TransferRequest = Ext.TransferRequest;
  type BulkTransferRequest = Ext.BulkTransferRequest;
  type BalanceRequest = Ext.BalanceRequest;
  type ListRequest = Ext.ListRequest;
  type TokenIndex = Ext.TokenIndex;
  type Allowance = Market.Allowance;
  type Price = Market.Price;
  type AccountId = AccountId.AccountId;
  type SubAccount = AccountId.SubAccount;
  type TokenId = TokenId.TokenId;
  type Transaction = Market.Transaction;
  type Lock = Market.SharedLock;
  type Mount = FSTypes.Mount;
  type HeartbeatService = HB.HeartbeatService;
  type Disbursement = Market.Disbursement;
  type Listing = Market.SharedListing;
  type Market = Market.Market;
  type Tokens = Tokens.Tokens;
  type Owners = Owners.Owners;
  type Path = Path.Path;
  type Index = Index.Index;
  type Inode = Filesystem.Inode;
  type Filesystem = Filesystem.Filesystem;

  type StableLock = {
    firesale   : Bool;
    seller     : Principal;
    buyer      : AccountId;
    subaccount : SubAccount;
    price      : Nat64;
    status : { #idle; #busy };
    fees : [(AccountId,Nat64)];
  };

  type InitConfig = {
    minter : Principal;
    base_fee : Nat64;
    max_fee : Nat64;
    royalty_address : AccountId;
    initial_supply : Nat;
    heartbeat : Principal;
    fileshare : Principal;
    mountpath : Text;
    admins : [Principal];
    markets : [AccountId];
    firesale_threshold : Nat;
  };

  type MarketListRequest = {
    token : TokenId;
    price : ?Price;
    allowance : Allowance;
    from_subaccount : ?SubAccount;
  };

  type MarketLockRequest = {
    token : TokenId;
    price : Nat64;
    buyer : AccountId;
    subaccount : SubAccount;
    fees : [(AccountId,Nat64)];
  };

  // Mapped type should always be a CanisterId ( i.e Principal )
  type FungibleToken = {
    #icp : Principal;
  };

  // Mapped type should always be a CanisterId ( i.e Principal )
  type NonFungibleToken = {
    #ext : Principal;
  };

  type Ledger = {
    #cycles;
    #token : FungibleToken;
    #nft : NonFungibleToken;
  };

  type Fee = {
    to : AccountId;
    amount : Nat64;
    txhash : TxHash;
  };

  type TxHash = Text;

  type SubEvent = {
    #bid;
    #none;
    #listed;
    #locked;
    #unlocked;
    #settled;
    #disbursed; 
    #refunded;
  };

  type TokenAttributes = {
    index : Index;
    attributes : ?Blob;
  };

  type Event = {
    #mint;
    #burn;
    #sale;
    #auction;
    #transfer;
    #application;
  };

  type LedgerTxn = {
    ledger : Ledger;
    event : Event;
    subevent : SubEvent;
    time : Int;
    txhash : TxHash;
    indices : ?[Nat];
    source : ?AccountId;
    destination : ?AccountId;
    amount : ?Nat64;
    fees : ?[Fee];
    txref : ?TxHash;
    memo : ?Blob;
  };

  public type Return<X,Y> = { #ok : X; #err : Y };

  /// Ext Types

  // =============================================================== //
  // Stable Memory                                                   //
  // =============================================================== //
  stable var _lastbeat      : Text           = "";
  stable var _hb_enable     : Bool           = false;
  stable var _init          : Bool           = false;
  stable var _path          : Path           = Path.Root;
  stable var _mount         : Filesystem     = Filesystem.empty();
  stable var _tokens        : Tokens         = Tokens.init(500);
  stable var _owners        : Owners         = Owners.init();
  stable var _market        : Market         = Market.stage();
  stable var _pub_queries   : Text.Set       = Text.Set.init();
  stable var _coll_queries  : Text.Set       = Text.Set.init();
  stable var _priv_queries  : Text.Set       = Text.Set.init();
  stable var _admins        : Principal.Set  = Principal.Set.init();
  stable var _collaborators : Principal.Set  = Principal.Set.init();
  stable var _affiliates    : Text.Set       = Text.Set.init();
  stable var _self          : Principal      = Principal.placeholder();
  stable var _heartbeat     : Principal      = Principal.placeholder();
  stable var _fileshare     : Principal      = Principal.placeholder();
  stable var _minter        : Principal      = Principal.placeholder();
  stable var _ledger_txns   : [LedgerTxn]    = [];
  stable var _revealed      : Bool           = false;
  stable var _lastUpdate    : Time.Time      = 0;
  stable var _attributes    : [var ?Blob]    = Array.init(500, null);
  stable var _minters       : Principal.Set  = Principal.Set.init();
  stable var _minter_assets : Principal.Tree<Text> = Principal.Tree.init<Text>();

  // =============================================================== //
  // Public Registry Interface                                       //
  // =============================================================== //
  //
  public query func lastbeat() : async Text { _lastbeat };

  public query func fileshare() : async Principal { _fileshare };

  public query func lastUpdate() : async Time.Time { _lastUpdate };

  public query func supply( tid : TokenId ) : async Return<Balance,CommonError> {
    #ok( Tokens.supply( _tokens ) )
  };

  public query func affiliates() : async [AccountId] { Text.Set.toArray(_affiliates) };

  public query func extensions() : async [Ext.Extension] { ["@ext/common","@ext/nonfungible"] };

  public query func transactions() : async [Transaction] { Market.transactions( _market ) };

  public query func getTokenId( t : Index ) : async TokenId { Market.tokenid(_market, t) };

  public shared query ({caller}) func locks() : async [(Index,Lock)] { 
    assert _is_admin(caller);
    Market.locks(_market)
  };

  public shared query ({caller}) func getDisbursements() : async [Disbursement] {
    assert _is_admin(caller);
    Market.query_disbursements(_market)
  };

  public query func tokens( aid : AccountId ) : async Return<[TokenIndex],CommonError> {
    let owner_tokens = Owners.get_tokens(_owners, aid);
    if ( owner_tokens.size() == 0 ) #err( #Other("No tokens"))
    else #ok( Array.map<Index,TokenIndex>(owner_tokens, Nat32.fromNat) )
  };

  public query func getRegistry() : async [(TokenIndex,AccountId)] {
    Array.map<(Index,AccountId),(TokenIndex,AccountId)>(
      Tokens.map_owners( _tokens ), func (x) = (Nat32.fromNat(x.0), x.1) )
  };

  public query func getTokens() : async [(TokenIndex,Metadata)] { 
    Array.tabulate<(TokenIndex,Metadata)>(Tokens.supply( _tokens ), func(i) = (
      Nat32.fromNat(i),
      #nonfungible( { metadata = _attributes[i] } )
    ))
  };

  public query func balance( request : Ext.BalanceRequest ) : async Return<Nat,CommonError> {
    switch( _index_valid_tokens( [request.token] ) ){
      case ( #ok indices ) _balance(request.user, indices[0]);
      case ( #err val ) #err val
    }
  };

  public query func bearer( tokenid : TokenId ) : async Return<AccountId,CommonError> {
    switch( _index_valid_tokens( [tokenid] ) ){
      case ( #ok indices ) #ok( Tokens.get_owner(_tokens, indices[0]) );
      case ( #err val ) #err val
    }
  };

  public query func tokens_ext( aid : AccountId ) : async Return<[(TokenIndex,?Listing,?Blob)],CommonError> {
    #ok(
      Array.map<Index,(TokenIndex,?Listing,?Blob)>(
        Owners.get_tokens(_owners, aid), func(x) = (
          Nat32.fromNat(x),
          Market.getOpt_listing(_market, x),
          null
        )
      )
    )
  };

  public query func metadata( tokenid : TokenId ) : async Return<Metadata,CommonError> {
    switch( _index_valid_tokens( [tokenid] ) ){
      case ( #err val ) #err val;
      case ( #ok tokens ){
        assert tokens.size() == 1;
        #ok( #nonfungible( { metadata = _attributes[tokens[0]] } ) )
      }
    }
  };

  public query func details( tokenid : TokenId ) : async Return<(AccountId,?Listing),CommonError> {
    switch( _index_valid_tokens( [tokenid] ) ){
      case ( #err val ) #err val;
      case ( #ok tokens ){
        assert tokens.size() == 1;
        #ok((
          Tokens.get_owner(_tokens, tokens[0]),
          Market.getOpt_listing(_market, tokens[0])
        ));
      }
    }
  };

  public shared ({caller}) func check_listing() : async Bool {
    assert _is_admin(caller);
    Market.is_listed(_market, 360);
  };

  public shared ({caller}) func transfer( request : TransferRequest ) : async Return<Balance,TransferError> {
    if ( request.amount != 1) return #err( #Other("must use amount of 1") );
    // if ( request.notify ) return #err(#Rejected);
    let tindex : Index = Nat32.toNat(TokenId.index(request.token));
    let sender : AccountId = AccountId.fromPrincipal(caller, request.subaccount);
    if ( Market.is_listed(_market, tindex) ) return #err(#Other("Token is listed for sale!"));
    if ( not Tokens.is_owner(_tokens, tindex, sender) ) return #err(#Unauthorized(sender));
    switch( request.to ){
      case ( #principal _ ){};
      case ( #address addr ){
        if ( not AccountId.valid(addr) ){
          return #err(#Other("Invalid destination address"))
        }
      }
    };
    await _transfer([request.token], caller, request.subaccount, request.to, request.notify, request.memo, #single)
  };

  public shared ({caller}) func transferBulk( request : BulkTransferRequest ) : async Return<Balance,TransferError> {
    assert ( request.tokens.size() > 0 );
    if ( request.amount != request.tokens.size() ) return #err( #Other("Wrong amount requested") );
    if ( request.notify ) return #err(#Rejected);
    switch( request.to ){
      case ( #principal _ ){};
      case ( #address addr ){
        if ( not AccountId.valid(addr) ){
          return #err(#Other("Invalid destination address"))
        }
      }
    };
    await _transfer(request.tokens, caller, request.subaccount, request.to, request.notify, request.memo, #bulk)
  };

  // =============================================================== //
  // Marketplace Methods                                             //
  // =============================================================== //
  //
  public query func settlements() : async [(TokenIndex, AccountId, Nat64)] {
    Array.map<(Index,Lock),(TokenIndex,AccountId,Nat64)>(
      Market.locks(_market), func(x) = (
        Nat32.fromNat(x.0),
        AccountId.fromPrincipal(Market.get_listing(_market, x.0).seller, null),
        Market.get_listing(_market, x.0).price
      )
    )
  };

  public query func allSettlements() : async [(TokenIndex, Ext.Settlement)] {
    Array.map<(Index,Lock),(TokenIndex, Ext.Settlement)>(
      Market.locks(_market), func(x) = (
        Nat32.fromNat(x.0),
        {
          buyer = Option.get(x.1.buyer, AccountId.fromPrincipal(Principal.placeholder(), null));
          subaccount = Option.get<SubAccount>(x.1.subaccount, AccountId.SUBACCOUNT_ZERO);
          seller = Market.get_listing(_market, x.0).seller;
          price = Market.get_listing(_market, x.0).price;
        }
      )
    )
  };

  public query func listings() : async [(TokenIndex, Ext.Listing, Ext.Metadata)] {
    Array.map<(Index,Listing),(TokenIndex,Ext.Listing,Ext.Metadata)>(
      Market.listings(_market), func(x) = (
        Nat32.fromNat(x.0),
        { seller = x.1.seller; price = x.1.price; locked = x.1.locked },
        #nonfungible({ metadata = _attributes[x.0] })
      )
    )
  };

  type Attributes = { firesale : Bool };

  public query func market_listings() : async [(TokenIndex, Listing, Attributes, Ext.Metadata)] {
    Array.map<(Index,Listing),(TokenIndex,Listing, Attributes, Ext.Metadata)>(
      Market.listings(_market), func(x) = (
        Nat32.fromNat(x.0),
        x.1,
        { firesale = Market.active_firesale(_market, x.0) },
        #nonfungible({ metadata = _attributes[x.0] })
      )
    )
  };

  public shared ({caller}) func list( request : ListRequest ) : async Return<(),CommonError> {
    _list(request.token, caller, request.from_subaccount, request.price, 1000 );
  };

  public shared ({caller}) func lock(tokenid : TokenId, price : Nat64, address : AccountId, _subaccountNOTUSED : SubAccount ) : async Return<AccountId,CommonError> {
    let fees : [(AccountId,Nat64)] = [( "c7e461041c0c5800a56b64bb7cefc247abc0bbbb99bd46ff71c64e92d9f5c2f9", 1000)]; //Entrepot
    if ( not AccountId.valid( address ) ) return #err(#Other("Invalid destination address"));
    _lock(tokenid, caller, address, price, fees)
  };

  public shared ({caller}) func market_list( request : MarketListRequest ) : async Return<(),CommonError> {
    _list(request.token, caller, request.from_subaccount, request.price, request.allowance );
  };

  public shared ({caller}) func market_lock( request : MarketLockRequest ) : async Return<AccountId,CommonError> {
    for ( (account, fee) in request.fees.vals() ){
      assert AccountId.valid(account) and Text.Set.match(_affiliates, account);
    };
    if ( not AccountId.valid(request.buyer) ) return #err(#Other("Invalid destination address"));
    _lock(request.token, caller, request.buyer, request.price, request.fees)
  };

  public shared ({caller}) func settle(tokenid : TokenId) : async Return<(),CommonError> {
    switch( _index_valid_tokens( [tokenid] ) ){
      case ( #err val ) #err val;
      case ( #ok tokens ){
        assert tokens.size() == 1;
        await _settle( tokens[0], ?caller, false );
      }
    }
  };

  public query func stats() : async (Nat64, Nat64, Nat64, Nat64, Nat, Nat, Nat) {
    let t_transactions : [Transaction] = Market.transactions( _market );
    let t_listings = Array.map<(Index,Listing),(TokenIndex,Ext.Listing)>(
      Market.listings(_market), func(x) = (
        Nat32.fromNat(x.0),
        { seller = x.1.seller; price = x.1.price; locked = x.1.locked }
      )
    );
    var res : (Nat64, Nat64, Nat64) = Array.foldLeft<Transaction, (Nat64, Nat64, Nat64)>(t_transactions, (0,0,0), func (b : (Nat64, Nat64, Nat64), a : Transaction) : (Nat64, Nat64, Nat64) {
      var total : Nat64 = b.0 + a.price;
      var high : Nat64 = b.1;
      var low : Nat64 = b.2;
      if (high == 0 or a.price > high) high := a.price; 
      if (low == 0 or a.price < low) low := a.price; 
      (total, high, low);
    });
    var floor : Nat64 = 0;
    for (a in t_listings.vals() ){
      if (floor == 0 or a.1.price < floor) floor := a.1.price;
    };
    (res.0, res.1, res.2, floor, t_listings.size(), Tokens.supply( _tokens ), t_transactions.size());
  };

  // =============================================================== //
  // Minting Interface                                               //
  // =============================================================== //
  public type MintRequest = {
    receiver : Principal;
    path : Path;
  };

  public shared ({caller}) func mint_nft( request : MintRequest ) : async ?Index {null};

  public shared ({caller}) func test_mint( wallet : Principal ) : async ?Index {
    assert Principal.Set.match(_minters, caller);
    var p : Path = "";
    let receiver : AccountId = AccountId.fromPrincipal(wallet, null);
    var metadata : Tokens.Metadata.Metadata = Tokens.Metadata.init();
    switch ( Principal.Tree.find<Text>(_minter_assets, caller) ){
      case null return null;
      case ( ?path ){
        p := path;
        for ( dentry in Filesystem.root_folder( _mount ).vals() ){
          switch( _walk( path ) ){
            case( null ) return null;
            case( ?inode ){
              switch( inode ){
                case( #Reserved _ ) assert false;
                case( #File _ )();
                case( #Directory dir ){
                  for ( dentry in dir.contents.vals() ){
                    switch( _mount.inodes[dentry.0] ){
                      case( #Reserved _ ) assert false;
                      case( #Directory _ )();
                      case( #File file ){
                        metadata := Tokens.Metadata.insert(metadata, file.name, #stream{
                          name = file.name;
                          ftype = file.ftype;
                          pointer = file.pointer
                        })
          }}}}}}}}}
    };
    let token : Index = Tokens.mint_token(_tokens, receiver, p, metadata);
    _owners := Owners.add_token(_owners, receiver, token);
    let now = Time.now();
    let hbuffer = Buffer.fromArray<Nat8>( Blob.toArray(Principal.toBlob(_self)) );
    hbuffer.append( Buffer.fromArray<Nat8>( Blob.toArray( Text.encodeUtf8(Nat.toText(Int.abs(now)) ))));
    let txhash : Text = Hex.encode(SHA224.sha224(Buffer.toArray<Nat8>(hbuffer)));
    _save_txn_record({
      ledger = #nft( #ext( _self ) );
      event = #mint;
      subevent = #none;
      time = now;
      txhash = txhash;
      indices = ?[token];
      source = null;
      destination = ?receiver;
      amount = null;
      fees = null;
      txref = null;
      memo = null;
    });
    ?token;
  };

  // =============================================================== //
  // Admin Interface                                                 //
  // =============================================================== //
  //
  type TestRegistration = { id : Principal; path : Path };
  public shared query ({caller}) func test_minters() : async [Principal] {
    assert _is_admin(caller);
    Principal.Set.toArray(_minters)
  };
  public shared ({caller}) func test_register_minter( r : TestRegistration ) : async () {
    assert _is_admin(caller) and Path.is_valid( r.path );
    _minters := Principal.Set.insert(_minters, r.id);
    _minter_assets := Principal.Tree.insert<Text>(_minter_assets, r.id, r.path);
  };
  public shared query ({caller}) func minter() : async Principal {
    assert _is_admin(caller);
    _minter
  };
  
  public shared query ({caller}) func admins() : async [Principal] { 
    assert _is_admin(caller);
    Principal.Set.toArray( _admins )
  }; 

  public shared ({caller}) func heartbeat_enable() : async () {
    assert _is_admin(caller);
    _hb_enable := true;
  };

  public shared ({caller}) func heartbeat_disable() : async () {
    assert _is_admin(caller);
    _hb_enable := false;
  };

	public shared ({caller}) func set_minter( p : Principal) : async () {
    assert _is_admin(caller);
    _set_minter(p);
	};

  public shared ({caller}) func set_admins( arr : [Principal] ) : async [Principal] {
    assert _is_admin(caller);
    _admins := Principal.Set.fromArray(arr);
    arr;
  };

  public shared ({caller}) func init( config : InitConfig ) : async Return<(),Market.Error> {
    assert Principal.equal(caller, _installer) and not _init;

    _self := Principal.fromActor(this);
    
    switch( Market.init(
      _market,
      _self,
      config.base_fee,
      config.max_fee,
      config.royalty_address,
      config.initial_supply,
      config.firesale_threshold,
    )){

      case ( #err val ) return #err val;

      case ( #ok ){

        _set_minter( config.minter );
        _set_admins( config.admins );
        _set_heartbeat( config.heartbeat );
        _set_fileshare( config.fileshare );
        _set_mountpath( config.mountpath );
        _set_affiliates( config.markets );

        let heartbeat_svc : HeartbeatService = actor(Principal.toText(_heartbeat));
        try {
          await heartbeat_svc.schedule([
            {interval = HB.Intervals._60beats; tasks = [settle_all]},
            {interval = HB.Intervals._05beats; tasks = [process_disbursements, process_refunds]},
            {interval = HB.Intervals._15beats; tasks = [report_balance]},
          ]);
        } catch (e) {
          return #err(#ConfigError("Failed to schedule heartbeat task"));
        };

        let fileshare_svc : FileshareService = actor(Principal.toText(_fileshare));
        try {
          switch( await fileshare_svc.export( _path, null, null ) ){
            case ( #ok( mount ) ) Filesystem.mount(_mount, mount);
            case ( #err val ) return #err(#ConfigError("Failed to mount remote directory"));
          }
        } catch (e) {
          return #err(#ConfigError("Failed to mount remote directory; service trapped"));
        };

        _hb_enable := true;
        _init := true;
        return #ok();
      }
    }

  };

  public shared ({caller}) func mount( path : Path ) : async Return<(),Market.Error> {
    assert _is_admin(caller);
    let fileshare_svc : FileshareService = actor(Principal.toText(_fileshare));
    try {
      switch( await fileshare_svc.export( path, null, null ) ){
        case ( #err val ) return #err(#ConfigError("Failed to mount remote directory"));
        case ( #ok( mount ) ) #ok( Filesystem.mount(_mount, mount) );
      }
    } catch (e) {
      return #err(#ConfigError("Failed to mount remote directory; service trapped"));
    };
  };

  public shared ({caller}) func add_affiliate( aid : AccountId ) : async () {
    assert _is_admin(caller);
    _set_affiliates([aid]);
  };

  type Keyword = { #wild; #word : Text };

  public shared ({caller}) func update_assets( range : (Nat,Nat), key : Keyword ) : async ?Nat {
    assert _is_admin(caller);
    var count : Nat = 0;
    for ( i in Iter.range(range.0, range.1) ){
      let path = Path.Root # Nat.toText(i);
      if ( not Path.is_valid( path ) ) return null;
      var metadata : Tokens.Metadata.Metadata = Tokens.Metadata.init();
      switch( _walk( path ) ){
        case( null ) return null;
        case( ?inode ){
          switch( inode ){
            case( #Reserved _ ) assert false;
            case( #File _ ) assert false;
            case( #Directory dir ){
              switch( key ){
                case ( #wild ){
                  for ( dentry in dir.contents.vals() ){
                    switch( _mount.inodes[dentry.0] ){
                      case( #Reserved _ ) assert false;
                      case( #Directory _ ) assert false;
                      case( #File file ){
                        Tokens.insert_metadata(_tokens, i-1, file.name, #stream{
                          name = file.name;
                          ftype = file.ftype;
                          pointer = file.pointer
                        });
                        count += 1
                      }
                    }
                  }
                };
                case ( #word keyword ){
                  for ( dentry in dir.contents.vals() ){
                    if ( Text.equal(dentry.2, keyword) ){
                      switch( _mount.inodes[dentry.0] ){
                        case( #Reserved _ ) assert false;
                        case( #Directory _ ) assert false;
                        case( #File file ){
                          Tokens.insert_metadata(_tokens, i-1, file.name, #stream{
                            name = file.name;
                            ftype = file.ftype;
                            pointer = file.pointer
                          });
                          count += 1
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    };
    ?count
  };

  public shared ({caller}) func reschedule() : async Return<(),Market.Error> {
    assert _is_admin( caller );
    let heartbeat_svc : HeartbeatService = actor(Principal.toText(_heartbeat));
    try {
      await heartbeat_svc.schedule([
        {interval = HB.Intervals._30beats; tasks = [settle_all]},
        {interval = HB.Intervals._10beats; tasks = [process_disbursements, process_refunds]},
        {interval = HB.Intervals._15beats; tasks = [report_balance]},
      ]);
    } catch (e) {
      return #err(#ConfigError("Failed to schedule heartbeat task"));
    };
    #ok()
  };

  public shared ({caller}) func update_attributes( attributes : [TokenAttributes] ) : async () {
    assert _is_admin(caller);
    for ( token in attributes.vals() ){
      assert Tokens.is_valid(_tokens, token.index);
      _update_token_attributes(token.index, token.attributes)
    }
  };

  public shared ({caller}) func set_revealed( b : Bool ) : async () {
    assert _is_admin(caller);
    _revealed := b;
  };

  public shared query ({caller}) func admin_query_settlement( i : Index ) : async ?StableLock { 
    assert _is_admin(caller);
    switch( Market.getOpt_listing(_market, i) ){
      case null null;
      case ( ?listing ){
        switch( _market.locks[i] ){
          case ( #unlocked _ ) null;
          case ( #locked lock ){
            return ?{
              firesale = false;
              seller = listing.seller;
              buyer = lock.buyer;
              subaccount = lock.subaccount;
              fees = lock.fees;
              price = listing.price;
              status = lock.status;
            }
          };
          case ( #firesale fs ){
            return ?{
              firesale = true;
              seller = listing.seller;
              price = listing.price;
              buyer = AccountId.fromPrincipal(Principal.placeholder(), null);
              subaccount = [];
              status = fs.status;
              fees = [];
            }
          }
        }
      }
    }
  };

  // =============================================================== //
  // Callback Methods                                                //
  // =============================================================== //
  //
  public shared ({caller}) func report_balance() : () {
    assert Principal.equal(caller, _heartbeat);
    let bal = Cycles.balance();
    let hbsvc : HB.HeartbeatService = actor(Principal.toText(_heartbeat));
    hbsvc.report_balance({balance = bal; transfer = acceptCycles});
  };

  public func acceptCycles() : async () {
    let available = Cycles.available();
    let accepted = Cycles.accept(available);
    assert (accepted == available);
  };

  public shared ({caller}) func process_disbursements() : () {
    assert Principal.equal(caller, _heartbeat);
    if _hb_enable ignore Market.disburse( _market );
  };

  public shared ({caller}) func process_refunds() : () {
    assert Principal.equal(caller, _heartbeat);
    if _hb_enable ignore Market.refund( _market );
  };

  public shared ({caller}) func settle_all() : () {
    assert Principal.equal(caller, _heartbeat);
    _lastbeat := Time.Datetime.now();
    if _hb_enable {
      for ( (token,lock) in Market.locks(_market).vals() ){
        switch( lock.status ){
          case ( #idle ) ignore _settle(token, null, false);
          case _ ();
        }
      }
    }
  };

	public query func license(tokenid : TokenId) : async Result.Result<Text, CommonError> {
    #ok( "On the basis that seller royalty fees are paid the owner of an NFT in the Gen2 pokedbot “mutant army” collection has an exclusive right to display and trade the artwork and to utilise any playable characters generated from the source 3D files. They can display and print the artworks and 3D models for personal use. The artwork can be used for promotional purposes by pokedstudio. All copyright in the pokedbots collections belongs to pokedstudio." );
  };

  // =============================================================== //
  // HTTP Interface                                                  //
  // =============================================================== //
  public query func http_request( request : Http.Request ) : async Http.Response {
    var keyword : Text = "";
    switch( _getParam( request.url, "tokenid" ) ){
      case null _http_market_stats();
      case ( ?tokenid ){
        let index : Index = Nat32.toNat(TokenId.index(tokenid));
        switch( _getParam( request.url, "type" ) ){
          case null {
            if ( not _revealed ) keyword := "PRE_REVEAL"
            else keyword := "VIDEO";
            _http_process_metadata(index, keyword);
          };
          case ( ?t ){
            if ( Text.equal(t, "thumbnail") ){
              if ( not _revealed ) keyword := "PRE_REVEAL_THUMB"
              // else keyword := "THUMB";
              else keyword := "IMAGE";
              _http_process_metadata(index, keyword);
            } else if ( Text.equal(t, "gif") ) {
              keyword := "GIF";
              _http_process_metadata(index, keyword);
            } else if ( Text.equal(t, "thumbnail2") ) {
              keyword := "THUMB";
              _http_process_metadata(index, keyword);
            } else { Http.NOT_FOUND() };
          }
        }
      }
    }
  };

  // =============================================================== //
  // Private Methods                                                 //
  // =============================================================== //
  //
  func _set_minter( p : Principal ) : () { _minter := p };
  func _set_heartbeat( p : Principal ) : () { _heartbeat := p };
  func _set_fileshare( p : Principal ) : () { _fileshare := p };
  func _set_mountpath( p : Text ) : () { _path := p };
  func _set_affiliates( arr : [AccountId] ) : () {
    for ( address in arr.vals() ){
      if ( AccountId.valid(address) ) _affiliates := Text.Set.insert(_affiliates, address)
    }
  };
  func _update_token_attributes( i : Index, b : ?Blob ) : () {
    _attributes[i] := b;
  };
  func _is_admin( p : Principal ) : Bool {
    Principal.Set.match(_admins, p);
  };
  func _set_admins( pa : [Principal] ) : () {
    _admins := Principal.Set.fromArray( pa );
  };
  func _balance( u : Ext.User, i : Index ) : Return<Nat,CommonError> {
    let wallet : AccountId = Ext.User.toAID( u );
    if ( Tokens.is_owner(_tokens, i, wallet ) ) #ok 1
    else #ok 0
  };
  func _walk( p : Path ) : ?Inode {
    switch( Filesystem.walk(_mount, p, _self) ){
      case ( #ok inode ) ?inode;
      case ( #err val ) null
    }
  };
  func _transfer(

    tokens : [TokenId],
    from : Principal,
    sa : ?SubAccount,
    to : Ext.User,
    notify : Bool,
    memo : Blob,
    strategy : { #single; #bulk }

  ) : async Return<Balance,TransferError> {

    let receiver = Ext.User.toAID( to );
    let sender : AccountId = AccountId.fromPrincipal(from, sa);
    switch( _index_owner_tokens(tokens, sender) ){
      case ( #err _ ) return #err( #Unauthorized( sender ) );
      case ( #ok tokens ){
        switch( _are_tokens_listed(tokens) ){
          case ( #err _ ) return #err( #Other("Token is listed for sale!"));
          case ( #ok _ ){
            switch( _are_tokens_locked(tokens) ){
              case ( #err _ ) return #err( #Other("Token is locked") );
              case ( #ok _ ){
                var accepted : ?Balance = ?1;
                if notify {
                  switch( Ext.User.toPrincipal( to ) ){
                    case null return #err(#CannotNotify(receiver));
                    case ( ?canisterId ){
                      for ( token in tokens.vals() ) Tokens.lock(_tokens, token);
                      switch( strategy ){
                        case ( #single ) accepted := await _notify_transfer(canisterId, tokens[0], #address(sender), 1, memo);
                        case ( #bulk ) accepted := await _notify_bulk_transfer(canisterId, tokens, #address(sender), tokens.size(), memo)
                      };
                      for ( token in tokens.vals() ) Tokens.unlock(_tokens, token);
                    }
                  }
                };
                switch( accepted ){
                  case null return #err(#Rejected);
                  case ( ?bal ){
                    if ( bal != tokens.size() ) return #err(#Rejected);
                    for ( token in tokens.vals() ){
                      _owners := Owners.remove_token(_owners, sender, token);
                      _owners := Owners.add_token(_owners, receiver, token);
                      Tokens.set_owner(_tokens, token, receiver);
                      let now = Time.now();
                      let hbuffer = Buffer.fromArray<Nat8>( Blob.toArray(Principal.toBlob(_self)) );
                      hbuffer.append( Buffer.fromArray<Nat8>( Blob.toArray( Text.encodeUtf8(Nat.toText(Int.abs(now)) ))));
                      let txhash : Text = Hex.encode(SHA224.sha224(Buffer.toArray<Nat8>(hbuffer)));
                      _save_txn_record({
                        ledger = #nft( #ext( _self ) );
                        event = #transfer;
                        subevent = #none;
                        time = now;
                        txhash = txhash;
                        indices = ?tokens;
                        source = ?sender;
                        destination = ?receiver;
                        amount = null;
                        fees = null;
                        txref = null;
                        memo = null;
                      });
                    }
                  }
                };
        }}}}}};
    _lastUpdate := Time.now();
    #ok(tokens.size())
  };
  func _list( tokenid : TokenId, c : Principal, sa : ?SubAccount, p : ?Price, a : Allowance ) : Return<(),CommonError> {
    let owner : AccountId = AccountId.fromPrincipal(c, sa);
    switch( _index_owner_tokens([tokenid], owner) ){
      case ( #err val ){
        switch( val ){
          case ( #Unauthorized _ ) #err( #Other("Not Authorized") );
          case _ #err( #InvalidToken( tokenid ) );
        }
      };
      case ( #ok tokens ){
        assert tokens.size() == 1;
        switch( _are_tokens_locked( tokens ) ){
          case( #err val ) #err( #Other("Listing is locked"));
          case( #ok _ ){
            switch( p ){
              case ( ?price ){
                switch( Market.list(_market, tokens[0], c, price, a) ){
                  case ( #ok ) #ok();
                  case ( #err val ){
                    switch val {
                      case ( #FeeTooHigh allowed ) #err( #Other("Seller allowance exceeds threshold"));
                      case ( #FeeTooSmall minimum ) #err( #Other("Seller allowance does not meet minimum"));
                      case ( #Locked ) #err( #Other("Listing is locked"));
                      case _ #err( #Other("Canister rejected list request"));
                    }
                  }
                }
              };
              case null { 
                switch( Market.delist(_market, tokens[0]) ){
                  case ( #ok ) #ok();
                  case ( #err val ){
                    switch val {
                      case ( #Locked ) #err( #Other("Listing is locked") );
                      case ( #DelistingRequested ) #err( #Other("Active fire sale; delisting requested but not guaranteed"));
                      case _ #err( #Other("Canister rejected delist request"));
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  };
  func _lock( tokenid : TokenId, c : Principal, b : AccountId, p : Nat64, f : [(AccountId,Nat64)] ) : Return<AccountId,CommonError> {
    switch( _index_valid_tokens( [tokenid] ) ){
      case ( #err val ) #err val;
      case ( #ok tokens ){
        assert tokens.size() == 1;
        switch( Market.lock(_market, tokens[0], c, b, p, f) ){
          case ( #ok payment_address ){
            Tokens.lock(_tokens, tokens[0]);
            #ok( payment_address )
          };
          case ( #err val ){
            switch val {
              case ( #PriceChange _ ) #err( #Other("Price has changed") );
              case ( #NoListing ) #err( #Other("No Listing!") );
              case ( #Locked ) #err( #Other("Listing is locked") );
              case ( #Busy ) #err( #Other("Pending sale") );
              case _ #err( #Other("System Fault") )
            }
          }
        }
      }
    }
  };
  func _settle( token : Index, caller : ?Principal, bypass : Bool ) : async Return<(),CommonError> {
    switch( await Market.settle(_market, token, caller, bypass) ){
      case ( #ok receiver ){
        Tokens.unlock(_tokens, token);
        let sender = Tokens.get_owner(_tokens, token);
        _owners := Owners.remove_token(_owners, sender, token);
        _owners := Owners.add_token(_owners, receiver, token);
        Tokens.set_owner(_tokens, token, receiver);
        #ok()
      };
      case ( #err val ){
        switch( val ){
          case ( #InsufficientFunds) #err( #Other("Insufficient Funds Sent") );
          case _ #err( #Other("Nothing to settle") )
        }
      }
    }
  };
  func _notify_transfer( receiver : Principal, token : Index, from : Ext.User, amount : Nat, memo : Blob ) : async ?Balance {
    let notifyFn : Ext.NotifyService = actor(Principal.toText(receiver));
    let tid : TokenId = TokenId.fromPrincipal(_self, Nat32.fromNat(token));
    try await notifyFn.tokenTransferNotification(tid, from, amount, memo)
    catch (e) null;
  };
  func _notify_bulk_transfer( receiver : Principal, tokens : [Index], from : Ext.User, amount : Nat, memo : Blob ) : async ?Balance {
    let notifyFn : Ext.BulkNotifyService = actor(Principal.toText(receiver));
    let tids : [TokenId] = Array.map<Index,TokenId>(tokens, func(x) = TokenId.fromPrincipal(_self, Nat32.fromNat(x)));
    try await notifyFn.bulkTokenTransferNotification(tids, from, amount, memo)
    catch (e) null;
  };
  func _http_process_metadata(  i : Index, key : Text ) : Http.Response {
    switch( Tokens.query_metadata(_tokens, i, key)){
      case ( #blob _ ) Http.NOT_FOUND();
      case ( #url _ ) Http.NOT_FOUND();
      case ( #none ) Http.NOT_FOUND();
      case ( #stream file ) Http.generic(
        file.ftype,
        Blob.fromArray([]),
        ?#Callback(file.pointer)
      )
    }
  };
  func _http_market_stats() : Http.Response {
    let supply : Nat = Tokens.supply( _tokens );
    let stats : Market.Statistics = Market.stats( _market );
    let cycles_balance : Nat = Cycles.balance() / 1000000000000;
    let display : Text = 
        "Cycle Balance:                            ~" # debug_show ( cycles_balance ) # "T\n" #
        "Minted NFTs:                              " # debug_show ( supply ) # "\n" #
        "Marketplace Listings:                     " # debug_show ( stats.listings ) # "\n" #
        "Sold via Marketplace:                     " # debug_show ( stats.transactions ) # "\n" #
        "Sold via Marketplace in ICP:              " # _displayICP( stats.volume ) # "\n" #
        "Average Price ICP Via Marketplace:        " # _displayICP( stats.average ) # "\n" #
        "Admin:                                    " # debug_show (_minter) # "\n";
    return {
      status_code = 200;
      headers = [("content-type", "text/plain")];
      body = Text.encodeUtf8 ( display );
      streaming_strategy = null
    }
  };
  func _displayICP(amount : Nat64) : Text {
    let amt : Nat = Nat64.toNat(amount);
    debug_show(amt/100000000) # "." # debug_show ((amt%100000000)/1000000) # " ICP";
  };
  func _index_valid_tokens( tids : [TokenId] ) : Return<[Index],CommonError> {
    Array.mapResult<TokenId, Index, CommonError>(tids,
      func (x) : Return<Index,CommonError> {
        let index : Index = Nat32.toNat( TokenId.index( x ) );
        if ( not TokenId.isPrincipal(x, _self) ) #err( #InvalidToken( x ) )
        else if ( not Tokens.is_valid(_tokens, index) ) #err( #InvalidToken( x ) )
        else #ok( index )
      }
    )
  };
  func _index_owner_tokens( tokens : [TokenId], owner : AccountId ) : Return<[Index],TransferError> {
    Array.mapResult<TokenId, Index, Ext.TransferError>(tokens,
      func (x) : Return<Index,TransferError> {
        let index : Index = Nat32.toNat( TokenId.index( x ) );
        if ( not TokenId.isPrincipal(x, _self) ) #err( #InvalidToken( x ) )
        else if ( not Tokens.is_valid(_tokens, index) ) #err( #InvalidToken( x ) )
        else if ( not Tokens.is_owner(_tokens, index, owner) ) #err( #Unauthorized( owner ) )
        else #ok( index )
      }
    )
  };
  func _are_tokens_listed( tokens : [Index] ) : Return<[Index],CommonError> {
    for ( token in tokens.vals() ){
      if (Market.is_locked(_market, token) ) return #err( #Other("Token is listed for"));
    };
    #ok( tokens );
    // Array.mapResult<Index, Index, CommonError>(tokens,
    //   func(x) : Return<Index,CommonError> {
    //     if ( Market.is_locked(_market, x) ){
    //       #err( #Other("Token is listed for sale!") )
    //     } else #ok( x )
    //   }
    // )
  };
  func _are_tokens_locked( tokens : [Index] ) : Return<[Index],CommonError> {
    Array.mapResult<Index, Index, CommonError>(tokens,
      func(x) : Return<Index,CommonError> {
        if ( Market.is_locked(_market, x) or Tokens.is_locked(_tokens, x) ){
          #err( #Other("Token is locked") );
        } else #ok( x )
      }
    )
  };
  func nat_to_subaccount( n : Nat ) : SubAccount {
    let n_byte = func(i : Nat) : Nat8 {
      assert(i < 32);
      let shift : Nat = 8 * (32 - 1 - i);
      Nat8.fromIntWrap(n / 2**shift)
    };
    Array.tabulate<Nat8>(32, n_byte)
  };
  func textToNat( txt : Text) : Nat {
    assert(txt.size() > 0);
    let chars = txt.chars();
    var num : Nat = 0;
    for (v in chars){
      let charToNum = Nat32.toNat(Char.toNat32(v)-48);
      assert(charToNum >= 0 and charToNum <= 9);
      num := num * 10 +  charToNum;          
    };
    num;
  };

  func _save_txn_record( txn : LedgerTxn ) : () {
    let buffer = Buffer.fromArray<LedgerTxn>(_ledger_txns);
    buffer.add( txn );
    _ledger_txns := Buffer.toArray(buffer);
  };

  func _getParam(url : Text, param : Text) : ?Text {
    var _s : Text = url;
    Iter.iterate<Text>(Text.split(_s, #text("/")), func(x, _i) {
      _s := x;
    });
    Iter.iterate<Text>(Text.split(_s, #text("?")), func(x, _i) {
      if (_i == 1) _s := x;
    });
    var t : ?Text = null;
    var found : Bool = false;
    Iter.iterate<Text>(Text.split(_s, #text("&")), func(x, _i) {
      if (found == false) {
        Iter.iterate<Text>(Text.split(x, #text("=")), func(y, _ii) {
          if (_ii == 0) {
            if (Text.equal(y, param)) found := true;
          } else if (found == true) t := ?y;
        });
      };
    });
    return t;
  };

};