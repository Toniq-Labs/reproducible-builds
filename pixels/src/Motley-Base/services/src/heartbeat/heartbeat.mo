import HB "../../../Motley-Base/src/heartbeat/Types";
import TL "../../../Motley-Base/src/heartbeat/TaskList";
import TR "../../../Motley-Base/src/heartbeat/TaskRegistry";
import SC "../../../Motley-Base/src/heartbeat/Schedule";
import Cycles "../../../Motley-Base/src/base/Cycles";
import Principal "../../../Motley-Base/src/base/Principal";
import Option "mo:base/Option";
import Result "mo:base/Result";
import Array "mo:base/Array";


shared ({ caller = _installer }) actor class Heartbeat() = this {

  // ========================================================================= //
  // Type Definitions                                                          // 
  // ========================================================================= //
  //
  private type ScheduledTask = HB.ScheduledTask;
  private type TaskList = TL.TaskList;
  private type TaskRegistry = TR.TaskRegistry;
  private type Schedule = SC.Schedule;
  private type TextError = Result.Result<(),Text>;
  private type CyclesReport = {
    balance : Nat;
    transfer : shared () -> async ();
  };

  // ======================================================================== //
  // Stable Memory                                                            //
  // ======================================================================== //
  private stable var _INIT_ : Bool = false;
  private stable var _TICK_ : Int = 0;
  private stable var _MIN_CYCLES_ : Nat = 2000000000000;
  private stable var _MAX_CYCLES_ : Nat = 4000000000000;
  private stable var _tasks : Any = null;
  private stable var _registry : TaskRegistry = TR.empty();
  private stable var _schedule : Schedule = SC.empty();
  private stable var _services : Principal.Set = Principal.Set.init();
  private stable var _admins : Principal.Set = Principal.Set.init();

  // ======================================================================== //
  // Public Interface                                                         //
  // ======================================================================== //
  public shared ({caller}) func init() : async TextError {
    assert Principal.equal(caller, _installer) and not _INIT_;
    let _ = _set_admins([Principal.toText(_installer)]);
    _INIT_ := true;
    return #ok();
  };
  public shared ({caller}) func schedule( tasks : [ScheduledTask] ) : async () {
    assert Principal.Set.match(_services, caller) and _INIT_;
    let svc : Text = Principal.toText(caller);
    var t_tasklist : TaskList = TL.empty();
    for ( task in tasks.vals() ){ 
      t_tasklist := TL.schedule_task(t_tasklist, task);
      _schedule := SC.add(_schedule, task.interval, svc);
    };
    _registry := TR.put(_registry, svc, t_tasklist);
  };
  type Thresholds = {min: Nat; max: Nat};
  public shared ({caller}) func set_cycle_thresholds( min : ?Nat, max : ?Nat ) : async Thresholds {
    assert Principal.Set.match(_admins, caller) and _INIT_;
    _MIN_CYCLES_ := Option.get(min, _MIN_CYCLES_);
    _MAX_CYCLES_ := Option.get(max, _MAX_CYCLES_);
    return { min = _MIN_CYCLES_; max = _MAX_CYCLES_};
  };
  public shared query func get_cycle_thresholds() : async Thresholds {
    return { min = _MIN_CYCLES_; max = _MAX_CYCLES_};
  };
  public shared ({caller}) func add_service( svc : Text ) : async [Text] {
    assert Principal.Set.match(_admins, caller) and _INIT_;
    _add_service(svc);
  };
  public shared ({caller}) func remove_service( svc : Text ) : async [Text] {
    assert Principal.Set.match(_admins, caller) and _INIT_;
    _remove_service(svc);
  };
  public shared ({caller}) func set_services( sa : [Text] ) : async [Text] {
    assert Principal.Set.match(_admins, caller) and _INIT_;
    _set_services(sa);
  };
  public shared query ({caller}) func services() : async [Text] {
    Array.map<Principal,Text>(Principal.Set.toArray(_services), Principal.toText);
  };
  public shared ({caller}) func add_admin( admin : Text ) : async [Text] {
    assert Principal.Set.match(_admins, caller) and _INIT_;
    _add_admin(admin);
  };
  public shared ({caller}) func remove_admin( admin : Text ) : async [Text] {
    assert Principal.Set.match(_admins, caller) and _INIT_;
    _remove_admin(admin);
  };
  public shared ({caller}) func set_admins( ta : [Text] ) : async [Text] {
    assert Principal.Set.match(_admins, caller) and _INIT_;
    _set_admins(ta);
  };
  public shared query ({caller}) func admins() : async [Text] {
    Array.map<Principal,Text>(Principal.Set.toArray(_admins), Principal.toText);
  }; 

  // ======================================================================== //
  // Cycles Management Interface                                              //
  // ======================================================================== //
  //
  public shared func acceptCycles() : async () {
    let available = Cycles.available();
    let accepted = Cycles.accept(available);
    assert (accepted == available);
  };
  public shared ({caller}) func report_balance( report : CyclesReport ) : () {
    assert Principal.Set.match(_services, caller) and _INIT_;
    if ( report.balance < _MIN_CYCLES_ ){
      let topup : Nat = _MAX_CYCLES_ - report.balance;
      if ( Cycles.balance() > (topup + _MIN_CYCLES_) ){
        Cycles.add(topup);
        await report.transfer();
      };
    };
  }; 
  public query func availableCycles() : async Nat {
    return Cycles.balance();
  };

  // ======================================================================== //
  // System Methods                                                           //
  // ======================================================================== //
  //
  system func heartbeat() : async () {
    if _INIT_ {
      _TICK_ += 1;
      for ( interval in SC.intervals(_schedule) ){
        if ( HB.Interval.rem(_TICK_, interval) == 0 ){
          for ( service in SC.services_by_interval(_schedule, interval) ){
            for ( task in TR.tasks_by_svc_interval(_registry, service, interval) ){ task() };
        }}};
      if ( _TICK_ == 155520 ){ _TICK_ := 0 };
    };
  };

  // ======================================================================== //
  // Private Functions                                                        //
  // ======================================================================== //
  //
  // Add, remove, and get service canister addresses
  //
  func _add_service( t : Text ) : [Text] {
    _services := Principal.Set.insert(_services, Principal.fromText(t));
    Array.map<Principal,Text>(Principal.Set.toArray(_services), Principal.toText);
  };
  func _remove_service( t : Text ) : [Text] {
    _services := Principal.Set.insert(_services, Principal.fromText(t));
    Array.map<Principal,Text>(Principal.Set.toArray(_services), Principal.toText);
  };

  func _set_services( ta : [Text] ) : [Text] {
    _services := Principal.Set.fromArray(Array.map<Text,Principal>(ta, Principal.fromText));
    ta;
  };
  //
  // Update, modify, or get a list of admin principals
  //
  func _add_admin( t : Text ) : [Text] {
    _admins := Principal.Set.insert(_admins, Principal.fromText(t));
    Array.map<Principal,Text>(Principal.Set.toArray(_admins), Principal.toText);
  };

  func _remove_admin( t : Text ) : [Text] {
    _admins := Principal.Set.delete(_admins, Principal.fromText(t));
    Array.map<Principal,Text>(Principal.Set.toArray(_admins), Principal.toText);
  };

  func _set_admins( ta : [Text] ) : [Text] {
    _admins := Principal.Set.fromArray(Array.map<Text,Principal>(ta, Principal.fromText));
    ta;
  };

};