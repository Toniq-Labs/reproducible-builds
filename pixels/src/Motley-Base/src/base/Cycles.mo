import Prim "mo:⛔";
import Nat "mo:base/Nat";
import Error "mo:base/Error";
import Principal "Principal";

module Cycles {

  public let balance : () -> (amount : Nat) = Prim.cyclesBalance;

  public let available : () -> (amount : Nat) = Prim.cyclesAvailable;

  public let accept : (amount : Nat) -> (accepted : Nat) = Prim.cyclesAccept;

  public let add : (amount : Nat) -> () = Prim.cyclesAdd;

  public let refunded : () -> (amount : Nat) = Prim.cyclesRefunded;

  public module Manager {

    public type ChainReport = {
      #report : CyclesReport;
      #ping;
    };

    public type CyclesReport = {
      balance : Nat;
      transfer : shared () -> async ();
    };

    public type ChildService = actor {
      chain_report : shared (ChainReport) -> ();
    };

    public type Manager = {
      var dependants : Principal.Set;
      var lower_threshold : Nat;
      var upper_threshold : Nat;
      var balance : Nat;
    };

  };

  public class Transaction() = {

    assert ( Cycles.available() > 0 );
    var bal : Nat = Cycles.available();
    var avail : Nat = Cycles.balance();

    public func check( min : Nat ) : async () { // For Moc-7.4.0: make async*
      if ( available() < min ) throw Error.reject("insufficient cycles sent: " # Nat.toText(min) # " required");
      if ( avail > min ) avail := min;
    };

    public func settle( cost : {#q1; #q2; #q3; #all} ) : () {
      var charge : Nat = 0;
      switch( cost ){
        case ( #q1 ) charge := avail / 4;
        case ( #q2 ) charge := avail / 2;
        case ( #q3 ) charge := 3 * ( avail / 4 );
        case ( #all ) charge := avail;
      };
      if ( charge >= avail ) ignore Cycles.accept(avail)
      else ignore Cycles.accept(charge); 
    };

  };

}