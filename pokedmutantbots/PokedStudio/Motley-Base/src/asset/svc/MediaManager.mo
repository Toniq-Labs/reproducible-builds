import HB "../../../../../src/scheduling/heartbeat/Types";
import AS "../../../../../src/messaging/ActorSet";
import Cycles "mo:base/ExperimentalCycles";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import BD "../BlockDevice/BlockDevice";
import Principal "mo:base/Principal";
import Buffer "mo:base/Buffer";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import DQ "mo:base/Deque";
import SD "StorageDaemon";
import S "mo:base/Stack";
import T "../Types";


shared ({ caller = _installer }) actor class MediaManager( admin : Principal ) = this {

  type Index     = T.Index;
  type File      = T.File;
  type State     = T.Status;
  type Return<T> = T.Return<T>;
  type Request   = T.WriteRequest;
  type Strategy  = T.UploadStrategy;
  type Device    = T.StorageDevice;
  type Daemon    = SD.ServiceDaemon;
  type HBService = HB.HeartbeatService;
  type SaveCmd   = T.SaveCmd;

  type CyclesReport = {
    balance : Nat;
    transfer : shared () -> async ();
  };

  let _MAX_STATE_      : Nat         = 10;
  let _MAX_RESERVE_    : Nat         = 5;
  let _state           : [var State] = Array.init(_MAX_STATE_, #Null);
  stable var _INIT_    : Bool        = false;
  stable var _clock    : [HB.Task]   = [];
  stable var _managed  : [HB.Task]   = [];
  stable var _rescount : Nat         = 0;

  stable var _dependants : AS.ActorSet      = AS.init();
  private var _daemons   : DQ.Deque<Daemon> = DQ.empty();
  stable var _reserves   : DQ.Deque<Device> = DQ.empty();
  stable var _devices    : DQ.Deque<Device> = DQ.empty();

  public shared ({caller}) func write_request( request : Request, save : SaveCmd, secret : Text ) : async Return<Index> {
    assert Principal.equal(caller, _installer);
    for ( index in Iter.range(0, (_MAX_STATE_ - 1)) ){
      switch( _state[index] ){
        case( #Null ){
          _state[index] := #Reserved;
          spawn_daemon(index,request,save,secret);
          return #ok(index);
        };
        case(_){};
      };
    };
    #err(#ServiceLimit);
  };

  public shared ({caller}) func request_instruction( index : Index ) : async Return<Strategy> {
    switch( _state[index] ){
      case( #Finished(strategy,delegate) ){
        if ( Principal.equal(caller,delegate) ){
          switch( await strategy() ){
            case( null ){ return #err(#TryAgain) };
            case( ?strat ){
              _state[index] := #Null;
              #ok(strat);
            };
          };
        } else { #err( #Unauthorized ) };
      };
      case(_){
        #err( #Busy );
      };
    };
  };

  var _tick : Nat = 0;
  public shared ({caller}) func clock() : () {
    if ( Nat.rem(_tick, 1) == 0 ){
      assert Principal.equal(caller, _installer);
      let stack = S.Stack<Daemon>();
      while( not DQ.isEmpty<Daemon>(_daemons) ){
        switch( DQ.popBack<Daemon>(_daemons) ){
          case( null ){ assert false };
          case( ?(dq, daemon) ){
            _daemons := dq;
            switch( daemon.state){
              case( #Ready ){
                ignore daemon.map();
                stack.push(daemon);
              };
              case( #Mapped ){
                ignore daemon.format();
                stack.push(daemon);
              };
              case( #Delete ){};
              case(_){ stack.push(daemon) };
        }}}};
      while ( not stack.isEmpty() ){
        switch( stack.pop() ){
          case( ?daemon ){_daemons := DQ.pushBack<Daemon>(_daemons, daemon)};
          case( null ){};
        };
      };
      if ( _rescount < _MAX_RESERVE_ ){
        _rescount += 1;
        let new : Device = await new_device();
        _reserves := DQ.pushFront<Device>(_reserves, new); 
      };
    };
    _tick += 1;
  };

  // ======================================================================== //
  // Cycles Management Interface                                              //
  // ======================================================================== //
  //
  public shared query ({caller}) func dependants() : async [Text] {
    assert Principal.equal(caller, admin);
    AS.toArray(_dependants);
  };
  public shared ({caller}) func reclaim() : async () {
    assert Principal.equal(caller, admin);
    let _self : Principal = Principal.fromActor(this);
    let IC : T.IC = actor("aaaaa-aa");
    await IC.update_settings({
      canister_id = _self;
      settings = { controllers = [admin] };
    });
  };
  public shared func acceptCycles() : async () {
    let available = Cycles.available();
    let accepted = Cycles.accept(available);
    assert (accepted == available);
  };
  public shared ({caller}) func send_cycles( p : Text ) : async () {
    assert Principal.equal(caller, admin);
    type Target = actor { acceptCycles : shared () -> async () };
    let target : Target = actor(p);
    let available : Nat = Cycles.balance();
    let amount : Nat = (available - 50000000000);
    Cycles.add(amount);
    await target.acceptCycles();
  };
  public shared ({caller}) func request_report() : () {
    assert Principal.equal(caller, _installer);
    let bal = Cycles.balance();
    let hbsvc : HBService = actor(Principal.toText(_installer));
    hbsvc.report_balance({balance = bal; transfer = acceptCycles});
  };
  public shared ({caller}) func report_balance( report : CyclesReport ) : () {
    assert AS.match(_dependants, caller);
    if ( report.balance < 2000000000000 ){
      let balance : Nat = Cycles.balance();
      let topup : Nat = 3000000000000 - report.balance;
      if ( balance > (topup + 5000000000000) ){
        Cycles.add(topup);
        await report.transfer();
      };
    };
  }; 

  // ======================================================================== //
  // Private Methods                                                          //
  // ======================================================================== //
  //
  func reserve( size : T.BlockCount ) : async Device {
    let stack = S.Stack<Device>();
    func reverse() : () {
      Debug.print("Reverse devices");
      while ( not stack.isEmpty() ){
        switch( stack.pop() ){
          case( null ){};
          case( ?device ){
            Debug.print(Principal.toText(device.principal) # " added back to deque");
            _devices := DQ.pushBack<Device>(_devices, device);
      }}}};
    while ( not DQ.isEmpty<Device>(_devices) ){
      switch( DQ.popBack<Device>(_devices) ){
        case( null ){ assert false };
        case( ?(dq, device) ){
          Debug.print("Used device " # Principal.toText(device.principal) # " found");
          Debug.print("Available: " # Nat.toText(device.available) # " Size: " # Nat.toText(size));
          _devices := dq;
          if( device.available >= size ){
            reverse();
            return device;
          } else {
            stack.push(device);
      }}}};
    reverse();
    if ( not DQ.isEmpty<Device>(_reserves) ){
      switch( DQ.popBack<Device>(_reserves) ){
        case( null ){ assert false };
        case( ?(dq, device) ){
          _reserves := dq;
          if (_rescount > 0 ){ _rescount -= 1 };
          return device;
        };
      };
    };
    await new_device();
  };

  func release( device : Device ) : () {
    if ( device.available == T.SectorCount.blocks(1) ){
      _reserves := DQ.pushFront<Device>(_reserves,device);
      _rescount += 1;
    } else {
      _devices := DQ.pushFront<Device>(_devices, device);
    };
  };

  func set_state( index : Index, state : State ) : () {
    _state[index] := state;
  };

  func add_task( tasks : [HB.Task], task : HB.Task ) : [HB.Task] {
    let buff = Buffer.fromArray<HB.Task>(tasks);
    buff.add(task);
    Buffer.toArray(buff);
  };

  func new_device() : async Device {
    Cycles.add(5000000000000);
    let t_actor : BD.BlockDevice = await BD.BlockDevice(admin);
    let t_principal : Principal = Principal.fromActor(t_actor);
    let device : Device = {
      open = t_actor.open;
      close = t_actor.close;
      principal = t_principal;
      available = T.SectorCount.blocks(1);
    };
    _clock := add_task(_clock, t_actor.clock);
    _managed := add_task(_managed, t_actor.request_report);
    _dependants := AS.put(_dependants, Principal.toText(t_principal));
    let IC : T.IC = actor("aaaaa-aa");
    await IC.update_settings({
      canister_id = t_principal;
      settings = { controllers = [t_principal] };
    });
    return device;
  };

  func spawn_daemon( index : Index, request : Request, save : SaveCmd, secret : Text ) : () {
    _daemons := DQ.pushFront(
      _daemons, SD.ServiceDaemon(
        index,
        request,
        save,
        set_state,
        reserve,
        release,
        secret,
      )
    );
  };

};