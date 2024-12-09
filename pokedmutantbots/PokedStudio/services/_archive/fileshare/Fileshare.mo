import T "Types";
import MM "MediaManager";
import Error "mo:base/Error";
import Buffer "mo:base/Buffer";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Debug "mo:base/Debug";
import Filesystem "Filesystem";
import Path "../../../../Motley-Base/src/asset/Path";
import HB "../../../../Motley-Base/src/heartbeat/Types";
import Text "../../../../Motley-Base/src/base/Text";
import Random "../../../../Motley-Base/src/base/Random";
import Index "../../../../Motley-Base/src/base/Index";
import SBuffer "../../../../Motley-Base/src/base/StableBuffer";
import Principal "../../../../Motley-Base/src/base/Principal";
import Cycles "../../../../Motley-Base/src/base/Cycles";

shared ({caller = _installer}) actor class Fileshare() = this {

  // Type Declarations
  type Filedata = T.Filedata;
  type Manifest = T.Manifest;
  type WriteRequest = T.WriteRequest;
  type UploadRequest = T.UploadRequest;
  type ChainReport = T.ChainReport;
  type ChildService = T.ChildService;
  type Index = Index.Index;
  type HeartbeatService = HB.HeartbeatService;
  type CyclesReport = HB.CyclesReport;
  type Filesystem = T.Filesystem;
  type Entropy = Random.Entropy;
  type Return<T> = T.Return<T>;
  type Path = Path.Path;
  type Mode = T.Mode;
  type Dentry = T.Dentry; 
  type DState = T.DState;
  type Mount = T.Mount;
  type Inode = T.Inode;
  type Directory = T.Directory;
  type File = T.File;
  type DACL = T.DACL;

  // Module Shortcuts
  let Entropy = Random.Entropy;

  // Persistent Data
  stable var _active     : Nat             = 0;
  stable var _init       : Bool            = false;
  stable var _self       : Principal       = Principal.placeholder();
  stable var _hbsvc      : Principal       = Principal.placeholder();
  stable let _entropy    : Entropy         = Entropy.init(250);
  stable var _admins     : Principal.Set   = Principal.Set.init();
  stable var _manager    : MM.MediaManager = actor "aaaaa-aa";
  stable var _dependants : Principal.Set   = Principal.Set.init();
  stable var _filesystem : Filesystem      = Filesystem.empty();

  /*============================================================================||
  || Public Interface                                                           ||
  ||============================================================================*/
  //
  // Call-once method used to initialize the filesystem and set admins
  public shared ({caller}) func init( hbsvc : Principal, admins : [Principal] ) : async Return<()> {
    assert Principal.equal(caller, _installer) and not _init;
    await _schedule( hbsvc ); // For Moc-7.4.0: make await*
    await _new_manager( admins ); // For Moc-7.4.0: make await*
    _set_admins( admins );
    _initfs();
    #ok();
  };

  // Returns an Inode representing a directory or file
  public shared query ({caller}) func walk( p : Path ) : async Return<Inode> {
    _walk(p, caller);
  };

  // Returns a list of all child canisters being managed by this service 
  public shared query ({caller}) func dependants() : async [Text] {
    assert _is_admin(caller);
    Array.map<Principal,Text>(Principal.Set.toArray(_dependants), Principal.toText);
  };

  // If caller permitted, export a shared filesystem path (a.k.a "mount")
  public shared query ({caller}) func export( p : Path, m : ?Mode, g : ?[Principal] ) : async Return<Mount> {
    assert _is_admin(caller);
    _export(p, caller, m, g);
  };

  // Determine if a directory exists; if it doesn't, and the caller is authorized, create it.
  public shared ({caller}) func makedir( p : Path, g : ?[Principal], m : ?Mode ) : async Return<()> {
    assert _is_admin(caller);
    _makedir(p, caller, g, m);
  };

  // This method is called by a media manager after it has successfully processed a write request
  public shared ({caller}) func save( files : [(Index,File)] ) : async () {
    assert _is_dependant(caller);
    for ( file in files.vals() ) ignore _save(file.0, file.1);
    _close_request();
  };

  // This method is used to create a new folder at the root directory
  public shared ({caller}) func make_rootdir( p : Path, g : ?[Principal], m : ?Mode ) : async Return<()> {
    assert _is_admin(caller);
    _makeroot(p, caller, g, m);
  };

  // Primary service interface; used by a FE application to initiate an upload request
  public shared ({caller}) func upload( request : UploadRequest ) : async Return<(Text,Index)> {
    assert _is_admin( caller) and Path.is_valid(request.path);
    if ( not _is_permitted(request.path, caller, #write) ) return #err( #Unauthorized );

    let mbuffer = Buffer.Buffer<(Index,Filedata)>(request.manifest.size());

    for ( fdata in request.manifest.vals() ){
      let p : Path = Path.join(request.path, fdata.name);
      if ( Text.contains(fdata.name, #text("/")) ){
        switch( _makedirs(Path.dirname(p), caller, null, null) ){
          case ( #ok() ){};
          case ( #err(val) ) assert false;
        };
      };
      switch( _touch(p, caller) ){
        case ( #ok(index) ) mbuffer.add((index,fdata));
        case ( #err(val) ) assert false;
      };
    };

    let wr : WriteRequest = {
      delegate = request.delegate;
      owners = request.group;
      manifest = Buffer.toArray(mbuffer);
    };

    // await _issue_write_request(wr, _new_secret());// For Moc-7.4.0: make await*
    switch( await _manager.write_request(wr, save, _new_secret()) ){
      case ( #err(val) ) #err val;
      case ( #ok(rindex) ) {
        _open_request();
        let mgr : Text = Principal.toText( Principal.fromActor(_manager) );
        #ok((mgr, rindex));
      };
    };
    
  };

  /*============================================================================||
  || Callback Methods                                                           ||
  ||============================================================================*/
  //
  // Used to receive and accept cycles
  public shared func acceptCycles() : async () {
    let available = Cycles.available();
    let accepted = Cycles.accept(available);
    assert (accepted == available);
  };

  // Used to report balance to cycles management service
  public shared ({caller}) func report_balance() : () {
    assert _is_heartbeat_service( caller );
    for ( dep in Iter.fromArray(Principal.Set.toArray(_dependants)) ){
      let chsvc : ChildService = actor(Principal.toText(dep));
      chsvc.chain_report(#ping);
    };
    let hbsvc : HeartbeatService = actor(Principal.toText(_hbsvc));
    hbsvc.report_balance({
      balance = Cycles.balance();
      transfer = acceptCycles;
    });
  };

  // Called by dependants reporting their cycles balance
  public shared ({caller}) func chain_report( cr : ChainReport ) : () {
    switch cr {
      case ( #ping ){};
      case ( #report(report) ){
        assert _is_dependant( caller );
        let min_cycles : Nat = 1000000000000;
        let max_cycles : Nat = 2000000000000;
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

  // If there's an open request (not saved) clock the media manager
  public shared ({caller}) func pulse() : () {
    assert _is_heartbeat_service( caller );
    _manager.clock();
    await _fill_entropy(); // For Moc-7.4.0: make await*
  };

  /*============================================================================||
  || Private functions over state and modes of operation                        ||
  ||============================================================================*/
  //
  func _open_request() : () { _active += 1 };
  func _close_request() : () { _active -= 1 };
  func _active_request() : Bool { _active > 0 };
  func _mkroot( t : Text, eid : Principal, g : ?[Principal], m : ?Mode ) : Return<()> {
    Filesystem.make_root_folder(_filesystem, t, eid, g, m);
  };
  func _chown( p : Path, eid : Principal, o : Principal ) : Return<()> {
    Filesystem.chown(_filesystem, p, eid, o);
  };
  func _touch( p : Path, eid : Principal ) : Return<Index> {
    Filesystem.touch(_filesystem, p, eid);
  };
  func _setgroup( p : Path, eid : Principal, g : [Principal] ) : Return<()> {
    Filesystem.setgroup(_filesystem, p, eid, g);
  };
  func _makeroot( p : Path, eid : Principal, g : ?[Principal], m : ?Mode ) : Return<()> {
    Filesystem.make_root_folder(_filesystem, p, eid, g, m);
  };
  func _makedir( p : Path, eid : Principal, g : ?[Principal], m : ?Mode ) : Return<()> {
    Filesystem.mkdir(_filesystem, p, eid, g, m);
  };
  func _makedirs( p : Path, eid : Principal, g : ?[Principal], m : ?Mode ) : Return<()> {
    Filesystem.make_directories(_filesystem, p, eid, g, m);
  };
  func _export( p : Path, eid : Principal, m : ?Mode, g : ?[Principal] ) : Return<Mount> {
    Filesystem.export(_filesystem, p, eid, m, g);
  };
  func _is_admin( p : Principal ) : Bool {
    Principal.Set.match(_admins, p) and _init;
  };
  func _is_manager( p : Principal ) : Bool {
    Principal.equal(Principal.fromActor(_manager), p) and _init;
  };
  func _is_dependant( p : Principal ) : Bool {
    Principal.Set.match(_dependants, p) and _init;
  };
  func _walk( p : Path, eid : Principal ) : Return<Inode> {
    Filesystem.walk(_filesystem, p, eid);
  };
  func _is_heartbeat_service( p : Principal ) : Bool {
    Principal.equal(_hbsvc, p) and _init;
  };
  func _add_dependant( p : Principal ) : () {
    _dependants := Principal.Set.insert(_dependants, p);
  };
  func _set_admins( arr : [Principal] ) : () {
    _admins := Principal.Set.fromArray( arr );
  };
  func _fill_entropy() : async () {  // For Moc-7.4.0: make async*
    await Entropy.fill(_entropy);
  };
  func _new_secret() : Text { 
    switch( Entropy.rng(_entropy).spin(9999) ){
      case ( ?sec ) Nat.toText(sec);
      case null _new_secret();
    };
  };
  func _initfs() : () {
    _self := Principal.fromActor(this);
    Filesystem.init(_filesystem, _self, ?Principal.Set.toArray(_admins), null);
    _init := true;
  };
  func _save( index : Index, file : File ) : Return<()> {
    Filesystem.sudo_save(_filesystem, index, file);
  };
  func _is_permitted( p : Path, eid : Principal, op : {#read; #write} ) : Bool {
    switch( _walk(p, eid) ){
      case ( #err(_) ) false;
      case ( #ok(inode) ){
        switch inode {
          case ( #Directory(dir) ) Filesystem.is_permitted(dir, eid, op);
          case ( #File(file) ) Filesystem.is_permitted(file, eid, op);
          case _ false;
        };
      };
    };
  };
  // func _issue_write_request( wr : WriteRequest, sec : Text ) : async Return<(Text,Index)> { // For Moc-7.4.0: make async*
  //   switch( await _manager.write_request(wr, save, sec) ){
  //     case ( #err(val) ) #err val;
  //     case ( #ok(rindex) ) {
  //       _open_request();
  //       #ok((Principal.toText(Principal.fromActor(_manager)), rindex));
  //     };
  //   };
  // };
  func _schedule( p : Principal ) : async () { // For Moc-7.4.0: make async*
    _hbsvc := p;
    let hbsvc : HB.HeartbeatService = actor(Principal.toText(_hbsvc));
    await hbsvc.schedule([
      {interval = HB.Intervals._05beats; tasks = [pulse]},
      {interval = HB.Intervals._15beats; tasks = [report_balance]},
    ]);
  };
  func _new_manager( arr : [Principal] ) : async () { // For Moc-7.4.0: make async*

    assert ( Cycles.balance() > ( 36000000000000) );
    assert ( _active == 0 );

    Cycles.add(35000000000000);
    _manager := await MM.MediaManager(arr);

    let IC : T.IC = actor("aaaaa-aa");
    let mgmt_principal : Principal = Principal.fromActor(_manager);

    _add_dependant(mgmt_principal);
    await IC.update_settings({
      canister_id = mgmt_principal;
      settings = { controllers = [mgmt_principal] };
    });

  };

};