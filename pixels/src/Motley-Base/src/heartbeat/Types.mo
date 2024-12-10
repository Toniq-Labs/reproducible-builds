import Hash "mo:base/Hash";
import Trie "mo:base/Trie";
import Int "mo:base/Int";

module {

  public type Interval = Int;
  public type Task = shared() -> ();

  public type ChainReport = {
    #report : CyclesReport;
    #ping;
  };

  public type CyclesReport = {
    balance : Nat;
    transfer : shared () -> async ();
  };

  public type HeartbeatService = actor {
    schedule : shared ([ScheduledTask]) -> async ();
    report_balance : shared (CyclesReport) -> ();
  };

  public type ChildService = actor {
    chain_report : shared (ChainReport) -> ();
  };

  public type ScheduledTask = {
    interval : Interval;
    tasks : [Task];
  };

  public module Intervals = {

    public let _01beats : Interval = 1;
    public let _05beats : Interval = 5;
    public let _10beats : Interval = 10;
    public let _15beats : Interval = 15;
    public let _30beats : Interval = 30;
    public let _45beats : Interval = 45;
    public let _60beats : Interval = 60;
    public let _02rounds : Interval = 120;
    public let _05rounds : Interval = 540;
    public let _10rounds : Interval = 1080;
    public let _15rounds : Interval = 1620;
    public let _30rounds : Interval = 3240;
    public let _45rounds : Interval = 4860;
    public let _60rounds : Interval = 6480;
    public let _02cycles : Interval = 12960;
    public let _04cycles : Interval = 25920;
    public let _08cycles : Interval = 51840;
    public let _12cycles : Interval = 77760;
    public let _24cycles : Interval = 155520;
  };

  public module Interval = {
    
    public func hash( x : Interval ) : Hash.Hash {Int.hash(x)};
    public func equal( x : Interval, y : Interval ) : Bool {Int.equal(x,y)};
    public func rem( x : Interval, y : Interval ) : Int {Int.rem(x, y)};
    public func key( x : Interval ) : Trie.Key<Interval> {
      let h : Hash.Hash = hash(x);
      return { hash = h; key = x };
    };

  };

};