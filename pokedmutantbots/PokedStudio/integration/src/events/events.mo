import T "Types";
import Nat "mo:base/Nat";
import Iter "mo:base/Iter";
import Blob "mo:base/Blob";
import Nat32 "mo:base/Nat32";
import Deque "mo:base/Deque";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Option "mo:base/Option";
import HB "../../../../Motley-Base/src/heartbeat/Types";
import Time "../../../../Motley-Base/src/base/Time";
import Ext "../../../../Motley-Base/src/nft/ext/Core";
import Text "../../../../Motley-Base/src/base/Text";
import Index "../../../../Motley-Base/src/base/Index";
import Random "../../../../Motley-Base/src/base/Random";
import Principal "../../../../Motley-Base/src/base/Principal";
import History "../../../../Motley-Base/src/nft/swap/History";
import SBuffer "../../../../Motley-Base/src/base/StableBuffer";
import AID "../../../../Motley-Base/src/nft/ext/util/AccountIdentifier";

shared ({caller = _installer }) actor class ExtSwap() = this {

  /// TYPE DECLARATIONS
  type User = Ext.User;
  type Memo = Ext.Memo;
  type Index = Index.Index;
  type Credits = T.Credits;
  type Request = T.Request;
  type Balance = Ext.Balance;
  type Category = T.Category;
  type BurnReqs = T.BurnReqs;
  type Event = History.Event;
  type Snapshot = T.Snapshot;
  type Return<T> = T.Return<T>;
  type Inventory = T.Inventory;
  type Whitelist = T.Whitelist;
  type Entropy = Random.Entropy;
  type History = History.History;
  type Candidates = T.Candidates;
  type TokenState = T.TokenState;
  type SnapshotSvc = T.SnapshotSvc;
  type TokenIndex = Ext.TokenIndex;
  type BurnRequest = T.BurnRequest;
  type ServiceState = T.ServiceState;
  type RequestStatus = T.RequestStatus;
  type Configuration = T.Configuration;
  type StableCredits = T.StableCredits;
  type SharedRequest = T.SharedRequest;
  type ClaimRequest = T.ClaimRequest;
  type WhitelistEntry = T.WhitelistEntry;
  type StableWhitelist = T.StableWhitelist;
  type BurnInstruction = T.BurnInstruction;
  type SBuffer<X> = SBuffer.StableBuffer<X>;
  type TokenIdentifier = Ext.TokenIdentifier;
  type AccountIdentifier = Ext.AccountIdentifier;
  type StableWhitelistEntry = T.StableWhitelistEntry;
  type ConfigActivity = { #active; #inactive };
  type SwapRegistry = Text.Tree<TokenIdentifier>;
  type Holdings = Text.Tree<[TokenIndex]>;
  type Requests = SBuffer<Request>;
  type SharedHistory = History.SharedHistory;

  type TestBackup = {
    burn_registry : Principal;
    registry : Principal;
    inventory : [[TokenIdentifier]];
    holdings : Holdings;
    candidates : Candidates;
    whitelist : StableWhitelist;
  };

  /// PERSISTENT STATE
  stable var _history : History       = History.init();
  stable var _entropy : Entropy       = Random.Entropy.init(50);
  stable var _admins  : Principal.Set = Principal.Set.init();
  stable var _self    : Principal     = Principal.placeholder();

  /// TRANSIENT STATE
  stable var _requirements    : BurnReqs       = [];
  stable var _operational     : Bool           = false;
  stable var _config_activity : ConfigActivity = #inactive;
  stable var _event           : ServiceState   = #inactive;
  stable var _inventory       : Inventory      = Array.init(5,[]);
  stable var _registry        : Principal      = Principal.placeholder();
  stable var _snapshot        : Principal      = Principal.placeholder();
  stable var _burn_registry   : Principal      = Principal.placeholder();
  stable var _whitelist       : Whitelist      = Text.Tree.init<Credits>();
  stable var _candidates      : Candidates     = Text.Tree.init<TokenState>(); 
  stable var _requests        : Requests       = SBuffer.init<Request>();
  stable var _swappable       : SwapRegistry   = Text.Tree.init<TokenIdentifier>();
  stable var _holdings        : Holdings       = Text.Tree.init<[TokenIndex]>();
  stable var _match_candidate : Text.Set       = Text.Set.init();
  // stable var _backup          : TestBackup     = {
  //   burn_registry = Principal.placeholder();
  //   registry = Principal.placeholder();
  //   inventory = [];
  //   holdings = Text.Tree.init<[TokenIndex]>();
  //   candidates = Text.Tree.init<TokenState>();
  //   whitelist = [];
  // };

  /*============================================================================||
  ||                                                                            ||
  || Administrator Interface                                                    ||
  ||                                                                            ||
  ||============================================================================*/
  //
  public shared query func rand_cache() : async Nat { Random.Entropy.size(_entropy) };

  // public shared func reset_test() : async () {
  //   type ResetSvc = actor { reset_test : shared () -> async () };
  //   let registry : ResetSvc = actor(Principal.toText(_registry) );
  //   let burn_registry : ResetSvc = actor(Principal.toText(_burn_registry));
  //   await registry.reset_test();
  //   await burn_registry.reset_test();
  //   _burn_registry := _backup.burn_registry;
  //   _registry := _backup.registry;
  //   _inventory := Array.thaw<[TokenIdentifier]>( _backup.inventory );
  //   _holdings := _backup.holdings;
  //   _candidates := _backup.candidates;
  //   process_whitelist( _backup.whitelist );
  // };

  public query func holdings() : async [(AccountIdentifier,[TokenIndex])] {
    Iter.toArray<(AccountIdentifier,[TokenIndex])>(Text.Tree.entries<[TokenIndex]>(_holdings));
  };

  public shared query ({caller}) func get_user_requests( p : Principal ) : async [(Nat,SharedRequest)] {
    assert is_admin(caller);
    let buffer = Buffer.Buffer<(Nat,SharedRequest)>(0);
    let count : Nat = SBuffer.size(_requests)-1;
    for ( i in Iter.range(0,count) ){
      let request = SBuffer.get(_requests, i);
      if ( Principal.equal(request.owner, p) ){
        switch( request.status ){
          case ( #submitted ){
            buffer.add((i, {
              owner = p;
              subaccount = SBuffer.get(_requests, i).subaccount;
              category   = SBuffer.get(_requests, i).category;
              candidates = SBuffer.get(_requests, i).candidates;
              status     = SBuffer.get(_requests, i).status;
            }));
          };
          case ( #settled ){
            buffer.add((i, {
              owner = p;
              subaccount = SBuffer.get(_requests, i).subaccount;
              category   = SBuffer.get(_requests, i).category;
              candidates = SBuffer.get(_requests, i).candidates;
              status     = SBuffer.get(_requests, i).status;
            })); 
          };
          case _ ();
        }
      };
    };
    Buffer.toArray<(Nat,SharedRequest)>(buffer);
  };

  public shared query ({caller}) func refunded() : async [(Nat,SharedRequest)] {
    assert is_admin(caller);
    let buffer = Buffer.Buffer<(Nat,SharedRequest)>(0);
    let count : Nat = SBuffer.size(_requests)-1;
    for ( i in Iter.range(0,count) ){
      switch( SBuffer.get(_requests, i).status ){
        case ( #refunded ){
          buffer.add((i, {
            owner = SBuffer.get(_requests, i).owner;
            subaccount = SBuffer.get(_requests, i).subaccount;
            category   = SBuffer.get(_requests, i).category;
            candidates = SBuffer.get(_requests, i).candidates;
            status     = SBuffer.get(_requests, i).status;
          }))
        };
        case _ {};
      }
    };
    Buffer.toArray<(Nat,SharedRequest)>(buffer);
  };

  public shared query ({caller}) func cancelled() : async [(Nat,SharedRequest)] {
    assert is_admin(caller);
    let buffer = Buffer.Buffer<(Nat,SharedRequest)>(0);
    let count : Nat = SBuffer.size(_requests)-1;
    for ( i in Iter.range(0,count) ){
      switch( SBuffer.get(_requests, i).status ){
        case ( #cancelled ){
          buffer.add((i, {
            owner = SBuffer.get(_requests, i).owner;
            subaccount = SBuffer.get(_requests, i).subaccount;
            category   = SBuffer.get(_requests, i).category;
            candidates = SBuffer.get(_requests, i).candidates;
            status     = SBuffer.get(_requests, i).status;
          }))
        };
        case _ {};
      }
    };
    Buffer.toArray<(Nat,SharedRequest)>(buffer);
  };

  public query func aid( p : Principal ) : async AccountIdentifier {
    AID.fromPrincipal(p, null);
  };
  public query func self_aid() : async AccountIdentifier {
    AID.fromPrincipal(_self, null);
  };
  public query func tid( p : Principal, i : Nat32 ) : async TokenIdentifier {
    Ext.TokenIdentifier.fromPrincipal(p, i);
  };
  public query func rand_size() : async Nat { Random.Entropy.size(_entropy) };
  public query func admins() : async [Principal] { Principal.Set.toArray(_admins) };

  public query func service_state() : async (ServiceState, Bool) { (_event, _operational) };

  public query func burn_registry() : async Principal { _burn_registry };
  
  public query func claim_registry() : async Principal { _registry };

  public query func burn_tokenid( n : Nat32 ) : async TokenIdentifier {
    Ext.TokenIdentifier.fromPrincipal(_burn_registry, n)
  };

  public shared query ({caller}) func event_by_id( i : Index ) : async ?Event { 
    assert is_admin(caller);
    History.get_event(_history, i);
  };

  public query func burned() : async Nat {
    var count : Nat = 0;
    for ( burned in History.get_burned(_history, _burn_registry).vals() ) count += 1;
    count-2;
  };

  // public query func dump_history() : async SharedHistory {
  //   History.share(_history);
  // };

  public shared query ({caller}) func claimed( p : Principal ) : async [(TokenIndex, Index)] {
    assert is_admin(caller);
    History.get_claimed(_history, p);
  };



  public shared query ({caller}) func user_events( account : AccountIdentifier ) : async [Event] {
    assert is_admin(caller);
    History.get_user_events(_history, account);
  };

  // public query func event_by_token( tokenid : TokenIdentifier ) : async ?Event {
  //   _event_by_token(tokenid);
  // };

  public query func credits( account : AccountIdentifier ) : async ?StableCredits {
    switch( get_user_credits( account ) ){
      case ( ?c ) ?(c[0],c[1],c[2],c[3],c[4]);
      case null null;
    };
  };

  // public shared ({caller}) func finalfix() : async Return<()> {
  //   assert is_admin(caller);
  //   let owner : AccountIdentifier = "b8b4e2867d9a756668da7e4a972eb1fe63decac9342f62d840fedd7c4ef02549";
  //   let candidates : [TokenIdentifier] = [
  //     "ehjxl-xqkor-uwiaa-aaaaa-b4arg-qaqca-aacdw-a",
  //     "ftx4d-yakor-uwiaa-aaaaa-b4arg-qaqca-aaefo-a"
  //   ];
  //   switch( await bulk_transfer(candidates, owner, _burn_registry) ){
  //     case ( #err val ) #err( #Other("failed"));
  //     case ( #ok _ ){
  //       let current = Buffer.fromArray<TokenIdentifier>(_inventory[0]);
  //       current.add("w7iuv-gykor-uwiaa-aaaaa-cyanl-maqca-aaahj-q");
  //       _inventory[0] := Buffer.toArray<TokenIdentifier>( current );
  //       #ok();
  //     }
  //   }
  // };
  type Action = { #add; #subtract };
  public shared ({caller}) func fix( account : AccountIdentifier, action : Action, cat : Category, token : ?TokenIndex ) : async ?StableCredits {
    assert is_admin(caller);
    switch( get_user_credits( account ) ){
      case null null;
      case ( ?c ){
        switch action {
          case ( #subtract ) c[category_index(cat)] -= 1;
          case ( #add ){
            switch( token ){
              case null ();
              case ( ?tindex ){
                let holdings = Buffer.fromArray<TokenIndex>(
                  Option.get<[TokenIndex]>(Text.Tree.find<[TokenIndex]>(_holdings,account), [])
                );
                holdings.add(tindex);
                _holdings := Text.Tree.insert<[TokenIndex]>(
                  _holdings, account, Buffer.toArray<TokenIndex>(holdings)
                )
              }
            };
            c[category_index(cat)] += 1
          }
        };
        ?(c[0],c[1],c[2],c[3],c[4])
      }
    } 
  };

  // public shared ({caller}) func fix( aid : AccountIdentifier ) : async () {
  //   assert is_admin(caller);
  //   switch( get_user_credits( aid ) ){
  //     case ( ?c ) c[0] += 1;
  //     case null assert false;
  //   };
  //   ();
  // };

  public query func all_candidates() : async [(TokenIdentifier,TokenState)] {
    Iter.toArray(Text.Tree.entries<TokenState>(_candidates));
  };

  public shared query ({caller}) func check_candidates( aid : AccountIdentifier ) : async [TokenIdentifier] {
    assert is_admin(caller);
    switch( Text.Tree.find<[TokenIndex]>(_holdings, aid) ){
      case ( ?tokens ) Array.mapFilter<TokenIndex,TokenIdentifier>(
        tokens, func(x) : ?TokenIdentifier {
          let tokenid = Ext.TokenIdentifier.fromPrincipal(_burn_registry, x);
          if ( Text.Set.match(_match_candidate, tokenid) ) ?tokenid
          else null
        }
      );
      case null [];
    };
  };
  
  public shared query ({caller}) func candidates() : async [TokenIdentifier] {
    let owner : AccountIdentifier = AID.fromPrincipal(caller, null);
    switch( Text.Tree.find<[TokenIndex]>(_holdings, owner) ){
      case ( ?tokens ) Array.mapFilter<TokenIndex,TokenIdentifier>(
        tokens, func(x) : ?TokenIdentifier {
          let tokenid = Ext.TokenIdentifier.fromPrincipal(_burn_registry, x);
          if ( Text.Set.match(_match_candidate, tokenid) ) ?tokenid
          else null
        }
      );
      case null [];
    };
  };

  public query func whitelist() : async StableWhitelist {
    Array.map<WhitelistEntry, StableWhitelistEntry>(
      Iter.toArray<WhitelistEntry>( Text.Tree.entries<Credits>( _whitelist ) ),
      func (x) = (x.0, (x.1[0], x.1[1], x.1[2], x.1[3], x.1[4]))
    );
  };

  public query func participants() : async [AccountIdentifier] {
    Iter.toArray<AccountIdentifier>( Text.Tree.keys<Credits>( _whitelist ) )
  };

  public shared query ({caller}) func count_credits() : async (Nat,Nat,Nat,Nat,Nat) {
    assert is_admin(caller);
    review_credits();
  };

  public query func inventory() : async [(Category,[TokenIdentifier])] {
    let c1 : (Category,[TokenIdentifier]) = (#cat1, _inventory[0]);
    let c2 : (Category,[TokenIdentifier]) = (#cat2, _inventory[1]);
    let c3 : (Category,[TokenIdentifier]) = (#cat3, _inventory[2]);
    let c4 : (Category,[TokenIdentifier]) = (#cat4, _inventory[3]);
    let c5 : (Category,[TokenIdentifier]) = (#cat5, _inventory[4]);
    [c1,c2,c3,c4,c5];
  };

  public shared query ({caller}) func count_inventory() : async [(Category,Nat)] {
    assert is_admin(caller);
    let c1 : (Category,Nat) = (#cat1, _inventory[0].size());
    let c2 : (Category,Nat) = (#cat2, _inventory[1].size());
    let c3 : (Category,Nat) = (#cat3, _inventory[2].size());
    let c4 : (Category,Nat) = (#cat4, _inventory[3].size());
    let c5 : (Category,Nat) = (#cat5, _inventory[4].size());
    [c1,c2,c3,c4,c5];
  };
  
  /*============================================================================||
  ||                                                                            ||
  || Administrator Interface                                                    ||
  ||                                                                            ||
  ||============================================================================*/
  //
  public shared ({caller}) func claim( request : ClaimRequest ) : async Return<[TokenIdentifier]> {

    assert operational();

    let tbuffer = Buffer.Buffer<TokenIdentifier>(0);
    var claimant : AccountIdentifier = "none";
    var subaccount : ?Ext.SubAccount = null;
    var burned : [TokenIdentifier] = [];
    var reference : Index = 0;

    switch request {

      case ( #drop(sa) ){

        assert active_drop();

        subaccount := ?sa; 
        claimant := AID.fromPrincipal(caller, subaccount);

        switch ( get_user_credits( claimant ) ){
 
          case null return #err(#NotWhitelisted(claimant));

          case ( ?cred ){

            let avail : Nat = cred[0] + cred[1] + cred[2] + cred[3] + cred[4];

            if (  avail == 0 ) return #err(#InsufficientCredits);

            for ( i in Iter.range(0,4) ){
              if ( cred[i] > 0 ){
                for ( n in Iter.range(1,cred[i]) ){
                  tbuffer.add( random_token(index_category(i)) );
                };
              };
            };

            clear_user_credits( claimant );

          };
        };
      };

      case ( #burn(ref) ){

        assert active_burn();

        // Determine if the request exists
        reference := ref;
        switch( get_request(ref) ){

          case null return #err(#Other("Request ID: " # Index.toText(ref) # "; not found."));

          case (?request){

            // Does the caller own this request?
            let requestor = AID.fromPrincipal(request.owner, request.subaccount);
            claimant := AID.fromPrincipal(caller, request.subaccount);
            assert AID.equal(requestor, claimant);

            // Evaluate request status   
            switch( request.status ){

              // If settled, process the claim.
              case( #settled ){ 
                set_request_status(ref, #busy);
                tbuffer.add( random_token(request.category) );
                burned := request.candidates;
              };

              case( #busy ) return #err( #ProcessingRequest );
              case( #submitted ) return #err( #ConditionsNotMet );
              case( #claimed ) return #err( #AlreadyClaimed );
              case( #cancelled ) return #err( #RequestCancelled );
              case( #refunded ) return #err( #RequestCancelled );
              case(_) return #err( #UnknownState );

            };

            set_request_status(ref, #claimed);

          };
        };
      };
    };
            
    let transferred : [TokenIdentifier] = Buffer.toArray( tbuffer );

    switch( await bulk_transfer(transferred, claimant, _registry) ){
          
      case ( #ok() ){

        add_user_event({
          address = claimant;
          burned = burned;
          claimed = transferred;
          timestamp = Time.now();
          memo = to_candid(get_event());
        });

        #ok( transferred );

      };
      
      case ( #err(val) ){

        if ( active_burn() ) set_request_status(reference, #settled);
        set_inoperable();
        #err val;

      };
    };
  };

  /*============================================================================||
  ||                                                                            ||
  || Administrator Interface                                                    ||
  ||                                                                            ||
  ||============================================================================*/
  //
  public shared ({caller}) func burn( request : BurnRequest ) : async Return<BurnInstruction> {

    assert active_burn() and operational();
    
    let cindex : Index = category_index( request.category );

    // Determine if the request satisfies event criteria
    switch ( get_requirement( cindex ) ) {
      case null #err(#BadCategory(request.category));
      case ( ?num_tokens_required ) { // Number of tokens required for a given category 

        if( request.tokens.size() != num_tokens_required ) {
          return #err(#InsufficientTokens(num_tokens_required));
        };
        
        let requestor : AccountIdentifier = AID.fromPrincipal(
          caller, request.subaccount
        );

        let user_tindices : [TokenIndex] = Option.get<[TokenIndex]>(
          Text.Tree.find<[TokenIndex]>(_holdings, requestor), []
        ); 

        let user_tokenids : [TokenIdentifier] = Array.map<TokenIndex,TokenIdentifier>(
          user_tindices, func(x) : TokenIdentifier {
            Ext.TokenIdentifier.fromPrincipal(_burn_registry, x)
          }
        );

        let user_holdings = Text.Set.fromArray( user_tokenids );

        let burn_tokens = Text.Set.fromArray( request.tokens );
        
        for ( t in request.tokens.vals() ){
          if ( not Text.Set.match(user_holdings, t) ) return #err(#Other("You don't own these tokens"))
        };
        
        // Does the caller have sufficent credits?
        switch( get_user_credits( requestor ) ) {
          case null #err(#Unauthorized(requestor));
          case ( ?credits ) {
            
            if ( credits[cindex] == 0 ) return #err(#InsufficientCredits);
            
            // Have the specified tokens been locked or burned?
            for ( tokenid in request.tokens.vals() ){
              
              switch ( get_token_state( tokenid ) ) {
                case null return #err(#InvalidToken(tokenid));
                case ( ?lock ) {                  
       
                  switch lock {
                    case ( #locked ) return #err(#TokenIsLocked(tokenid));
                    case ( #burned ) return #err(#AlreadyBurned(tokenid));
                    case _ {};
                  };

                };
              };

            };

            // Deduct user credit
            credits[cindex] -= 1;

            // Lock tokens; used to detect duplicate transactions
            for (tokenid in request.tokens.vals() ){
              set_token_lock(tokenid, #locked);
            };

            // Store user request information
            let requestId = add_new_request({
              owner = caller;
              subaccount = request.subaccount;
              category = request.category;
              candidates = request.tokens;
              var status = #submitted;
            });

            // Craft burn instruction
            let burn_registry : Ext.Service = actor(Principal.toText(_burn_registry)); // actor(_burn_registry);

            let btxfr : Ext.BulkTransferRequest = {
              to = #principal(_self);
              from = #address(requestor);
              amount = num_tokens_required;
              tokens = request.tokens;
              memo = to_candid(requestId);
              notify = true;
              subaccount = request.subaccount;
            };

            // Return burn instruction
            #ok({
              reference = requestId;
              transfer = burn_registry.transferBulk;
              request = btxfr;
            });

          };
        };
      };
    };
  };

  /*============================================================================||
  ||                                                                            ||
  || Administrator Interface                                                    ||
  ||                                                                            ||
  ||============================================================================*/
  //
  public shared ({caller}) func configure( config : Configuration ) : async Return<()> {
    
    assert is_admin(caller) and not active_configuration();
    
    if ( not ( inactive() and inoperable() ) ) return #err(#ConfigError("Service still running"));

    if ( not_valid_event( config.event ) ) return #err(#ConfigError("Not valid event type"));

    set_configuration( #active );

    let cbuffer = Buffer.Buffer<Category>( config.inventory.size() );
    let ibuffer = Buffer.Buffer<Ext.TokenIndex>( config.inventory.size() );
  
    for ( cat in config.inventory.vals() ){
      for ( tindex in cat.1.vals() ) ibuffer.add(tindex);
      cbuffer.add(cat.0);
    };

    try {

      let tokensvc = actor(Principal.toText(config.registry)) : Ext.Service;

      switch ( await tokensvc.tokens( AID.fromPrincipal(_self, null) ) ){

        case ( #ok(i) ){
          let inventory = Index.Set.fromArray( Array.map<Ext.TokenIndex,Index>(i, Nat32.toNat) );
          for ( tindex in ibuffer.vals() ){
            if ( not Index.Set.match(inventory, Nat32.toNat(tindex)) ){
              set_configuration( #inactive );
              return #err(#ConfigError("Inventory mismatch"));
            };
          };
        };

        case( #err(val) ) { 
          set_configuration( #inactive );
          return #err(#ConfigError("Failed to retrieve inventory"));
        };

      };

    } catch (e) {
      set_configuration( #inactive );
      return #err(#ConfigError("Trapped when calling claim registry"));
    };

    for ( cat in cbuffer.vals() ){

      switch( cat ){

        case ( #cat1 ) if ( Option.isNull(config.requirements.0) ){
          set_configuration( #inactive );
          return #err(#ConfigError("Cat 1 requirements can't be null"))
        };

        case ( #cat2) if ( Option.isNull(config.requirements.1) ){
          set_configuration( #inactive );
          return #err(#ConfigError("Cat 2 requirements can't be null"))
        };

        case ( #cat3 ) if ( Option.isNull(config.requirements.2) ){
          set_configuration( #inactive );
          return #err(#ConfigError("Cat 3 requirements can't be null"))
        };

        case ( #cat4 ) if ( Option.isNull(config.requirements.3) ){
          set_configuration( #inactive );
          return #err(#ConfigError("Cat 4 requirements can't be null"))
        };

        case ( #cat5 ) if ( Option.isNull(config.requirements.4) ){
          set_configuration( #inactive );
          return #err(#ConfigError("Cat 5 requirements can't be null"))
        };

      };

    };

    switch ( config.event ){

      case ( #drop ) process_whitelist( config.recipients );

      case ( #burn ){

        switch ( config.snapshot ){

          case null {

            set_configuration( #inactive );
            return #err(#ConfigError("Burn event requires snapshot principal"));

          };

          case ( ?p ){

            try {

              let svc = actor(Principal.toText(p)) : SnapshotSvc;
              let ss : Snapshot = await svc.snapshot();
              let tprin : Principal = Option.get(config.burn_registry, Principal.placeholder());

              if ( not Principal.equal(tprin, ss.registry) ){
                set_configuration( #inactive );
                return #err(#ConfigError("Snapshot registry does not match burn registry"));
              }; 

              set_user_holdings( ss.owners );
              set_burn_registry( ss.registry );
              process_requirements( config.requirements );
              process_whitelist( ss.whitelist );
              process_candidates( ss.candidates );

            } catch (e) {

              set_configuration( #inactive );
              return #err(#ConfigError("Trapped when calling snapshot canister"));

            };
          }; 
        };

      };

      case ( #swap ){

        assert ( config.mapping.size() > 0 );

        switch( config.burn_registry ){

          case null {
            set_configuration( #inactive );
            return #err(#ConfigError("Swap event requires a burn_registry argument"));
          };

          case ( ?p ){
            try {
              let svc = actor(Principal.toText(p)) : Ext.Service;
              let _ = await svc.tokens(AID.fromPrincipal(_self, null));
            } catch (e) {
              set_configuration( #inactive );
              return #err(#ConfigError("Trapped when calling burn registry"));
            };
            set_burn_registry( p );
          };

        };

        map_swap_tokens( config.mapping );

      };

      case _ {

        set_configuration( #inactive );
        return #err(#ConfigError("This should never happen"));

      };

    };

    set_claim_registry(config.registry);
    set_event( config.event );
    process_inventory(config.inventory);
    set_configuration( #inactive );

    // _backup := {
    //   burn_registry = _burn_registry;
    //   registry = _registry;
    //   inventory = Array.freeze<[TokenIdentifier]>(_inventory);
    //   holdings = _holdings;
    //   candidates = _candidates;
    //   whitelist = Array.map<WhitelistEntry, StableWhitelistEntry>(
    //     Iter.toArray<WhitelistEntry>( Text.Tree.entries<Credits>( _whitelist ) ),
    //     func (x) = (x.0, (x.1[0], x.1[1], x.1[2], x.1[3], x.1[4]))
    //   );
    // };

    #ok();
  
  };

  public shared ({caller}) func init() : async () {
    assert Principal.equal(caller, _installer);

    let _hbsvc = Principal.fromText("qnkcz-4aaaa-aaaal-abixq-cai");

    // Register with the heartbeat service
    let hbsvc : HB.HeartbeatService = actor(Principal.toText(_hbsvc));
    try {
      await hbsvc.schedule([
        {interval = HB.Intervals._15beats; tasks = [pulse]}
      ]);
    } catch (e) {};

    _self := Principal.fromActor(this);
    _add_admin(caller);
  };

  public shared ({caller}) func pulse() : () {
    assert Principal.equal(caller, Principal.fromText("qnkcz-4aaaa-aaaal-abixq-cai"));
    await Random.Entropy.fill(_entropy);
  };

  /*============================================================================||
  ||                                                                            ||
  || Administrator Interface                                                    ||
  ||                                                                            ||
  ||============================================================================*/
  //
  public shared ({caller}) func round2_whitelist( entries : [(AccountIdentifier,(Nat,Nat,Nat,Nat,Nat))] ) : async () {
    assert is_admin(caller) and inoperable();
    _whitelist := Text.Tree.init<Credits>();
    process_whitelist( entries );
  };

  public shared ({caller}) func reset() : async Return<()> {
  
    // Verify that the caller is an administrator and that the system is not accepting new requests
    assert is_admin(caller) and inoperable();

    // Verify that all requests have been closed out
    for ( request in all_requests() ) {  
      switch( request.status ) {
        case ( #settled ) return #err(#ActiveRequest(share_request(request)));
        case ( #submitted ) return #err(#ActiveRequest(share_request(request)));
        case ( #busy ) return #err(#ActiveRequest(share_request(request)));
        case _ ();
      };
    };

    // Verify that all remianing inventory as been reclaimed
    if ( unclaimed_inventory() ) {
      return #err(#ConfigError("Rejected: Please reclaim inventory before resetting the exchange service"));
    };
    
    // Verify that all unclaimed credits have been recovered
    if ( unclaimed_credits() ) {
      return #err(#ConfigError("Rejected: Please reclaim credits before resetting the exchange service"));
    };

    internal_reset();
    #ok();

  };

  /*============================================================================||
  ||                                                                            ||
  || Administrator Interface                                                    ||
  ||                                                                            ||
  ||============================================================================*/
  //
  public shared ({caller}) func refund( ref : Index ) : async Return<()> {

    assert is_admin(caller);

    // Verify that the index reference maps to a real request
    switch ( get_request(ref) ) {

      case null #err(#DoesNotExist);
      
      case ( ?request ) {

        // Verify that the refund request is coming from the request owner or a service adminsitrator
        assert Principal.equal(caller, request.owner) or is_admin(caller);

        // Make sure the request hasn't already been refunded or cancelled
        switch( request.status ) {

          case ( #cancelled ) return #err(#RequestCancelled);
          case ( #refunded ) return #err(#AlreadyRefunded);
          case ( #submitted ) return #err(#NothingToRefund);
          case ( #busy ) return #err(#BeingProcessed);
          case ( #claimed ) return #err(#AlreadyClaimed);
          case ( #settled ){} // This is the only case in which a refund should be processed

        };

        // Lock the request to prevent future processing
        request.status := #busy;

        // Process the refund
        let owner : AccountIdentifier = AID.fromPrincipal(request.owner, request.subaccount);
        switch( await bulk_transfer(request.candidates, owner, _burn_registry) ) {

          // Nested fault handling
          case ( #err val ) #err val;

          // Set the request status to "Refunded" and provide positive confirmation to the caller
          case ( #ok ) {

            switch( get_user_credits( owner ) ) {
              case null #err(#Unauthorized(owner));
              case ( ?credits ) {

                let cindex : Index = category_index( request.category );

                // Refund user credit
                credits[cindex] += 1;

                // Unlock tokens
                for (tokenid in request.candidates.vals() ){
                  set_token_lock(tokenid, #unlocked);
                };

                let current_holdings = Buffer.fromArray<TokenIndex>(
                  Option.get<[TokenIndex]>(
                    Text.Tree.find<[TokenIndex]>(_holdings, owner), []
                  )
                );

                let refunded_tokens = Buffer.fromArray<TokenIndex>(
                  Array.map<TokenIdentifier,TokenIndex>(
                    request.candidates, func(x) : TokenIndex {
                      Ext.TokenIdentifier.getIndex(x)
                    }
                  )
                );

                current_holdings.append( refunded_tokens );

                _holdings := Text.Tree.insert<[TokenIndex]>(
                  _holdings, owner, Buffer.toArray( current_holdings )
                );

                request.status := #refunded;
                #ok();
              }
            }
          };

        };

      };

    };
  };

  /*============================================================================||
  ||                                                                            ||
  || Administrator Interface                                                    ||
  ||                                                                            ||
  ||============================================================================*/
  //
  public shared ({caller}) func cancel( ref : Index ) : async Return<()> {

    assert is_admin(caller);
    // Verify that the index reference maps to a real request
    switch ( get_request(ref) ) {

      case null #err(#DoesNotExist);
      
      case ( ?request ) {

        // Verify that the refund request is coming from the request owner or a service adminsitrator
        assert Principal.equal(caller, request.owner) or is_admin(caller);

        // Make sure the request hasn't already been refunded or cancelled
        switch( request.status ) {
          
          case ( #cancelled ) return #err(#RequestCancelled);
          case ( #refunded ) return #err(#AlreadyRefunded);
          case ( #settled ) return #err(#AlreadySettled);
          case ( #busy ) return #err(#BeingProcessed);
          case ( #claimed ) return #err(#AlreadyClaimed);
          case ( #submitted ){}; // This is the only case in which a request should be cancelled.

        };

        // Set request status to "Cancelled" and provide positive confirmation of cancellation
        let requestor : AccountIdentifier = AID.fromPrincipal(request.owner, request.subaccount);
        switch( get_user_credits( requestor ) ) {
          case null #err(#Unauthorized(requestor));
          case ( ?credits ) {

            let cindex : Index = category_index( request.category );

            // Refund user credit
            credits[cindex] += 1;

            // Unlock tokens
            for (tokenid in request.candidates.vals() ){
              set_token_lock(tokenid, #unlocked);
            };

            request.status := #cancelled;
            #ok()
          }
        }

      };

    };
  }; 

  /*============================================================================||
  ||                                                                            ||
  || Administrator Interface                                                    ||
  ||                                                                            ||
  ||============================================================================*/
  //
  public shared ({caller}) func add_admin( p : Principal ) : async () { 
    assert is_admin(caller);
    _add_admin(p);
  };
  public shared ({caller}) func del_admin( p : Principal ) : async () {
    assert is_admin(caller);
    _del_admin(p);
  };
  public shared ({caller}) func set_admins( arr : [Principal] ) : async () {
    assert is_admin(caller);
    _set_admins(arr);
  };
  public shared ({caller}) func start() : async () { 
    assert is_admin(caller);
    set_operational();
  };
  public shared ({caller}) func stop() : async () {
    assert is_admin(caller);
    set_inoperable();
  };

  /*============================================================================||
  ||                                                                            ||
  || Administrator Interface                                                    ||
  ||                                                                            ||
  ||============================================================================*/
  //
  public shared ({caller}) func bulkTokenTransferNotification(
    tokens : [TokenIdentifier], sender : User, amount : Balance, memo : Memo ) 
    : async ?Balance {

      assert is_burn_registry(caller);

      if( not ( active_burn() or active_swap() ) ){ return null };

      switch( from_candid(memo) : ?Index ){
        case null null;
        case ( ?ref ) {

          switch( get_request(ref) ){
            case null null;
            case ( ?request ) {

              switch ( request.status ){
                case ( #submitted ) {

                  let expected = Text.Set.fromArray( request.candidates );
                  if ( Text.Set.size( expected ) != amount ) return null;

                  for ( tokenid in tokens.vals() ){
                    if ( not Text.Set.match(expected, tokenid) ) return null;
                  };

                  let spender = Ext.User.toAID( sender );
                  let owner = AID.fromPrincipal(request.owner, request.subaccount);
                  if ( not AID.equal(owner, spender) ) return null;

                  let user_tindices : [TokenIndex] = Option.get<[TokenIndex]>(
                    Text.Tree.find<[TokenIndex]>(_holdings, owner), []
                  ); 

                  let user_tokenids : [TokenIdentifier] = Array.map<TokenIndex,TokenIdentifier>(
                    user_tindices, func(x) : TokenIdentifier {
                      Ext.TokenIdentifier.fromPrincipal(_burn_registry, x)
                    }
                  );

                  // Remove tokens from user holdings
                  let remaining : [TokenIndex] = Array.mapFilter<TokenIdentifier,TokenIndex>(
                    user_tokenids, func(x) : ?TokenIndex {
                      if( not Text.Set.match(expected, x) ) ?Ext.TokenIdentifier.getIndex(x)
                      else null
                    } 
                  );

                  _holdings := Text.Tree.insert<[TokenIndex]>(_holdings, owner, remaining);

                  for ( tokenid in tokens.vals() ) set_token_lock(tokenid, #burned);
                  set_request_status(ref, #settled);
                  ?amount;

                };
                case _ null;
              };
            };
          };
        };
      };
  };

  /*============================================================================||
  ||                                                                            ||
  || Private functions over state & modes of operation                          ||
  ||                                                                            ||
  ||============================================================================*/
  //
  func all_requests() : Iter.Iter<Request> {
    SBuffer.vals<Request>(_requests);
  };
  func set_configuration( c : ConfigActivity ) : () {
    _config_activity := c;
  };
  func operational() : Bool { _operational };
  func inoperable() : Bool { not _operational };
  func get_event() : ServiceState { _event };
  func set_operational() : () {
    _operational := true;
  };
  func set_inoperable() : () {
    _operational := false;
  };
  func set_event( e : ServiceState ) : () {
    _event := e;
  };
  func not_valid_event( e : ServiceState) : Bool {
    switch e { case (#inactive) true; case _ false };
  };
  func _add_admin( p : Principal ) : () { 
    _admins := Principal.Set.insert(_admins, p);
  };
  func _del_admin( p : Principal ) : () {
    _admins := Principal.Set.delete(_admins, p);
  };
  func _set_admins( arr : [Principal] ) : () {
    _admins := Principal.Set.fromArray(arr);
  };
  func active_configuration() : Bool {
    switch _config_activity { case (#active) true; case _ false };
  };
  func active_burn() : Bool {
    switch _event { case (#burn) true ; case _ false };
  };
  func active_drop() : Bool {
    switch _event { case (#drop) true; case _ false };
  };
  func active_swap() : Bool {
    switch _event { case (#swap) true; case _ false };
  };
  func inactive() : Bool {
    switch _event { case (#inactive) true; case _ false };
  };
  func active() : Bool {
    not inactive();
  };
  func is_admin( p : Principal ) : Bool {
    Principal.Set.match(_admins, p);
  };
  func add_new_request( r : Request ) : Index {
    let index = SBuffer.size<Request>(_requests);
    SBuffer.add<Request>(_requests, r);
    index;
  };
  func set_user_holdings( entries : [(AccountIdentifier,[TokenIndex])] ) {
    _holdings := Text.Tree.fromEntries<[TokenIndex]>(entries);
  };
  func process_requirements( r : (?Nat,?Nat,?Nat,?Nat,?Nat) ) : () {
    _requirements := [r.0, r.1, r.2, r.3, r.4];
  };
  func process_whitelist( wl : [(AccountIdentifier,(Nat,Nat,Nat,Nat,Nat))] ) : () {
    for ( e in wl.vals() ){
      let varray : Credits = Array.thaw([e.1.0, e.1.1, e.1.2, e.1.3, e.1.4]);
      update_whitelist(e.0, varray);
    };
  };
  func map_swap_tokens( t : [(TokenIndex,TokenIndex)] ) : () {
    _swappable := Text.Tree.fromEntries<TokenIdentifier>(
      Array.map<(TokenIndex,TokenIndex),(TokenIdentifier,TokenIdentifier)>(
        t, func ( (x,y) ) : (TokenIdentifier,TokenIdentifier) {(
          Ext.TokenIdentifier.fromPrincipal(_burn_registry, x),
          Ext.TokenIdentifier.fromPrincipal(_registry, y)
        )}
      )
    );
  };
  func process_candidates( candidates : [TokenIndex] ) : () {
    for ( tindex in candidates.vals() ){
      let tokenid : TokenIdentifier = get_burn_tokenid(tindex);
      _match_candidate := Text.Set.insert(_match_candidate, tokenid);
      set_token_lock(tokenid, #unlocked);
    };
  };
  func process_inventory( inventory : [(Category,[TokenIndex])] ) : () {
    for ( entry in inventory.vals() ){
      let cindex : Index = category_index(entry.0);
      _inventory[cindex] := Array.map<TokenIndex,TokenIdentifier>(
        entry.1, get_claim_tokenid);
    };
  };
  func is_burn_registry( p : Principal ) : Bool {
    Principal.equal(_burn_registry, p);
  };
  func get_requirement( i : Index ) : ?Nat {
    _requirements[i];
  };
  func set_claim_registry( p : Principal ) : () {
    _registry := p;
  };
  func set_burn_registry( p : Principal ) : () {
    _burn_registry := p;
  };
  func add_user_event( e : Event ) : () {
    History.add_event(_history, e);
  };
  func set_token_lock( tokenid : TokenIdentifier, state : TokenState ) : () {
    _candidates := Text.Tree.insert<TokenState>(_candidates, tokenid, state);
  };
  func update_whitelist( aid : AccountIdentifier, credits : Credits ) : () {
    _whitelist := Text.Tree.insert<Credits>(_whitelist, aid, credits);
  };
  func get_user_credits( aid : AccountIdentifier ) : ?Credits {
    Text.Tree.find<Credits>(_whitelist, aid)
  };
  func clear_user_credits( aid : AccountIdentifier ) : () {
    for ( k in Text.Tree.keys<Credits>( _whitelist ) ){
      _whitelist := Text.Tree.insert<Credits>(_whitelist, aid, Array.init<Nat>(5,0));
    };
  };
  func get_token_state( tokenid : TokenIdentifier ) : ?TokenState {
    Text.Tree.find<TokenState>(_candidates, tokenid)
  };
  func get_burn_tokenid( tindex : TokenIndex ) : TokenIdentifier {
    Ext.TokenIdentifier.fromPrincipal(_burn_registry, tindex);
  };
  func get_claim_tokenid( tindex : TokenIndex ) : TokenIdentifier {
    Ext.TokenIdentifier.fromPrincipal(_registry, tindex);
  };
  func update_inventory( i : Index, ta : [TokenIdentifier] ) : () {
    _inventory[i] := ta;
  };
  func get_inventory( i : Index ) : [TokenIdentifier] {
    _inventory[i];
  };
  func get_request( i : Index ) : ?Request {
    SBuffer.getOpt(_requests, i);
  };
  func get_request_status( i : Index ) : RequestStatus {
    SBuffer.get<Request>(_requests, i).status;
  };
  func set_request_status( i : Index, s : RequestStatus ) : () {
    SBuffer.get<Request>(_requests, i).status := s;
  };
  func bulk_transfer( arr : [TokenIdentifier], receiver : AccountIdentifier, registry : Principal ) : async Return<()> {
    let burn_registry : Ext.Service = actor(Principal.toText(registry));
    let btxfr : Ext. BulkTransferRequest = {
      to = #address(receiver);
      from = #principal(_self);
      amount = arr.size();
      tokens = arr;
      memo = Blob.fromArray([]);
      notify = false;
      subaccount = null;
    };
    switch ( await burn_registry.transferBulk( btxfr ) ){
      case ( #ok(_) ) #ok();
      case ( #err val ){
        switch val {
          case ( #CannotNotify aid ) #err( #Other("Cannot notify") );
          case ( #InsufficientBalance ) #err ( #Other("InsufficientBalance"));
          case ( #InvalidToken tid ) #err( #Other("Invalid token: " # tid));
          case ( #Other text ) #err( #Other(text) );
          case ( #Rejected ) #err( #Other("Rejected"));
          case ( #Unauthorized aid ) #err( #Other("Unauthorized: " # aid));
        }
      }
    }
  };
  func random_token( cat : Category ) : TokenIdentifier {
    let cindex : Index = category_index(cat);
    assert _inventory[cindex].size() > 0;
    var selection : Nat = _inventory[cindex].size() - 1;
    if ( selection > 0 ) selection := random_number( selection );
    let tokenid : TokenIdentifier = _inventory[cindex][ selection ];
    _inventory[cindex] := Array.filter<TokenIdentifier>(
      _inventory[cindex], func x = Text.notEqual(tokenid, x));
    tokenid;
  };
  func internal_reset() : () {
    _requirements  := [];
    _inventory     := Array.init<[TokenIdentifier]>(5,[]);
    _registry      := Principal.placeholder();
    _burn_registry := Principal.placeholder();
    _whitelist     := Text.Tree.init<Credits>();
    _candidates    := Text.Tree.init<TokenState>(); 
    _requests      := SBuffer.init<Request>();
    set_event(#inactive);
    set_inoperable();
  };
  func share_request( r : Request ) : SharedRequest {
    return {
      owner = r.owner;
      subaccount = r.subaccount;
      category = r.category;
      candidates = r.candidates;
      status = r.status;
    };
  };
  func unclaimed_inventory() : Bool {
    for ( v in _inventory.vals() ){
      if ( v.size() > 0 ) return true;
    };
    false;
  };
  func unclaimed_credits() : Bool {
    var count : Nat = 0;
    for ( v in Text.Tree.vals<Credits>(_whitelist) ){
      for ( n in v.vals() ) count += n;
      if ( count > 0 ) return true;
    };
    false;
  };
  func reclaim_inventory( aid : AccountIdentifier ) : async Return<()> {
    let tbuffer = Buffer.Buffer<TokenIdentifier>(0);
    for ( v in _inventory.vals() ) { for ( t in v.vals() ) tbuffer.add(t) };
    switch( await bulk_transfer(Buffer.toArray(tbuffer), aid, _registry) ){
      case ( #err(_) ) #err(#TransferFailed);
      case ( #ok(_) ) #ok();
    };
  }; 
  // func reclaim_credits() : (Nat,Nat,Nat,Nat,Nat) {
  //   let r : [var Nat] = Array.init(5,0);
  //   for ( key in Text.Tree.keys<Credits>(_whitelist) ){
  //     switch( Text.Tree.find<Credits>(_whitelist, key) ){
  //       case ( ?c ) { for ( i in Iter.range(0,4) ) r[i] += c[i] };
  //       case null {}; // this won't ever happen;
  //     };
  //     clear_user_credits( key );
  //   };
  //   (r[0], r[1], r[2], r[3], r[4]);
  // };
  func review_credits() : (Nat,Nat,Nat,Nat,Nat) {
    let r : [var Nat] = Array.init(5,0);
    for ( key in Text.Tree.keys<Credits>(_whitelist) ){
      switch( Text.Tree.find<Credits>(_whitelist, key) ){
        case ( ?c ) { for ( i in Iter.range(0,4) ) r[i] += c[i] };
        case null {}; // this won't ever happen;
      }
    };
    (r[0], r[1], r[2], r[3], r[4]);
  };
  func random_number( max : Nat ) : Nat {
    switch (Random.Entropy.rng(_entropy).spin(max)) {
      case (?n) n;
      case null random_number(max);
    };
  };
  func index_category( i : Index ) : Category {
    if ( i == 0 ) #cat1
    else if ( i == 1 ) #cat2
    else if ( i == 2 ) #cat3
    else if ( i == 3 ) #cat4
    else #cat5
  };
  func category_index( category : Category ) : Index {
    switch( category ){
      case (#cat1) 0;
      case (#cat2) 1;
      case (#cat3) 2;
      case (#cat4) 3;
      case (#cat5) 4;
    };
  };

};