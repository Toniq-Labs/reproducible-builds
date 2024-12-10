import Principal "../../../../Motley-Base/src/base/Principal";
import SD "../../../../Motley-Base/src/asset/StorageDaemon";
import HB "../../../../Motley-Base/src/heartbeat/Types";
import T "../../../../Motley-Base/src/asset/Types";
import Cycles "mo:base/ExperimentalCycles";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import BD "BlockDevice";
import Buffer "mo:base/Buffer";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import DQ "mo:base/Deque";
import S "mo:base/Stack";


shared ({ caller = _installer }) actor class MediaManager( admins : [Principal] ) = this {

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
  type ChainReport = HB.ChainReport;
  type ChildService = HB.ChildService;

  type CyclesReport = {
    balance : Nat;
    transfer : shared () -> async ();
  };

  let _MAX_STATE_      : Nat         = 10;
  let _MAX_RESERVE_    : Nat         = 5;
  var _daemons    : DQ.Deque<Daemon> = DQ.empty();
  let _state           : [var State] = Array.init(_MAX_STATE_, #Null);
  stable var _INIT_           : Bool        = false;
  stable var _clock           : [HB.Task]   = [];
  stable var _managed         : [HB.Task]   = [];
  stable var _rescount        : Nat         = 0;
  stable var _admins     : Principal.Set    = Principal.Set.fromArray(admins);
  stable var _dependants : Principal.Set    = Principal.Set.init();
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
    assert is_admin(caller);
    Array.map<Principal,Text>(Principal.Set.toArray(_dependants), Principal.toText);
  };
  public shared func acceptCycles() : async () {
    let available = Cycles.available();
    let accepted = Cycles.accept(available);
    assert (accepted == available);
  };
  public shared ({caller}) func reclaim() : async () {
    assert is_admin(caller);
    let _self : Principal = Principal.fromActor(this);
    let IC : T.IC = actor("aaaaa-aa");
    await IC.update_settings({
      canister_id = _self;
      settings = { controllers = Principal.Set.toArray(_admins) };
    });
  };
  // Called by dependants reporting their cycles balance
  public shared ({caller}) func chain_report( cr : T.ChainReport ) : () {
    switch cr {
      case ( #ping ){
        assert Principal.equal(caller, _installer);
        for ( dep in Iter.fromArray(Principal.Set.toArray(_dependants)) ){
          let chsvc : ChildService = actor(Principal.toText(dep));
          chsvc.chain_report(#ping);
        };
        let chsvc : ChildService = actor(Principal.toText(_installer));
        chsvc.chain_report(
          #report({
            balance = Cycles.balance();
            transfer = acceptCycles;
          })
        );
      };
      case ( #report(report) ){
        assert Principal.Set.match(_dependants, caller);
        let min_cycles : Nat = 2000000000000;
        let max_cycles : Nat = 3000000000000;
        if ( report.balance < min_cycles ){
          let topup : Nat =  max_cycles - report.balance;
          if ( Cycles.balance() > (topup + min_cycles) ){
            Cycles.add(topup);
            await report.transfer();
          };
        };
      };
    };
  };
  public shared ({caller}) func send_cycles( p : Text ) : async () {
    assert is_admin(caller);
    type Target = actor { acceptCycles : shared () -> async () };
    let target : Target = actor(p);
    let available : Nat = Cycles.balance();
    let amount : Nat = (available - 50000000000);
    Cycles.add(amount);
    await target.acceptCycles();
  };

  // ======================================================================== //
  // Private Methods                                                          //
  // ======================================================================== //
  //
  func is_admin( p : Principal ) : Bool {
    Principal.Set.match(_admins, p);
  };
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
    let t_actor : BD.BlockDevice = await BD.BlockDevice(Principal.Set.toArray(_admins));
    let t_principal : Principal = Principal.fromActor(t_actor);
    let device : Device = {
      open = t_actor.open;
      close = t_actor.close;
      principal = t_principal;
      available = T.SectorCount.blocks(1);
    };
    _clock := add_task(_clock, t_actor.clock);
    _managed := add_task(_managed, t_actor.request_report);
    _dependants := Principal.Set.insert(_dependants, t_principal);
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