import RBT "mo:stableRBT/StableRBTree";
import Result "mo:base/Result";
import Principal "mo:base/Principal";
import Option "mo:base/Option";
import Buffer "mo:base/Buffer";
import Array "mo:base/Array";
import Text "mo:base/Text";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Path "Path";
import T "../Types";
import PS "PrincipalSet";
import Debug "mo:base/Debug";

import SBuffer "../base/StableBuffer";
import Index "../base/Index";

module {

  public type Filesystem = SBuffer.StableBuffer<Inode>;
  public type Index = T.Index;
  public type Dentry = T.Dentry;
  public type File = T.File;
  public type Directory = T.Directory;
  public type Path = Path.Path;
  public type Elements = Path.Elements;
  public type Inode = T.Inode;
  public type Filesystem = RBT.Tree<Index,Inode>;
  public type Return<T> = T.Return<T>;

  public func init() : Filesystem {
    var fs : Filesystem = RBT.init<Index,Inode>();
    insert(fs,
      0, // Root directory is always index 0
      #Directory( {
        name = Path.Root : Path;
        parent = 0 : Index;
        owners = [] : [Principal];
        contents = [] : [Dentry];
    }));
  };

  public func dentry( name : Text, parent : Index, next : () -> Nat ) : Dentry {
    return {
      name = name;
      inode = next();
      parent = parent;
      validity = #Empty;
      global = true;
    };
  };

  public func get_inode( fs : Filesystem, index : Index ) : ?Inode {
    find(fs, index);
  };

  public func put_inode( fs : Filesystem, index : Index, inode : Inode ) : Filesystem {
    insert(fs, index, inode);
  };

  public func path_exists( fs : Filesystem, path : Path ) : Bool {
    switch( traverse(fs, path) ){
      case( #ok(val) ){ true };
      case( #err(val) ){ false };
    };
  };

  public func root_entries( fs : Filesystem ) : Return<[Dentry]> {
    switch( find(fs, 0) ){
      case( ?inode ){
        switch( inode ){
          case( #Directory(dir) ){ #ok(dir.contents) };
          case(_){ #err(#Corrupted) }}};
      case( null ){ #err(#Corrupted) };
    };
  };

  public func export_path( fs : Filesystem, path : Path, requestor : Principal ) : Return<Filesystem> {
    if ( Path.is_valid(path) == false ){ return #err(#Invalid(path)) };
    if ( Path.is_root(path) ){ return #err(#Invalid(path)) };

    var newfs : Filesystem = RBT.init<Index,Inode>();
    switch( traverse(fs, path) ){
      case( #err(val) ){ return #err(val) };
      case( #ok(dentry) ){

        newfs := insert(newfs,
          0, // Root directory is always index 0
          #Directory( {
            name = Path.Root;
            parent = 0;
            owners = [];
            contents = [{
              name = dentry.name;
              inode = dentry.inode;
              parent = 0;
              validity = dentry.validity;
              global = dentry.global;
            }];
            }
          )
        );

        func drilldown( dentry : Dentry ) : () {
          switch( find(fs, dentry.inode) ){
            case( null ){};
            case( ?inode ){
              switch( inode ){
                case( #File(file) ){
                  var permitted : Bool = false;
                  for ( owner in file.owners.vals() ){
                    if ( Principal.equal(owner, requestor) ){ permitted := true } };
                  if permitted {
                    newfs := insert(newfs, dentry.inode, inode) };
                };
                case( #Directory(dir) ){
                  var permitted : Bool = false;
                  for ( owner in dir.owners.vals() ){
                    if ( Principal.equal(owner, requestor) ){ permitted := true } };
                  if permitted { 
                    newfs := insert(newfs, dentry.inode, inode);
                    for ( entry in dir.contents.vals() ){ drilldown(entry) };
                  };
                };
              };
            };
          };
        };

        drilldown(dentry); 

      };
    };
  
    #ok(newfs);

  };

  public func traverse( fs : Filesystem, path : Path ) : Return<Dentry> {
    if ( Path.is_valid(path) == false ){ return #err(#Invalid(path)) };
    if ( Path.is_root(path) ){ return #ok({name="/";inode=0;parent=0;validity=#Valid;global=true}) };
    var current : ?Inode = find(fs, 0);
    var depth : Nat = 0;
    let target : Nat = Path.depth(path);
    Debug.print("traversing: " # path);
    while( depth <= target ){
      switch( current ){
        case( null ){ Debug.print("Depth: " # Nat.toText(depth)); return #err(#NotFound(path)) };
        case( ?inode ){
          switch( inode ){
            case( #Directory(dir) ){
              let element : Text = Option.get( Path.index(path, depth), Path.Root);
              switch( search_content(dir.contents, element) ){
                case( null ){ Debug.print("NotFound: " # element); return #err(#NotFound(element)) };
                case( ?dentry ){
                  if ( depth == target ){ return #ok(dentry) }
                  else { current := find(fs, dentry.inode) };
                };
              };
            };
            case(_){
              return #err(#NotFound(path));
        }}}};
      depth += 1;
    };
    Debug.print("Depth Exceeded");
    #err(#NotFound(path));
  };

  public func touch( fs : Filesystem, next : () -> Index, path : Path ) : Return<(Filesystem, Index)> {
    if ( path_exists(fs, path) ){ return #err(#AlreadyExists(path)) };
    if ( not path_exists(fs, Path.dirname(path)) ){ return #err(#NotFound(Path.dirname(path))) };
    if ( Path.is_root(path) ){ return #err(#EmptyPath(path)) };
    let index : Index = next();
    switch( add_empty_dentry(fs, path, index) ){
      case( #err(val) ){ #err(val) };
      case( #ok(newfs) ){ #ok((newfs,index)) };
    };
  };

  public func makedir( fs : Filesystem, next : () -> Index, path : Path, owners : [Principal] ) : Return<Filesystem> {
    var p_dentry : Dentry = {name="/";inode=0;parent=0;validity=#Valid;global=true};
    var parent : ?Inode = null;
    if ( path_exists(fs, path) ){ return #err(#AlreadyExists(path)) };
    if ( Path.is_root(Path.dirname(path)) ){ Debug.print("Path is root"); parent := get_inode(fs,0) }
    else {
      switch( traverse(fs, Path.dirname(path)) ){
        case( #err(val) ){ return #err(val) };
        case( #ok(dentry) ){ 
          p_dentry := dentry;
          parent := get_inode(fs, p_dentry.inode) };
      };
    };
    switch( parent ){
      case( null ){ #err(#Corrupted) };
      case( ?inode ){
        switch( inode ){
          case ( #Directory(dir) ){
            let c_buffer = Buffer.fromArray<Dentry>(dir.contents);
            let new_index : Index = next();
            c_buffer.add({
              name = Path.basename(path);
              parent = p_dentry.inode;
              inode = new_index;
              validity = #Valid;
              global = true;
            });
            let p_dir : Directory = {
              name = dir.name;
              parent = dir.parent;
              owners = dir.owners;
              contents = Buffer.toArray(c_buffer);
            };
            let newdir : Directory = {
              name = Path.basename(path);
              parent = p_dentry.inode;
              owners = owners;
              contents = [];
            };
            let newfs : Filesystem = insert(fs, new_index, #Directory(newdir));
            #ok( insert(newfs, newdir.parent, #Directory(p_dir)) );
          };
          case(_){ #err(#IsFile(Path.dirname(path))) };
        };
      };
    };
  };

  public func save( fs : Filesystem, path : Path, inode : Inode ) : Return<Filesystem> {
    switch( traverse(fs, path) ){
      case( #err(val) ){ #err(val) };
      case( #ok(dentry) ){
        if ( not Text.equal(dentry.name, Path.basename(path)) ){ return #err(#NotFound(path)) };
        switch( dentry.validity ){
          case( #Empty ){
            switch( get_inode(fs,dentry.parent) ){
              case( null ){ #err(#NotFound(Path.dirname(path))) };
              case( ?parent){
                switch( parent ){
                  case( #Directory(dir) ){
                    let c_buffer = Buffer.fromArray<Dentry>(dir.contents);
                    c_buffer.filterEntries(func(_,x) = not Text.equal(x.name, dentry.name));
                    c_buffer.add({
                      name = dentry.name;
                      parent = dentry.parent;
                      inode = dentry.inode;
                      validity = #Valid;
                      global = dentry.global;
                    });
                    let updated : Directory = {
                      name = dir.name;
                      parent = dir.parent;
                      owners = dir.owners;
                      contents = Buffer.toArray(c_buffer);
                    };
                    var newfs : Filesystem = insert(fs, dentry.inode, inode);
                    #ok( insert(newfs, dentry.parent, #Directory(updated)) );
                  };
                  case(_){ #err(#IsFile(Path.dirname(path))) };
                };
              };
            };
          };
          case(_){ #err(#AlreadyExists(path))};
        };
      };
    };
  };

  func add_empty_dentry(fs : Filesystem, path : Path, index : Index ) : Return<Filesystem> {
    switch( traverse(fs, Path.dirname(path)) ){
      case( #err(val) ){ return #err(val) };
      case( #ok(dentry) ){
        let p_index = dentry.inode;
        switch( find(fs, p_index) ){
          case( null ){ return #err( #NotFound(Path.dirname(path)) )}; 
          // Should we trap instead? If we've gotten here an inode entry should always exist.
          case( ?ino ){
            switch( ino ){
              case( #Directory(dir) ){
                let c_buffer = Buffer.fromArray<Dentry>(dir.contents);
                c_buffer.add({
                  name = Path.basename(path);
                  parent = p_index;
                  inode = index;
                  validity = #Empty;
                  global = true;
                } : Dentry );
                let updated : Directory = {
                  name = dir.name;
                  parent = dir.parent;
                  owners = dir.owners;
                  contents = Buffer.toArray(c_buffer);
                };
                #ok( insert(fs, p_index, #Directory(updated)) );
              };
              case(_){ #err(#IsFile(Path.dirname(path))) };
            };
          };
        };
      };
    };
  };

  func search_content( content : [Dentry], key : Text ) : ?Dentry {
    for ( entry in content.vals() ){
      if ( Text.equal(entry.name, key) ){
        return ?entry;
      };
    };
    return null;
  };

  func scan( map : Filesystem, lower : Index, upper : Index ) : [(Index,Inode)] {
    RBT.scanLimit<Index,Inode>(map, T.Index.compare, lower, upper, #fwd, 25).results;
  };
  func keys( map : Filesystem ) : Iter.Iter<Index> {
    Iter.map(entries(map), func (kv : (Index, Inode)) : Index { kv.0 });
  };
  func vals( map : Filesystem ) : Iter.Iter<Inode> {
    Iter.map(entries(map), func (kv : (Index, Inode)) : Inode { kv.1 });
  };
  func entries( map : Filesystem ) : Iter.Iter<(Index, Inode)> {
    RBT.entries<Index,Inode>(map);
  };
  func insert( map : Filesystem, key : Index, val : Inode ) : Filesystem {
    RBT.put<Index,Inode>( map, T.Index.compare, key, val);
  };
  func delete( map : Filesystem, key : Index ) : Filesystem {
    RBT.delete<Index, Inode>( map, T.Index.compare, key );
  };
  func find( map : Filesystem, key : Index) : ?Inode {
    RBT.get<Index,Inode>( map, T.Index.compare, key);
  };

};