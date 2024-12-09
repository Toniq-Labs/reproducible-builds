import RBT "mo:stableRBT/StableRBTree";
import Cycles "mo:base/ExperimentalCycles";
import Trie "mo:base/Trie";
import Iter "mo:base/Iter";
import TrieMap "mo:base/TrieMap";
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Buffer "mo:base/Buffer";
import Text "mo:base/Text";
import Blob "mo:base/Blob";
import Path "Path";
import Nat "mo:base/Nat";
import Http "../Http";
import Html "../../html/Html";
import MM "../MediaManager/MediaManager";
import FS "Filesystem";
import PS "PrincipalSet";
import T "../Types";

shared ({caller = _installer}) actor class ICFS() = this {

  type Index = T.Index;
  type Return<T> = T.Return<T>;
  type Path = Path.Path;
  type File = T.File;
  type Stat = T.Stat;
  type Dentry = T.Dentry;
  type Directory = T.Directory;
  type UploadRequest = T.UploadRequest;
  type WriteRequest = T.WriteRequest;
  type Filesystem = FS.Filesystem;
  type Filedata = T.Filedata;
  type Manfifest = T.Manifest;

  stable var _init       : Bool            = false;
  stable var _self       : Principal       = Principal.fromText("aaaaa-aa");
  stable var _manager    : MM.MediaManager = actor "aaaaa-aa";
  stable var _files      : Filesystem      = FS.init();
  stable var _dependants : PS.PrincipalSet = PS.init();
  stable var _next_inode : Index           = 0;

  /*
    Remove this after we change the return type of the storage daemon.
    we really only need it to return the full path of the file
  */
  let delete_me = TrieMap.TrieMap<Index,Path>(T.Index.equal, T.Index.hash);

  public shared ({caller}) func init() : async () {
    assert Principal.equal(caller, _installer) and not _init;
    _self := Principal.fromActor(this);
    Cycles.add(32000000000000);
    _manager := await MM.MediaManager(_installer);
    let mgmt_principal : Principal = Principal.fromActor(_manager);
    _dependants := PS.put(_dependants, mgmt_principal);
    let IC : T.IC = actor("aaaaa-aa");
    await IC.update_settings({
      canister_id = mgmt_principal;
      settings = { controllers = [mgmt_principal] };
    });
    _init := true;
  };

  public shared query ({caller}) func dependants() : async [Text] {
    assert Principal.equal(caller, _installer) and _init;
    let buffer = Buffer.Buffer<Text>(0);
    for ( dep in PS.toArray(_dependants).vals() ){
      buffer.add(Principal.toText(dep));
    };
    Buffer.toArray(buffer);
  };

  public shared ({caller}) func makedir( path : Path, owners : [Principal] ) : async Return<()> {
    assert Principal.equal(caller, _installer) and _init;
    switch( is_owner(caller, Path.dirname(path)) ){
      case( #err(val) ){ return #err(val) };
      case( #ok(bool) ){ assert bool };
    };
    makedir_internal(path,owners);
  };

  public shared ({caller}) func upload( request : UploadRequest ) : async Return<(Text, Index)> {
    assert Principal.equal(caller, _installer) and _init;
    switch( stat(request.path) ){
      case( #err(val) ){ #err(val) };
      case( #ok(parent) ){
        if ( parent.inode > 0 ){ assert PS.match(PS.fromArray(parent.owners), caller) };
        let secret : Text = request.secret;
        let num_entries : Nat = request.manifest.size();
        let file_buffer = Buffer.Buffer<(Index,Filedata)>(num_entries);
        let dentry_buffer = Buffer.Buffer<Dentry>(num_entries);
        for ( filedata in request.manifest.vals() ){
          let dentry : Dentry = FS.dentry(filedata.name, parent.inode, next_inode);
          delete_me.put(dentry.inode, Path.join(request.path, filedata.name));
          file_buffer.add(dentry.inode,filedata);
          dentry_buffer.add(dentry);
        };
        switch( multi_touch(parent.inode, dentry_buffer) ){
          case( #err(val) ){ #err(val) };
          case( #ok() ){
            let w_request = {
              delegate = request.delegate;
              owners = request.owners;
              manifest = Buffer.toArray(file_buffer);
            };
            switch( await _manager.write_request(w_request, save, secret) ){
              case( #err(val) ){ #err(val) };
              case( #ok(rindex) ){
                #ok((Principal.toText(Principal.fromActor(_manager)), rindex));
              };
            };
          };
        };
      };
    };
  };

  public shared ({caller}) func save( files : [(Index,File)] ) : async () {
    Debug.print("Attempting to save files");
    assert PS.match(_dependants, caller) and _init;
    Debug.print("Save request permitted");
    for ( file in files.vals() ){
      switch( delete_me.get(file.0) ){
        case( ?full_path ){ 
          Debug.print("full path found: " # full_path);
          switch( FS.save(_files, full_path, #File(file.1)) ){
            case( #ok(newfs) ){ _files := newfs };
            case( #err(val) ){};
          };
        };
        case( null ){};
      };
    };
  };

  public shared func acceptCycles() : async () {
    let available = Cycles.available();
    let accepted = Cycles.accept(available);
    assert (accepted == available);
  };

  public shared query ({caller}) func export_path( path : Path ) : async Return<Filesystem> {
    assert Principal.equal(caller, _installer);
    FS.export_path(_files, path, caller);
  };

  public shared query func http_request( request : Http.Request ) : async Http.Response {
    var embed : Bool = false;
    var elems : [Text] = Iter.toArray(Text.split(request.url, #text("/?")));
    let path : Text = elems[0];
    if ( elems.size() > 1 ){ embed := true };
    if ( Path.is_valid(path) == false ){ return Http.BAD_REQUEST() };
    switch( FS.traverse(_files, path) ){
      case( #err(val) ){ Debug.print("not found"); Http.NOT_FOUND() };
      case( #ok(dentry) ){
        Debug.print("Dentry found");
        Debug.print("Inode: " # Nat.toText(dentry.inode));
        if( not dentry.global ){ return Http.UNAUTHORIZED() };
        switch( dentry.validity ){
          case( #Blacklisted ){ Http.LEGAL() };
          case( #Valid ){
            switch( FS.get_inode(_files, dentry.inode) ){
              case( null ){ Debug.print("Bad Request"); Http.BAD_REQUEST() };
              case( ?inode ){
                Debug.print("Inode found");
                switch( inode ){
                  case( #Directory(val) ){ http_process_directory(val, path) };
                  case( #File(file) ){
                    Debug.print("Found File");
                    if embed { return Http.generic(file.ftype, Blob.fromArray([]), ?#Callback(file.pointer)) };
                    if ( Text.contains(file.ftype, #text("video")) ){ return http_process_video(file, path) };
                    Http.generic( file.ftype, Blob.fromArray([]), ?#Callback(file.pointer) );
                    };
                  };
                };
              };
            };
          case(_){ Http.NOT_FOUND() };
          };
        };
      };
    };

  system func heartbeat() : async () {
    if _init { _manager.clock() };
  };

  func http_process_directory( dir : Directory, cwd : Path ) : Http.Response {
    var html : Text = Html.html_w_header(cwd);
    let dotdot : Text = Path.to_url(Path.dirname(cwd), _self);
    let href_buffer = Buffer.Buffer<Text>(dir.contents.size());
    href_buffer.add( Html.href(dotdot, "[BACK]..") );
    for ( ref in dir.contents.vals() ){
      let url : Text = Path.to_url(Path.join(cwd, ref.name), _self);
      let href : Text = Html.href(url, ref.name);
      href_buffer.add(href);
    };
    let body : Text = Text.join("", href_buffer.vals());
    html := Html.add_body_elements(html, body);
    let payload : Blob = Text.encodeUtf8(html);
    Http.generic("text/html", payload, null);
  };

  func http_process_video( file : File, cwd : Path ) : Http.Response {
    var html : Text = Html.html_w_header(cwd);
    let body_buffer : Buffer.Buffer<Text> = Buffer.Buffer(0);
    let back_element : Text = Html.href(Path.to_url(Path.dirname(cwd), _self), "[BACK]..");
    let video_url : Text = Path.to_url(cwd #"/?embed", _self);
    let video_element : Text = Html.video_element(video_url, file.ftype, null, null);
    body_buffer.add(back_element);
    body_buffer.add(video_element);
    html := Html.add_body_elements(html, Text.join("", body_buffer.vals()));
    Http.generic("text/html", Text.encodeUtf8(html), null);
  };

  func is_owner( subj : Principal, path : Path ) : Return<Bool> {
    if ( Path.is_root(path) ){ return #ok(true) };
    switch( stat(path) ){
      case( #err(val) ){ #err(val) };
      case( #ok(obj) ){
        for( owner in obj.owners.vals() ){
          if ( Principal.equal(owner,subj) ){ return #ok(true) };
        };
        return #ok(false);
      };
    };
  };

  func stat( path: Path ) : Return<Stat> {
    switch( FS.traverse(_files, path) ){
      case( #err(val) ){ #err(val) };
      case( #ok(dentry) ){
        switch( FS.get_inode(_files, dentry.inode) ){
          case( null ){ #err(#NotFound(path)) };
          case( ?inode ){
            switch(inode){
              case( #Directory(dir) ){
                #ok({
                  name = dentry.name;
                  inode = dentry.inode;
                  parent = dentry.parent;
                  validity = dentry.validity;
                  global = dentry.global;
                  owners = dir.owners;
                });
              };
              case( #File(file) ){
                #ok({
                  name = dentry.name;
                  inode = dentry.inode;
                  parent = dentry.parent;
                  validity = dentry.validity;
                  global = dentry.global;
                  owners = file.owners;
                });
              };
            };
          };
        };
      };
    };
  };

  func makedir_internal( path : Path, owners : [Principal] ) : Return<()> {
    switch( FS.makedir(_files, next_inode, path, owners) ){
      case( #err(val) ){ #err(val) };
      case( #ok(newfs) ){
        _files := newfs;
        #ok();
      };
    };
  };

  func touch( path : Path ) : Return<Index> {
    switch( FS.touch(_files, next_inode, path) ){
      case( #err(val) ){ #err(val) };
      case( #ok(newfs, index) ){
        _files := newfs;
        #ok(index);
      };
    };
  };

  func multi_touch( parent : Index, entries : Buffer.Buffer<Dentry> ) : Return<()> {
    switch( FS.get_inode(_files, parent) ){
      case( null ){ #err(#NotFound("Inode: " # Nat.toText(parent))) };
      case( ?inode ){
        switch( inode ){
          case( #Directory(dir) ){
            let c_buffer = Buffer.fromArray<Dentry>(dir.contents);
            c_buffer.append(entries);
            _files := FS.put_inode(
              _files,
              parent,
              #Directory({
                name = dir.name;
                parent = dir.parent;
                owners = dir.owners;
                contents = Buffer.toArray(c_buffer);
              }),
            );
            #ok();
          };
          case(_){ #err(#IsFile("Inode : " # Nat.toText(parent))) };
        };
      };
    };
  };

  func next_inode() : Index {
    _next_inode += 1;
    _next_inode;
  };

};