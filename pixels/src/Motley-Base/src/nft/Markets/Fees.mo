import Time "../../base/Time";
import { Ledger } "../../base/ic0/Ledger";
import AccountId "../../base/AccountId";
import Buffer "mo:base/Buffer";
import Array "mo:base/Array";
import Option "mo:base/Option";
import Nat64 "mo:base/Nat64";
import Iter "mo:base/Iter";
import Int "mo:base/Int";

module Fees {

  type AccountId = AccountId.AccountId;

  type Days = Nat;
  type Seconds = Nat;
  type Time = Time.Time;

  let whole_day : Seconds = 86400000000000;

  type Return<T> = { #ok : T; #err : Error };

  public type Error = {
    #ConfigError : Text;
    #FeeTooHigh : Fee;
    #FeeTooSmall : Fee;
  };

  public type Fee = Nat64;

  public type Fees = {
    var init         : Bool;
    var max_fee      : Fee;
    var min_fee      : Fee;
    var royalty      : Fee;
    var min_hodl     : Time;
    var max_hodl     : Time;
    var depreciating : Bool;
  };

  public func stage() : Fees {
    return {
      var init = false;
      var max_fee = 1000;
      var min_fee = 0;
      var royalty = 0;
      var min_hodl = 7 * whole_day;
      var max_hodl = 365 * whole_day;
      var depreciating = false;
    }
  };

  public func init(
    fees : Fees,
    _max_fee : Fee,
    _royalty : Fee,
    _min_hodl : ?Days,
    _max_hodl : ?Days,
  ) : Return<()> {
    if( _royalty > _max_fee ) return #err(#ConfigError("Royalty can't be larger than max fee"));
    if( _max_fee > 100000 or _max_fee < 1000 ) return #err(#ConfigError("Max fee must fall between 1000 - 100000"));
    let min_hodl : Days = Option.get<Days>(_min_hodl, 7);
    let max_hodl : Days = Option.get<Days>(_max_hodl, 365);
    if( max_hodl < min_hodl ) return #err(#ConfigError("Minimum days held can't be larger than the maximum"));
    if( min_hodl == 0 ) return #err(#ConfigError("Minimum days held can't be 0"));
    fees.min_hodl := min_hodl * whole_day;
    fees.max_hodl := max_hodl * whole_day;
    fees.max_fee := _max_fee;
    fees.royalty := _royalty;
    fees.init := true;
    #ok();
  };

  public func set_depreciating_royalty( fees : Fees, b : Bool ) : Return<()> {
    assert fees.init;
    fees.depreciating := b;
    #ok()
  };

  public func set_royalty( fees : Fees, fee : Fee ) : Return<()> {
    assert fees.init;
    if ( fee > fees.max_fee ) return #err(#ConfigError("Royalty can't be larger than max fee"));
    fees.royalty := fee;
    #ok()
  };

  public func set_minimum_fee( fees : Fees, fee : Fee ) : Return<()> {
    assert fees.init;
    if ( fee > fees.max_fee ) return #err(#ConfigError("Minimum fee can't be larger than the maximum fee"));
    fees.min_fee := fee;
    #ok()
  };

  public func set_maximum_fee( fees : Fees, fee : Fee ) : Return<()> {
    assert fees.init;
    if ( fee < fees.min_fee ) return #err(#ConfigError("Maximum fee can't be smaller than the minimum fee"));
    if ( fee > 100000 ) return #err(#ConfigError("Maximum fee must fall between 1000 - 100000"));
    fees.max_fee := fee;
    #ok()
  };

  public func set_maximum_hold( fees : Fees, days : Days ) : Return<()> {
    assert fees.init;
    if( days < fees.min_hodl ) return #err(#ConfigError("Minimum days held can't be larger than the maximum"));
    if( days == 0 ) return #err(#ConfigError("Maximum days held can't be 0"));
    let span = days * whole_day;
    fees.max_hodl := span;
    #ok()
  };

  public func set_minimum_hold( fees : Fees, days : Days ) : Return<()> {
    assert fees.init;
    if( days == 0 ) return #err(#ConfigError("Minimum days held can't be 0"));
    let span = days * whole_day;
    if( days > fees.max_hodl ) return #err(#ConfigError("Minimum days held can't be larger than the maximum"));
    fees.min_hodl := span;
    #ok()
  };

  public func check_allowance( fees : Fees, allowance : Nat64 ) : Return<()> {
    assert fees.init;
    if ( allowance < fees.min_fee ) #err(#FeeTooSmall(fees.min_fee))
    else if ( (fees.royalty + allowance) > fees.max_fee ) #err(#FeeTooHigh(fees.max_fee - fees.royalty))
    else #ok()
  };

  public func royalty( fees : Fees, last : Time ) : Fee {
    assert last < Time.now() and fees.init;
    if ( fees.depreciating == false ) return fees.royalty;
    let hodl : Time = Time.now() - last;
    if ( hodl < fees.min_hodl ) return fees.royalty;
    if ( hodl >= fees.max_hodl ) return 0;
    let span : Nat64 = Nat64.fromNat( Int.abs( fees.max_hodl ) / whole_day );
    let days_hodled : Nat64 = Nat64.fromNat( Int.abs( hodl ) / whole_day );
    let daily_credit : Nat64 = fees.max_fee / span;
    let royalty : Fee = fees.max_fee - days_hodled * daily_credit;
    return royalty       
  };

  public func distributions( seller : AccountId, price : Nat64, fees : [(AccountId,Nat64)] ) : Iter.Iter<(AccountId,Nat64)> {
    let count : Nat = fees.size() + 1;
    let balance : Nat64 = price - Ledger.expected_fee * Nat64.fromNat( count );
    let deductions = Buffer.Buffer<(AccountId,Nat64)>( count );
    var rem : Nat64 = balance;
    for ( fee in fees.vals() ){
      let deduction : Nat64 = balance * fee.1 / 100000;
      deductions.add((fee.0, deduction));
      rem -= deduction
    };
    deductions.add((seller, rem));
    deductions.vals();
  };

  public func allowed( f : Fees, fees : [(AccountId,Nat64)], allowance : Fee ) : Bool {
    assert f.init;
    var requested : Nat64 = Array.foldLeft<(AccountId,Nat64),Nat64>(
      fees, 0, func (x,y) : Nat64 { x + y.1 }
    );
    if ( allowance < f.min_fee ) false
    else if ( requested > allowance ) false
    else if ( (requested + f.royalty) <= f.max_fee ) true
    else false
  };

}