import { Ledger } "../../base/ic0/Ledger";
import Principal "../../base/Principal";
import AccountId "../../base/AccountId";
import TokenId "../../nft/TokenId";
import Index "../../base/Index";
import Time "../../base/Time";
import Blob "mo:base/Blob";
import DQ "mo:base/Deque";
import Iter "mo:base/Iter";
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Array "mo:base/Array";
import Option "mo:base/Option";
import Buffer "mo:base/Buffer";

module Market {

  type Time = Time.Time;
  type Index = Index.Index;
  type TokenId = TokenId.TokenId;
  type AccountId = AccountId.AccountId;
  type SubAccount = AccountId.SubAccount;
  public type Disbursement = (Index, AccountId, Blob, Nat64);
  type Tokens = {e8s : Nat64};

  type Return<T> = { #ok : T; #err : Error };

  public type Error = {
    #FeeTooHigh : Nat64;
    #PriceChange : Nat64;
    #InsufficientFunds;
    #Fatal : Text;
    #NotLocked;
    #NoListing;
    #Locked;
    #Busy;
  };

  public type Market = {
    var init          : Bool;
    var range         : Nat;
    var txcount       : Nat;
    var next_sa       : Nat;
    var base_fee      : Nat64;
    var max_fee       : Nat64;
    var escrow        : Principal;
    var royalty       : AccountId;
    var locks         : [var ?Lock];
    var listings      : [var ?Listing];
    var transactions  : [var Transaction];
    var disbursements : DQ.Deque<Disbursement>;
  };

  public type Listing = {
    seller : Principal;
    price : Nat64;
    locked : ?Time;
  };

  public type Lock = {
    seller     : Principal;
    buyer      : AccountId;
    subaccount : SubAccount;
    price      : Nat64;
    var status : { #idle; #busy };
    fees       : [(AccountId, Nat64)];
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
      var txcount       = 0;
      var base_fee      = 0;
      var max_fee       = 0;
      var escrow        = Principal.placeholder();
      var royalty       = "";
      var next_sa       = 0;
      var locks         = [var];
      var listings      = [var];
      var transactions  = [var];
      var disbursements = DQ.empty<Disbursement>()
    };
  };

  public func init(
    m : Market,
    c : Principal,
    base : Nat64,
    max : Nat64,
    addr : AccountId,
    size : Nat
  ) : () {
      assert ( ( max > base ) and ( max <= 100000 ) );
      assert size > 0;
      m.range := size;
      m.escrow := c;
      m.base_fee := base;
      m.max_fee := max;
      m.royalty := addr;
      m.locks := Array.init(size, null);
      m.listings := Array.init(size, null);
      m.init := true;
  };

  // public func share( m : Market ) : MarketState {
  //   return {
  //     range = m.range;
  //     txcount = m.txcount;
  //     next_sa = m.next_sa;
  //     init = m.init;
  //     base_fee = m.base_fee;
  //     max_fee = m.max_fee;
  //     escrow = m.escrow;
  //     royalty = m.royalty;
  //     locks = Array.freeze<?Lock>(m.locks);
  //     listings = Array.freeze<?Listing>(m.listings);
  //     transactions  = Array.freeze<Transaction>(m.transactions);
  //     disbursements = m.disbursements;
  //   };
  // };

  public func tokenid( m : Market, i : Index ) : TokenId {
    TokenId.fromPrincipal(m.escrow, Nat32.fromNat(i));
  };

  public func transactions( m : Market ) : [Transaction] {
    Array.freeze<Transaction>( m.transactions );
  };

  public func is_listed( m : Market, i : Index ) : Bool { Option.isSome(m.listings[i]) };

  public func get_listing( m : Market, i : Index ) : ?Listing {
    assert i < m.range;
    m.listings[i];
  };

  public func listings( m : Market ) : [(Index,Listing)] {
    assert m.init;
    var last : Nat = 0;
    if( m.range > 1 ) last := m.range - 1;
    let buffer = Buffer.Buffer<(Index,Listing)>(0);
    for ( i in Iter.range(0,last) ){
      switch( m.listings[i] ){
        case ( ?listing ) buffer.add((i,listing));
        case null ();
      }
    };
    Buffer.toArray<(Index,Listing)>(buffer);
  };

  public func delist( m : Market, i : Index ) : Return<()> {
    assert m.init;
    set_range(m, i);
    switch( m.locks[i] ){
      case ( ?lock ) #err(#Locked);
      case null {
        m.listings[i] := null;
        #ok()
      }
    }
  };

  public func list( m : Market, i : Index, s : Principal, p : Nat64 ) : Return<()> {
    assert m.init;
    set_range(m, i);
    switch( m.locks[i] ){
      case ( ?lock ) #err(#Locked);
      case null {
        m.listings[i] := ?{
          seller = s;
          price = p;
          locked = null;
        };
        #ok()
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
    if ( not is_fee_allowed(m, f) ) return #err(#FeeTooHigh(m.max_fee));
    switch( m.listings[i] ){
      case null #err(#NoListing);
      case ( ?listing ){
        if ( listing.price != p ) return #err(#PriceChange(listing.price));
        switch( m.locks[i] ){
          case ( ?lock ) #err(#Locked);
          case null {
            let _fees = Buffer.fromArray<(AccountId,Nat64)>(f);
            _fees.add((m.royalty, m.base_fee));
            let _sa : SubAccount = nat_to_subaccount( m.next_sa );
            m.locks[i] := ?{
              buyer = b;
              seller = listing.seller;
              price = listing.price;
              var status = #idle;
              subaccount = _sa;
              fees = Buffer.toArray( _fees );
            };
            m.next_sa += 1;
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
            let seller : AccountId = AccountId.fromPrincipal(lock.seller, null);
            let escrow : AccountId = AccountId.fromPrincipal(m.escrow, ?lock.subaccount);
            try {
              let balance = await Ledger.account_balance( escrow );
              if ( balance.e8s < lock.price ){
                lock.status := #idle;
                return #err(#InsufficientFunds);
              }
            } catch (e) { 
              lock.status := #idle;
              return #err(#Fatal("Failed to contact Ledger canister"))
            };
            var bal : Nat64 = lock.price - (Ledger.expected_fee * Nat64.fromNat(lock.fees.size() + 1));
            var rem : Nat64 = bal;
            for ( f in lock.fees.vals() ){
              let fee : Nat64 = bal * f.1 / 100000;
              add_disbursement(m, (i, f.0, Blob.fromArray(lock.subaccount), fee));
              rem := rem - fee;
            };
            add_disbursement(m, (i, seller, Blob.fromArray(lock.subaccount), rem));
            ignore add_transaction(m, i, lock.seller, lock.buyer, lock.price);
            m.listings[i] := null;
            m.locks[i] := null;
            #ok(lock.buyer);
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

  func is_fee_allowed( m : Market, f : [(AccountId,Nat64)] ) : Bool {
    assert m.init;
    var requested : Nat64 = Array.foldLeft<(AccountId,Nat64),Nat64>(
      f, 0, func (x,y) : Nat64 { x + y.1 }
    );
    requested += m.base_fee;
    if ( requested > m.max_fee ) false
    else true;
  };

  func set_range( m : Market, i : Nat ): () {
    assert m.init;
    if ( m.range < i ){
      let size = 2 * m.range;
      let elemsX = Array.init<?Listing>(size, null);
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
    let current_size : Nat = m.transactions.size();
    if ( m.txcount == current_size) {
      let size = 2 * current_size;
      let p : Transaction = tx_placeholder();
      var elems2 : [var Transaction] = [var];
      if ( size == 0 ) elems2 := Array.init<Transaction>(2, p)
      else elems2 := Array.init<Transaction>(size, p);
      var i = 0;
      label l loop {
        if (i >= m.txcount) break l;
        elems2[i] := m.transactions[i];
        i += 1;
      };
      m.transactions := elems2;
    };
    m.transactions[m.txcount] := {
      token = tokenid(m, i);
      seller = s;
      price = p;
      buyer = b;
      time = Time.now();
    };
    let index : Index = m.txcount;
    m.txcount += 1;
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