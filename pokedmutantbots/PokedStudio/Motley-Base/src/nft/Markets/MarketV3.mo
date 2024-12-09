import { Ledger } "../../base/ic0/Ledger";
import Principal "../../base/Principal";
import AccountId "../../base/AccountId";
import TokenId "../../nft/TokenId";
import Index "../../base/Index";
import Text "../../base/Text";
import Time "../../base/Time";
import Blob "mo:base/Blob";
import DQ "mo:base/Deque";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Array "mo:base/Array";
import Option "mo:base/Option";
import Buffer "mo:base/Buffer";
import Fees "Fees";

module Market {

  type Time = Time.Time;
  type Fee = Fees.Fee;
  type Fees = Fees.Fees;
  type AccountsPayable = [(AccountId,Nat64)];
  type Index = Index.Index;
  type TokenId = TokenId.TokenId;
  type AccountId = AccountId.AccountId;
  type SubAccount = AccountId.SubAccount;
  type Tokens = {e8s : Nat64};

  type Return<T> = { #ok : T; #err : Error };

  public type Price = Nat64;
  public type Allowance = Nat64;
  public type Disbursement = (Index, AccountId, Blob, Nat64);
  public type Refund = (AccountId,SubAccount);

  public type Error = {
    #ConfigError : Text;
    #FeeTooHigh : Nat64;
    #FeeTooSmall : Nat64;
    #PriceChange : Nat64;
    #InsufficientFunds;
    #UnauthorizedMarket : AccountId;
    #DelistingRequested;
    #Fatal : Text;
    #LockExpired;
    #NotLocked;
    #NoListing;
    #Locked;
    #Busy;
  };

  type Transactions = {
    var size : Nat;
    var elems : [var Transaction];
  };

  public type Market = {
    var init          : Bool;
    var range         : Nat;
    var next_sa       : Nat;
    var fees          : Fees;
    var escrow        : Principal;
    var genesis       : Time;
    var royalty       : AccountId;
    var locks         : [var Lock];
    var listings      : [var Listing];
    var transactions  : Transactions;
    var refunds       : DQ.Deque<Refund>;
    var disbursements : DQ.Deque<Disbursement>;
    var fs_threshold  : Nat;
  };

  public type Listing = {
    #delisted : Time.Time;
    #listed   : ListingDetails;
  };

  public type SharedListing = {
    seller    : Principal;
    price     : Nat64;
    royalty   : Fee;
    allowance : Fee;
    locked    : ?Time;
  };

  public type ListingDetails = {
    seller     : Principal;
    price      : Nat64;
    royalty    : Fee;
    allowance  : Fee;
    var locked : ?Time;
  };

  public type Lock = {
    #locked : LockDetails;
    #unlocked : Nat;
    #firesale : FireSale;
  };

  public type LockDetails = {
    timeouts   : Nat;
    buyer      : AccountId;
    subaccount : SubAccount;
    fees       : [(AccountId, Nat64)];
    var status : { #idle; #busy };
  };

  public type SharedLock = {
    firesale : Bool;
    buyer : ?AccountId;
    subaccount : ?SubAccount;
    fees : ?[(AccountId,Nat64)];
    status : { #idle; #busy };
  };

  public type FireSale = {
    timeouts       : Nat;
    var delist     : Bool;
    var principals : Principal.Set; 
    var pending    : [MultiLock];
    var buyers     : DQ.Deque<MultiLock>;
    var status     : { #idle; #busy };
  };

  public type MultiLock = (AccountId,SubAccount,AccountsPayable);

  public type Transaction = {
    token : TokenId;
    seller : Principal;
    price : Nat64;
    buyer : AccountId;
    time : Time;
  };

  public func stage() : Market {
    return {
      var init          = false;
      var range         = 0;
      var fees          = Fees.stage();
      var escrow        = Principal.placeholder();
      var genesis       = 0;
      var royalty       = "";
      var next_sa       = 0;
      var locks         = [var];
      var listings      = [var];
      var transactions  = { var size = 0; var elems = [var] };
      var refunds       = DQ.empty<Refund>();
      var disbursements = DQ.empty<Disbursement>();
      var fs_threshold  = 100;
    };
  };

  public func init(
    m : Market,
    self : Principal,
    royalty : Nat64,
    max_fee : Nat64,
    creator : AccountId,
    size : Nat,
    fs_threshold : Nat,
  ) : Return<()> {
    if( size == 0 ) return #err(#ConfigError("Projected inventory must be greater than 0"));
    if( not AccountId.valid( creator ) ) return #err(#ConfigError("Royalty address is not a valid Account ID"));
    switch( Fees.init(m.fees, max_fee, royalty, null, null) ){
      case ( #err val ) #err val;
      case ( #ok ){
        m.range := size;
        m.escrow := self;
        m.royalty := creator;
        m.locks := Array.init<Lock>(size, #unlocked(0));
        m.listings := Array.init<Listing>(size, #delisted(-1));
        m.fs_threshold := fs_threshold;
        m.genesis := Time.now();
        m.init := true;
        #ok()
      }
    }
  };

  public func tokenid( m : Market, i : Index ) : TokenId {
    TokenId.fromPrincipal(m.escrow, Nat32.fromNat(i));
  };

  public func transactions( m : Market ) : [Transaction] {
    assert m.init;
    if ( m.transactions.size == 0 ) []
    else {
      let resp = Array.init<Transaction>(m.transactions.size, tx_placeholder());
      for ( i in Iter.range(0, m.transactions.size - 1) ){
        resp[i] := m.transactions.elems[i]
      };
      Array.freeze<Transaction>( resp )
    }
  };

  public func is_listed( m : Market, i : Index ) : Bool {
    switch( m.listings[i] ){
      case ( #listed _ ) true;
      case ( #delisted _ ) false
    }
  };

  public func get_listing( m : Market, i : Index ) : SharedListing {
    assert i < m.range;
    switch( m.listings[i] ){
      case ( #delisted _ ) {assert false; {seller=Principal.placeholder();price=9999;royalty=100000;allowance=0;locked=null}};
      case ( #listed details ){
        ({
          seller = details.seller;
          price = details.price;
          royalty = details.royalty;
          allowance = details.allowance;
          locked = details.locked;
        })
      }
    }
  };

  public func getOpt_listing( m : Market, i : Index ) : ?SharedListing {
    assert i < m.range;
    switch( m.listings[i] ){
      case ( #delisted _ ) null;
      case ( #listed details ){
        Option.make({
          seller = details.seller;
          price = details.price;
          royalty = details.royalty;
          allowance = details.allowance;
          locked = details.locked;
        })
      }
    }
  };

  public func listings( m : Market ) : [(Index,SharedListing)] {
    assert m.init;
    var last : Nat = 0;
    if( m.range > 1 ) last := m.range - 1;
    let buffer = Buffer.Buffer<(Index,SharedListing)>(0);
    for ( index in Iter.range(0,last) ){
      switch( m.listings[index] ){
        case ( #delisted _ ) ();
        case ( #listed details ) buffer.add((
          index,
          {
            seller = details.seller;
            price = details.price;
            royalty = details.royalty;
            allowance = details.allowance;
            locked = details.locked;
          }
        ));
      }
    };
    Buffer.toArray<(Index,SharedListing)>(buffer);
  };

  public func delist( m : Market, i : Index ) : Return<()> {
    assert m.init;
    set_range(m, i);
    switch( m.listings[i] ){
      case ( #delisted _ ) #ok();
      case ( #listed _ ){
        switch( m.locks[i] ){
          case ( #locked _ ) #err(#Locked);
          case ( #unlocked _ ){
            m.listings[i] := #delisted( Time.now() );
            #ok();
          };
          case ( #firesale fs ){
            switch( fs.status ){
              case ( #busy ){
                fs.delist := true;
                #err(#DelistingRequested);
              };
              case ( #idle ){
                fs.status := #busy;
                let refunds = Buffer.Buffer<Refund>(fs.pending.size());
                label l loop {
                  if ( Option.isNull( DQ.peekFront<MultiLock>( fs.buyers ) ) ) break l;
                  switch( DQ.popFront<MultiLock>( fs.buyers ) ){
                    case null ();
                    case ( ?(lock, multilock) ){
                      fs.buyers := multilock;
                      refunds.add(lock.0,lock.1);
                    }
                  }
                };
                for ( buyer in fs.pending.vals() ) refunds.add(buyer.0,buyer.1);
                for ( refund in refunds.vals() ) m.refunds := DQ.pushBack<Refund>(m.refunds, refund);
                m.listings[i] := #delisted( Time.now() );
                m.locks[i] := #unlocked(0);
                #ok()
              }
            }
          }
        }
      }
    }
  };

  public func list( m : Market, i : Index, s : Principal, p : Price, a : Allowance ) : Return<()> {
    assert m.init;
    set_range(m, i);
    switch( m.locks[i] ){
      case ( #locked _ ) #err(#Locked);
      case ( #firesale _ ) #err(#Locked);
      case ( #unlocked _ ) {
        switch( Fees.check_allowance(m.fees, a) ){
          case ( #err val ) #err val;
          case ( #ok ){
            switch( m.listings[i] ){
              case ( #listed listing ){
                m.listings[i] := #listed({
                  seller = listing.seller;
                  royalty = listing.royalty;
                  var locked = null;
                  allowance = a;
                  price = p;
                });
                #ok()
              };
              case( #delisted last ){
                var last_listing : Time = 0;
                if ( last == -1 ) last_listing := m.genesis
                else last_listing := last;
                m.listings[i] := #listed({
                  royalty = Fees.royalty(m.fees, last_listing);
                  var locked = null;
                  allowance = a;
                  seller = s;
                  price = p;
                });
                #ok()
              }
            }
          }
        }
      }
    }
  };

  public func is_locked( m : Market, i : Index ) : Bool {
    switch( m.locks[i] ){
      case ( #unlocked _ ) false;
      case _ true
    }
  };

  public func active_firesale( m : Market, i : Index ) : Bool {
    switch( m.locks[i] ){
      case ( #firesale _ ) true;
      case _ false
    }
  };

  public func locks( m : Market ) : [(Index,SharedLock)] {
    assert m.init;
    var last : Nat = 0;
    if( m.range > 1 ) last := m.range - 1;
    let buffer = Buffer.Buffer<(Index,SharedLock)>(0);
    for ( i in Iter.range(0,last) ){
      switch( m.locks[i] ){
        case ( #unlocked _ )();
        case ( #firesale _ ){
          buffer.add(
            (i, {
              firesale = true;
              buyer = null;
              subaccount = null;
              fees = null;
              status = #idle;
            })
          )
        };
        case ( #locked lock ){
          buffer.add(
            (i, {
              firesale = false;
              buyer = ?lock.buyer;
              subaccount = ?lock.subaccount;
              fees = ?lock.fees;
              status = lock.status;
            })
          )
        }
      }
    };
    Buffer.toArray<(Index,SharedLock)>(buffer);
  };

  public func lock( m : Market, i : Index, c : Principal, b : AccountId, p : Nat64, f : [(AccountId,Nat64)] ) : Return<AccountId> {

    assert m.init and ( i < m.range );

    switch( m.listings[i] ){
      case ( #delisted _ ) #err(#NoListing);
      case ( #listed listing ){

        if ( not Fees.allowed(m.fees, f, listing.allowance) ) return #err(#FeeTooHigh(listing.allowance));
        if ( listing.price != p ) return #err(#PriceChange(listing.price));

        let _fees = Buffer.fromArray<(AccountId,Nat64)>(f);
        _fees.add((m.royalty, listing.royalty));

        switch( m.locks[i] ){

          case ( #locked _ ) #err(#Locked);

          case ( #firesale fs ){

            if ( Principal.Set.match(fs.principals, c)) return #err(#Locked)
            else {

              let _sa : SubAccount = nat_to_subaccount( m.next_sa );
              let pending_sales = Buffer.fromArray<MultiLock>(fs.pending);
              pending_sales.add((b, _sa, Buffer.toArray<(AccountId,Nat64)>( _fees )));
              fs.pending := Buffer.toArray<MultiLock>( pending_sales );
              fs.principals := Principal.Set.insert(fs.principals, c);
              #ok( AccountId.fromPrincipal(m.escrow, ?_sa) );
            }
          };

          case ( #unlocked timeouts ) {

            if ( timeouts < m.fs_threshold ){

              // Timeouts have not triggered a fire sale; lock normally.
              let _sa : SubAccount = nat_to_subaccount( m.next_sa );
              m.locks[i] := #locked({
                buyer = b;
                subaccount = _sa;
                var status = #idle;
                fees = Buffer.toArray( _fees );
                timeouts = timeouts;
              });
              m.next_sa += 1;
              listing.locked := ?Time.now();
              #ok( AccountId.fromPrincipal(m.escrow, ?_sa) )

            } else {

              /// IT'S A FIRE SALE!!!!
              let _sa : SubAccount = nat_to_subaccount( m.next_sa );
              let buyer_queue = DQ.empty<MultiLock>();
              m.locks[i] := #firesale({
                timeouts = timeouts;
                var pending = [];
                var delist = false;
                var principals = Principal.Set.fromArray([c]); 
                var buyers = DQ.pushBack<MultiLock>(buyer_queue, (b, _sa, Buffer.toArray( _fees )));
                var status = #idle;
              });
              #ok( AccountId.fromPrincipal(m.escrow, ?_sa) )
            }

          }

        }
      }
    }
  };

  public func settle( m : Market, i : Index, c : ?Principal ) : async Return<AccountId> {

    assert m.init;

    switch( m.locks[i] ){

      case ( #unlocked _ ) #err(#NotLocked);

      case ( #firesale fs ){

        switch( fs.status ){

          case ( #busy ) #err(#Busy);

          case ( #idle ){

            // If a delisting has been requested cancel the firesale
            if ( fs.delist ) { 
              switch( delist(m, i) ){
                case ( #ok ) return #err(#NotLocked);
                case ( #err _ )();
              }
            };

            // // only proceed if the settle call was issued with intent
            // if ( Option.isNull(c) ) return #err(#Busy);
            // let claimant : Principal = Option.get<Principal>(c, Principal.placeholder());

            // Atomicity protection
            fs.status := #busy;
            
            switch( m.listings[i] ){
  
              case ( #delisted _ ) #err( #Fatal("Market corrupted: Locked but not listed") );

              case ( #listed listing ){

                var response : Return<AccountId> = #err(#Busy);
                let seller : AccountId = AccountId.fromPrincipal(listing.seller, null);

                // Fold pendings buyers into active buyer queue
                for ( pending in fs.pending.vals() ) fs.buyers := DQ.pushBack<MultiLock>(fs.buyers, pending);

                // Reset the pending buyer queue
                fs.pending := [];

                // Boolean to indicate if a successful payment was found
                var paid : Bool = false;

                // Iterate over the active buyer queue; assessing escrow balance. Break if paid or all accounts assessed.
                let unpaid = Buffer.Buffer<MultiLock>(0);
                label l loop {

                  if paid break l; // Payment fulfilled
                  if ( Option.isNull( DQ.peekFront<MultiLock>( fs.buyers ) ) ) break l; // All accounts assessed

                  switch( DQ.popFront<MultiLock>( fs.buyers ) ){
                    case null (); // Will never happen ( see Option.isNull above ^ )
                    case ( ?(lock, multilock) ){

                      fs.buyers := multilock;
                      
                      let escrow : AccountId = AccountId.fromPrincipal(m.escrow, ?lock.1);

                      // Query the escrow account balance
                      try {
                        let balance = await Ledger.account_balance( escrow );
                        if ( balance.e8s < listing.price ) unpaid.add(lock)
                        else {

                          for ( (address, amount) in Fees.distributions(seller, listing.price, lock.2) ){
                            add_disbursement(m, (i, address, Blob.fromArray(lock.1), amount))
                          };

                          // Record the transaction
                          ignore add_transaction(m, i, listing.seller, lock.0, listing.price);

                          m.listings[i] := #delisted(Time.now());
                          m.locks[i] := #unlocked(0);
                          response := #ok( lock.0 );
                          paid := true;

                        }
                      } catch(e) unpaid.add(lock)
                    }
                  }
                };

                if ( not paid ){

                  // set the response to return an error
                  response := #err(#InsufficientFunds);

                  // Return unpaid buyers to active buyer queue
                  for ( lock in unpaid.vals() ){
                    fs.buyers := DQ.pushBack<MultiLock>(fs.buyers, lock)
                  }

                }
                else {

                  // We need to make one last attempt to refund buyers who didn't receive the token
                  let refunds = Buffer.Buffer<Refund>( unpaid.size() );

                  // Queue unpaid buyers for final refund assessments
                  for ( lock in unpaid.vals() ) refunds.add(lock.0, lock.1);

                  // We may have had pending buyers added during escrow balance queries
                  for ( lock in fs.pending.vals() ) refunds.add(lock.0, lock.1);

                  // Finally, add remaining buyers from active queue to the refund queue;
                  label l loop {
                    if ( Option.isNull( DQ.peekFront<MultiLock>( fs.buyers ) ) ) break l; // All accounts queued
                    switch( DQ.popFront<MultiLock>( fs.buyers ) ){
                      case null (); // Will never happen ( see Option.isNull above ^ )
                      case ( ?(lock, multilocks) ){
                        fs.buyers := multilocks;
                        refunds.add(lock.0, lock.1)
                      }
                    }
                  };

                  for ( refund in refunds.vals() ){
                    m.refunds := DQ.pushBack<Refund>(m.refunds, refund)
                  };

                };

                response

              }
            }
          }
        }
      };

      case ( #locked lock ){

        switch( lock.status ){

          case ( #busy ) #err(#Busy);

          case ( #idle ){

            // Atomicity protection
            lock.status := #busy;

            switch( m.listings[i] ){

              case ( #delisted _ ) #err( #Fatal("Market corrupted: Locked but not listed") );

              case ( #listed listing ){

                let seller : AccountId = AccountId.fromPrincipal(listing.seller, null);
                let escrow : AccountId = AccountId.fromPrincipal(m.escrow, ?lock.subaccount);

                switch( listing.locked ){

                  case null #err( #Fatal("Market corrupted: Listing not locked while locks exists") );

                  case ( ?time ){

                    // Query the escrow account balance
                    var balance : Tokens = { e8s = 0 };
                    try {
                      balance := await Ledger.account_balance( escrow );
                    } catch(e) {
                      // Release atomicity lock
                      lock.status := #idle;
                      return #err(#Fatal("Failed to contact Ledger canister"))
                    };

                    // Release expired locks
                    if ( (Time.now() - time) >= 600000000000 ){
                      if ( balance.e8s > Ledger.expected_fee ){
                        let bal : Nat64 = balance.e8s - Ledger.expected_fee;
                        add_disbursement(m, (i, lock.buyer, Blob.fromArray(lock.subaccount), bal));
                        listing.locked := null;
                        m.locks[i] := #unlocked(lock.timeouts + 1);
                        return #err(#LockExpired);
                      } else {
                        // Release atomicity lock
                        listing.locked := null;
                        m.locks[i] := #unlocked(lock.timeouts + 1);
                        return #err(#LockExpired)
                      }
                    };

                    // Verify escrow balance is greater than or equal to the listing price
                    if ( balance.e8s < listing.price ){
                      lock.status := #idle;
                      return #err(#InsufficientFunds);
                    };

                    // Assess escrow distributions ( fees + proceeds to seller )
                    for ( (address, amount) in Fees.distributions(seller, listing.price, lock.fees)){
                      add_disbursement(m, (i, address, Blob.fromArray(lock.subaccount), amount))
                    };

                    // Record the transaction
                    ignore add_transaction(m, i, listing.seller, lock.buyer, listing.price);

                    // Release the token and delist it
                    m.listings[i] := #delisted(Time.now());
                    m.locks[i] := #unlocked(0);
                    #ok( lock.buyer );
                  }
                }
              }
            }
          }
        }
      }
    }
  }; 

  public func query_disbursements( m : Market ) : [Disbursement] {
    var disbursements : DQ.Deque<Disbursement> = m.disbursements;
    let buffer = Buffer.Buffer<Disbursement>(0);
    label l loop {
      if ( Option.isNull( DQ.peekFront<Disbursement>( disbursements ) ) ) break l;
      switch( DQ.popFront<Disbursement>( disbursements ) ){
        case null buffer.add((0,"",Blob.fromArray([]),0));
        case ( ?(d, dq) ){
          disbursements := dq;
          buffer.add(d)
        }
      }
    };
    Buffer.toArray<Disbursement>( buffer );
  };

  public func disburse( m : Market ) : async () {
    assert m.init;
    let failed = Buffer.Buffer<Disbursement>(0);
    label l loop {
      if ( not peek_disbursement( m ) ) break l;
      let d : Disbursement = get_disbursement( m );
      try {
        switch( await Ledger.transfer(d.3, d.1, ?d.2) ){
          case ( #Err _ ) failed.add(d);
          case ( #Ok _ )() 
        }
      } catch ( e ) failed.add(d) 
    };
    for ( disbursement in failed.vals() ){
      m.disbursements := DQ.pushBack<Disbursement>(m.disbursements, disbursement)
    }
  };

  func add_disbursement( m : Market, d : Disbursement) : () {
    assert m.init;
    m.disbursements := DQ.pushBack<Disbursement>(m.disbursements, d);
  };

  func next_disbursement( m : Market ) : ?Disbursement {
    assert m.init;
    switch( DQ.popFront<Disbursement>( m.disbursements ) ){
      case null null;
      case ( ?(d, dq) ){
        m.disbursements := dq;
        ?d;
      };
    };
  };

  func peek_disbursement( m : Market ) : Bool {
    assert m.init;
    Option.isSome( DQ.peekFront<Disbursement>( m.disbursements ) );
  };

  func get_disbursement( m : Market ) : Disbursement {
    assert peek_disbursement( m );
    switch( DQ.popFront<Disbursement>( m.disbursements ) ){
      case null (0,"",Blob.fromArray([]),0);
      case ( ?(d, dq) ){
        m.disbursements := dq;
        d;
      };
    };
  };

  /// Refund Management & Processing
  public func query_refunds( m : Market ) : [Refund] {
    var refunds : DQ.Deque<Refund> = m.refunds;
    let buffer = Buffer.Buffer<Refund>(0);
    label l loop {
      if ( Option.isNull( DQ.peekFront<Refund>( refunds ) ) ) break l;
      switch( DQ.popFront<Refund>( refunds ) ){
        case null buffer.add(("",[]));
        case ( ?(r, dq) ){
          refunds := dq;
          buffer.add( r )
        }
      }
    };
    Buffer.toArray<Refund>( buffer );
  };

  public func refund( m : Market ) : async () {
    assert m.init;
    let failed = Buffer.Buffer<Refund>(0);
    label l loop {
      if ( not peek_refund( m ) ) break l;
      let (buyer, subaccount) : Refund = get_refund( m );
      let sa : Blob = Blob.fromArray(subaccount);
      try {
        let ({ e8s = amount }) = await Ledger.account_balance( AccountId.fromPrincipal(m.escrow, ?subaccount) );
        let balance = amount - Ledger.expected_fee;
        if ( balance > 0 ){
          switch( await Ledger.transfer(balance, buyer, ?sa) ){
            case ( #Err _ ) failed.add( (buyer, subaccount) );
            case ( #Ok _ )()
          }
        }
      } catch ( e ) failed.add( (buyer, subaccount) ) 
    };
    for ( refund in failed.vals() ){
      m.refunds := DQ.pushBack<Refund>(m.refunds, refund)
    }
  };

  func next_refund( m : Market ) : ?Refund {
    assert m.init;
    switch( DQ.popFront<Refund>( m.refunds ) ){
      case null null;
      case ( ?(r, dq) ){
        m.refunds := dq;
        ?r;
      };
    };
  };

  func peek_refund( m : Market ) : Bool {
    assert m.init;
    Option.isSome( DQ.peekFront<Refund>( m.refunds ) );
  };

  func get_refund( m : Market ) : Refund {
    assert peek_refund( m );
    switch( DQ.popFront<Refund>( m.refunds ) ){
      case null ("",[]);
      case ( ?(r, dq) ){
        m.refunds := dq;
        r;
      };
    };
  };

  func set_range( m : Market, i : Nat ): () {
    assert m.init;
    if ( m.range < i ){
      let size = 2 * m.range;
      let elemsX = Array.init<Listing>(size, #delisted(-1));
      let elemsY = Array.init<Lock>(size, #unlocked(0));
      var i = 0;
      label l loop {
        if (i >= m.range) break l;
        elemsX[i] := m.listings[i];
        elemsY[i] := m.locks[i];
        i += 1;
      };
      m.listings := elemsX;
      m.locks := elemsY;
    };
  };

  func add_transaction( m : Market, i : Index, s : Principal, b : AccountId, p : Nat64 ): Index {
    assert m.init;
    let current_size : Nat = m.transactions.elems.size();
    if ( m.transactions.size == current_size) {
      let size = 2 * current_size;
      let p : Transaction = tx_placeholder();
      var elems2 : [var Transaction] = [var];
      if ( size == 0 ) elems2 := Array.init<Transaction>(2, p)
      else elems2 := Array.init<Transaction>(size, p);
      var i = 0;
      label l loop {
        if (i >= m.transactions.size) break l;
        elems2[i] := m.transactions.elems[i];
        i += 1;
      };
      m.transactions.elems := elems2;
    };
    m.transactions.elems[m.transactions.size] := {
      token = tokenid(m, i);
      seller = s;
      price = p;
      buyer = b;
      time = Time.now();
    };
    let index : Index = m.transactions.size;
    m.transactions.size += 1;
    index;
  };

  func nat_to_subaccount( n : Nat ) : SubAccount {
    let n_byte = func(i : Nat) : Nat8 {
      assert(i < 32);
      let offset = n + 4294967396; //originally: 4294967296
      let shift : Nat = 8 * (32 - 1 - i);
      Nat8.fromIntWrap(offset / 2**shift)
    };
    Array.tabulate<Nat8>(32, n_byte)
  };

  func tx_placeholder() : Transaction {
    return {
      token = "";
      seller = Principal.placeholder();
      price = 0;
      buyer = "";
      time = 0;
    };
  };


};