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

  type Price = Nat64;
  type Allowance = Nat64;
  type Time = Time.Time;
  type Fee = Fees.Fee;
  type Fees = Fees.Fees;
  type Index = Index.Index;
  type TokenId = TokenId.TokenId;
  type AccountId = AccountId.AccountId;
  type SubAccount = AccountId.SubAccount;
  type Tokens = {e8s : Nat64};

  type Return<T> = { #ok : T; #err : Error };

  public type Disbursement = (Index, AccountId, Blob, Nat64);

  public type Error = {
    #ConfigError : Text;
    #FeeTooHigh : Nat64;
    #PriceChange : Nat64;
    #InsufficientFunds;
    #UnauthorizedMarket : AccountId;
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
    var royalty       : AccountId;
    var locks         : [var ?Lock];
    var listings      : [var Listing];
    var transactions  : Transactions;
    var disbursements : DQ.Deque<Disbursement>;
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
    buyer      : AccountId;
    subaccount : SubAccount;
    fees       : [(AccountId, Nat64)];
    var status : { #idle; #busy };
  };

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
      var royalty       = "";
      var next_sa       = 0;
      var locks         = [var];
      var listings      = [var];
      var transactions  = { var size = 0; var elems = [var] };
      var disbursements = DQ.empty<Disbursement>()
    };
  };

  public func init(
    m : Market,
    self : Principal,
    royalty : Nat64,
    max_fee : Nat64,
    creator : AccountId,
    size : Nat,
  ) : Return<()> {
    if( size == 0 ) return #err(#ConfigError("Projected inventory must be greater than 0"));
    if( not AccountId.valid( creator ) ) return #err(#ConfigError("Royalty address is not a valid Account ID"));
    switch( Fees.init(m.fees, max_fee, royalty, null, null) ){
      case ( #err val ) #err val;
      case ( #ok ){
        m.range := size;
        m.escrow := self;
        m.royalty := creator;
        m.locks := Array.init<?Lock>(size, null);
        m.listings := Array.init<Listing>(size, #delisted(-1));
        m.init := true;
        #ok()
      }
    }
  };

  public func tokenid( m : Market, i : Index ) : TokenId {
    TokenId.fromPrincipal(m.escrow, Nat32.fromNat(i));
  };

  public func transactions( m : Market ) : [Transaction] {
    Array.freeze<Transaction>( m.transactions.elems );
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
    switch( m.locks[i] ){
      case ( ?lock ) #err(#Locked);
      case null {
        m.listings[i] := #delisted( Time.now() );
        #ok()
      }
    }
  };

  public func list( m : Market, i : Index, s : Principal, p : Price, a : Allowance ) : Return<()> {
    assert m.init;
    set_range(m, i);
    switch( m.locks[i] ){
      case ( ?lock ) #err(#Locked);
      case null {
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
              case( #delisted last_listing ){
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

  public func is_locked( m : Market, i : Index ) : Bool { Option.isSome(m.locks[i]) };

  public func locks( m : Market ) : [(Index,Lock)] {
    assert m.init;
    var last : Nat = 0;
    if( m.range > 1 ) last := m.range - 1;
    let buffer = Buffer.Buffer<(Index,Lock)>(0);
    for ( i in Iter.range(0,last) ){
      switch( m.locks[i] ){
        case ( ?lock ) buffer.add((i,lock));
        case null ()
      }
    };
    Buffer.toArray<(Index,Lock)>(buffer);
  };

  public func lock( m : Market, i : Index, b : AccountId, p : Nat64, f : [(AccountId,Nat64)] ) : Return<AccountId> {
    assert m.init and ( i < m.range );
    switch( m.listings[i] ){
      case ( #delisted _ ) #err(#NoListing);
      case ( #listed listing ){
        if ( not Fees.allowed(m.fees, f) ) return #err(#FeeTooHigh(m.fees.max_fee - m.fees.royalty));
        if ( listing.price != p ) return #err(#PriceChange(listing.price));
        switch( m.locks[i] ){
          case ( ?lock ) #err(#Locked);
          case null {
            let _fees = Buffer.fromArray<(AccountId,Nat64)>(f);
            _fees.add((m.royalty, listing.royalty));
            let _sa : SubAccount = nat_to_subaccount( m.next_sa );
            m.locks[i] := ?{
              buyer = b;
              subaccount = _sa;
              var status = #idle;
              fees = Buffer.toArray( _fees );
            };
            m.next_sa += 1;
            listing.locked := ?Time.now();
            #ok( AccountId.fromPrincipal(m.escrow, ?_sa) )
          }
        }
      }
    }
  };

  public func settle( m : Market, i : Index ) : async Return<AccountId> {
    assert m.init;
    switch( m.locks[i] ){
      case null #err(#NotLocked);
      case ( ?lock ){
        switch( lock.status ){
          case ( #busy ) #err(#Busy);
          case ( #idle ){
            lock.status := #busy;
            switch( m.listings[i] ){
              case ( #delisted _ ) #err( #Fatal("Market corrupted: Locked but not listed") );
              case ( #listed listing ){
                let seller : AccountId = AccountId.fromPrincipal(listing.seller, null);
                let escrow : AccountId = AccountId.fromPrincipal(m.escrow, ?lock.subaccount);
                switch( listing.locked ){
                  case null #err( #Fatal("Market corrupted: Listing not locked while locks exists") );
                  case ( ?time ){
                    var balance : Tokens = { e8s = 0 };
                    try {
                      balance := await Ledger.account_balance( escrow );
                    } catch(e) {
                      lock.status := #idle;
                      return #err(#Fatal("Failed to contact Ledger canister"))
                    };
                    // Release expired locks
                    if ( (Time.now() - time) >= 600000000000 ){
                      if ( balance.e8s > Ledger.expected_fee ){
                        let bal : Nat64 = balance.e8s - Ledger.expected_fee;
                        add_disbursement(m, (i, lock.buyer, Blob.fromArray(lock.subaccount), bal));
                        listing.locked := null;
                        m.locks[i] := null;
                        return #err(#LockExpired);
                      } else {
                        listing.locked := null;
                        m.locks[i] := null;
                        return #err(#LockExpired)
                      }
                    };
                    if ( balance.e8s < listing.price ){
                      lock.status := #idle;
                      return #err(#InsufficientFunds);
                    };
                    for ( (address, amount) in Fees.distributions(seller, listing.price, lock.fees)){
                      add_disbursement(m, (i, address, Blob.fromArray(lock.subaccount), amount))
                    };
                    ignore add_transaction(m, i, listing.seller, lock.buyer, listing.price);
                    m.listings[i] := #delisted(Time.now());
                    m.locks[i] := null;
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
          buffer.add(d);
        };
      };
    };
    Buffer.toArray(buffer);
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

  func set_range( m : Market, i : Nat ): () {
    assert m.init;
    if ( m.range < i ){
      let size = 2 * m.range;
      let elemsX = Array.init<Listing>(size, #delisted(-1));
      let elemsY = Array.init<?Lock>(size, null);
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