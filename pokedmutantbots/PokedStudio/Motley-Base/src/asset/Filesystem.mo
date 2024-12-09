import Prim "mo:⛔";
import Array "mo:base/Array";
import Option "mo:base/Option";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import Path "Path";
import Text "../base/Text";
import Index "../base/Index";
import SBuffer "../base/StableBuffer";
import Principal "../base/Principal";
import Stack "mo:base/Stack";
import T "../../../../PokedStudio/services/src/fileshare/Types";

module {

  public type Inode = T.Inode;
  public type Depth = Nat;
  public type Priv = T.Priv;
  public type Index = Index.Index;
  public type Dentry = T.Dentry;
  public type Filesystem = T.Filesystem;
  public type File = T.File;
  public type Directory = T.Directory;
  public type Mode = T.Mode;
  public type Path = Path.Path;
  public type Return<T> = T.Return<T>;
  public type Mount = T.Mount;
  public type Handle = T.Handle;
  public type DACL = T.DACL;
  public type Operation = {#read; #write};

  public func empty() : Filesystem {
    return {
      var root = Principal.placeholder();
      var count = 0;
      var inodes = [var];
    };
  };

  public func mount( fs : Filesystem, m : Mount ) : () {
    fs.inodes := Array.thaw<Inode>(m);
  };

  public func init( fs : Filesystem, su : Principal, g : ?[Principal], m : ?Mode ) : () {
    fs.root := su;
    fs.count := 1;
    fs.inodes := Prim.Array_init<Inode>(5000, #Directory({
      name = Path.Root;
      inode = 0;
      parent = 0;
      owner = su;
      group = Option.get<[Principal]>(g, []);
      mode = Option.get<Mode>(m, (#RW,#NO));
      contents = [];
    }));
  };

  func is_root( fs : Filesystem, p : Principal ) : Bool { Principal.equal(fs.root, p) };

  public func touch( fs : Filesystem, p : Path, eid : Principal ) : Return<Index> {
    open(fs, p, eid, true, true);
  };

  public func find( fs : Filesystem, p : Path, eid : Principal ) : Return<Index> {
    open(fs, p, eid, false, false);
  };

  public func sudo_find( fs : Filesystem, p : Path ) : Return<Index> {
    open(fs, p, fs.root, false, true);
  };

  public func exists( fs : Filesystem, p : Path ) : Bool {
    switch( open(fs, p, fs.root, false, true) ){
      case ( #ok(_) ) true;
      case ( #err(_) ) false;
    };
  };

  public func walk( fs : Filesystem, p : Path, eid : Principal ) : Return<Inode> {
    var dacl : DACL = {owner = Principal.placeholder(); group = []; mode = (#NO,#NO)};
    switch( open(fs, p, eid, false, false) ){
      case ( #err(val) ) #err val;
      case ( #ok(index) ) {
        switch( fs.inodes[index] ){
          case( #Reserved(oid) ) return #err(#NotFound p);
          case( #Directory(dir) ) dacl := dir;
          case( #File(file) ) dacl := file;
          case _ return #err( #IncompatibleInode );
        };
        if ( is_permitted(dacl, eid, #read) or Principal.equal(fs.root, eid) ) #ok(fs.inodes[index])
        else #err( #Unauthorized );
      };
    };
  };

  public func root_folder( fs : Filesystem ) : [Dentry] {
    switch (fs.inodes[0] ){
      case ( #Directory(dir) ) dir.contents;
      case _ [];
    };
  };

  public func is_file( fs : Filesystem, p : Path, hidden : Bool ) : Bool {
    switch( open(fs, p, fs.root, false, hidden) ){
      case ( #err(val) ) false;
      case ( #ok(index) ){
        switch ( fs.inodes[index] ) {
          case ( #File(_) ) true;
          case _ false;
        };
      };
    };
  };

  public func is_directory( fs : Filesystem, p : Path, hidden : Bool ) : Bool {
    switch( open(fs, p, fs.root, false, hidden) ){
      case ( #err(val) ) false;
      case ( #ok(index) ) {
        switch ( fs.inodes[index] ) {
          case ( #Directory(_) ) true;
          case _ false;
        };
      };
    };
  };

  public func save( fs : Filesystem, index : Index, eid : Principal, file : File ) : Return<()> {
    switch( fs.inodes[index] ){
      case ( #Directory(dir) ) #err(#NotFile(dir.name));
      case ( #Reserved(oid) ){
        if ( not Principal.equal(oid, eid) ) return #err(#Unauthorized);
        fs.inodes[index] := #File(file); 
        #ok();
      };
      case ( #File(file) ){
        if ( not is_permitted(file, eid, #write) ) return #err(#Unauthorized);
        fs.inodes[index] := #File(file);
        #ok();
      };
      case _ #err( #IncompatibleInode );
    };
  };

  public func sudo_save( fs : Filesystem, index : Index, file : File ) : Return<()> {
    switch( fs.inodes[index] ){
      case ( #Directory(dir) ) { #err(#NotFile(dir.name)) };
      case ( #Reserved(oid) ){
        fs.inodes[index] := #File(file); 
        #ok();
      };
      case ( #File(file) ){
        fs.inodes[index] := #File(file);
        #ok();
      };
      case _ { #err( #IncompatibleInode ) };
    };
  };

  public func export( fs : Filesystem, p : Path, eid : Principal, m : ?Mode, g : ?[Principal] ) : Return<Mount> {
    let mount = SBuffer.init<Inode>();
    func drilldown( de : Dentry, parent : Index ) : ?Index {
      switch( de.3 ){
        case( #Valid ){
          switch( fs.inodes[de.0] ){
            case ( #Reserved(_) ) null;
            case ( #File(file) ){
              if ( not is_permitted(file, eid, #read) ) return null;
              let index : Nat = SBuffer.size<Inode>(mount);
              SBuffer.add<Inode>(mount, #File({
                name = file.name;
                size = file.size;
                ftype = file.ftype;
                timestamp = file.timestamp;
                owner = eid;
                group = Option.get<[Principal]>(g, file.group);
                mode = Option.get<Mode>(m, file.mode);
                pointer = file.pointer;
              }));
              ?index;
            };
            case ( #Directory(dir) ){
              if ( not is_permitted(dir, eid, #read) ) return null;
              let dindex : Nat = SBuffer.size<Inode>(mount);
              let cbuffer = Buffer.Buffer<Dentry>(0);
              SBuffer.add<Inode>(mount, #Reserved(eid));
              for ( dentry in dir.contents.vals() ){
                switch( drilldown(dentry, dindex) ){
                  case ( ?index ) cbuffer.add((index,dindex,dentry.2,#Valid));
                  case null {};
                };
              };
              SBuffer.put<Inode>(mount, dindex, #Directory({
                inode = dindex;
                parent = parent;
                name = dir.name;
                owner = eid;
                group = Option.get<[Principal]>(g, dir.group);
                mode = Option.get<Mode>(m, dir.mode);
                contents = Buffer.toArray(cbuffer);
              }));
              ?dindex;
            };
            case _ null;
          };
        };
        case _ null;
      };
    };
    switch( open(fs, p, eid, false, false) ){
      case ( #err(val) ) #err val;
      case ( #ok(index) ){
        switch( fs.inodes[index] ){
          case ( #Reserved(_) ) #err(#NotFound p);
          case ( #File(_) ) #err(#NotDirectory p);
          case ( #Directory(dir) ){
            if ( is_permitted(dir, eid, #read) == false ) return #err(#Unauthorized);
            let dindex : Index = SBuffer.size<Inode>(mount);
            SBuffer.add<Inode>(mount, #Reserved(eid));
            let cbuffer = Buffer.Buffer<Dentry>(0);
            for ( dentry in dir.contents.vals() ){
              switch( drilldown(dentry, 0) ){
                case ( ?idx ) cbuffer.add((idx,0,dentry.2,#Valid));
                case null {};
              };
            };
            SBuffer.put<Inode>(mount, dindex, #Directory({
              inode = 0;
              parent = 0;
              name = Path.Root;
              owner = eid;
              group = Option.get<[Principal]>(g, dir.group);
              mode = Option.get<Mode>(m, dir.mode);
              contents = Buffer.toArray(cbuffer);
            }));
            #ok( SBuffer.toArray<Inode>(mount) );
          };
        };
      };
    }; 
  };

  public func chown( fs : Filesystem, p : Path, eid : Principal, _actor : Principal ) : Return<()> {
    switch( open(fs, p, eid, false, false) ){
      case ( #err(val) ) #err val;
      case ( #ok(index) ) {
        switch( fs.inodes[index] ){
          case ( #Directory(dir) ){
            if ( not is_permitted(dir, eid, #write) ) return #err(#Unauthorized);
            fs.inodes[index] := #Directory{
              inode = dir.inode;
              parent = dir.parent;
              name = dir.name;
              owner = _actor;
              group = dir.group;
              mode = dir.mode;
              contents = dir.contents;
            };
            #ok();
          };
          case ( #File(file) ){
            if ( not is_permitted(file, eid, #write) ) return #err(#Unauthorized);
            fs.inodes[index] := #File{
              name = file.name;
              size = file.size;
              ftype = file.ftype;
              timestamp = file.timestamp;
              owner = _actor;
              group = file.group;
              mode = file.mode;
              pointer = file.pointer;
            };
            #ok();
          };
          case ( #Reserved(_) ) #err(#NotFound p);
          case _ #err( #IncompatibleInode );
        };
      };
    };
  };

  public func setgroup( fs : Filesystem, p : Path, eid : Principal, _actors : [Principal] ) : Return<()> {
    switch( open(fs, p, eid, false, false) ){
      case ( #err(val) ) #err val;
      case ( #ok(index) ) {
        switch( fs.inodes[index] ){
          case ( #Directory(dir) ){
            if ( not is_permitted(dir, eid, #write) ) return #err(#Unauthorized);
            fs.inodes[index] := #Directory{
              inode = dir.inode;
              parent = dir.parent;
              name = dir.name;
              owner = dir.owner;
              group = _actors;
              mode = dir.mode;
              contents = dir.contents;
            };
            #ok();
          };
          case ( #File(file) ){
            if ( not is_permitted(file, eid, #write) ) return #err(#Unauthorized);
            fs.inodes[index] := #File{
              name = file.name;
              size = file.size;
              ftype = file.ftype;
              timestamp = file.timestamp;
              owner = file.owner;
              group = _actors;
              mode = file.mode;
              pointer = file.pointer;
            };
            #ok();
          };
          case ( #Reserved(_) ) #err(#NotFound p);
          case _ #err( #IncompatibleInode )
        };
      };
    };
  };

  public func make_directories( fs : Filesystem, p : Path, eid : Principal, g : ?[Principal], m : ?Mode) : Return<()> {
    if ( exists(fs, p) ) return #ok();
    var dpath : Path = p;
    Debug.print(dpath);
    let stack = Stack.Stack<Path>();
    while ( Path.is_root(dpath) == false ) {
      stack.push(dpath);
      dpath := Path.dirname(p);
    };
    while ( Option.isSome( stack.peek() ) ){
      Debug.print("stack not empty");
      switch( stack.pop() ){
        case null return #err( #FatalFault );
        case ( ?tpath ){
          Debug.print(tpath);
          switch( mkdir(fs, tpath, eid, g, m) ){
            case ( #err(val) ) return #err val;
            case ( #ok ) {};
          };
        };
      };
    };
    #ok();
  };

  public func mkdir( fs : Filesystem, p: Path, eid : Principal, g : ?[Principal], m : ?Mode ) : Return<()> {
    switch( touch(fs, p, eid) ){
      case ( #err(val) ) #err val;
      case ( #ok(index) ){
        switch( fs.inodes[index] ){
          case ( #Reserved(oid) ){
            if ( Principal.equal(oid, eid) == false ) return #err(#Unauthorized);
            switch( find(fs, Path.dirname(p), eid) ){
              case ( #err(val) ) #err( #FatalFault ); // Shouldn't happen
              case ( #ok(pindex) ){
                switch( fs.inodes[pindex] ){
                  case ( #Directory(dir) ){
                    fs.inodes[index] := #Directory({
                      parent = pindex;
                      inode = index;
                      name = Path.basename(p);
                      owner = eid;
                      group = Option.get<[Principal]>(g, dir.group);
                      mode = Option.get<Mode>(m, dir.mode); 
                      contents = [];
                    });
                    #ok();
                  };
                  case _ #err( #FatalFault );
                };
              };
            };
          };
          case _ #ok();
        };
      };
    };
  };

  public func make_root_folder(fs : Filesystem, h : Handle, eid : Principal, g : ?[Principal], m : ?Mode ) : Return<()> {
    let path = Path.join(Path.Root, h);
    switch( touch(fs, path, fs.root) ){
      case ( #err(val) ) #err val;
      case ( #ok(index) ){
        switch( fs.inodes[index] ){
          case ( #Reserved(oid) ){
            if ( Principal.equal(oid, fs.root) == false ) return #err(#Unauthorized);
            fs.inodes[index] := #Directory({
              parent = 0;
              inode = index;
              name = h;
              owner = eid;
              group = Option.get<[Principal]>(g, []);
              mode = Option.get<Mode>(m, (#RW,#RO)); 
              contents = [];
            });
            #ok();
          };
          case _ #ok();
        };
      };
    };
  };

  public func toArray(fs : Filesystem) : [Inode] {
    Prim.Array_tabulate<Inode>(fs.count, func x = fs.inodes[x] );
  };

  public func toVarArray(fs : Filesystem) : [var Inode] {
    if ( fs.count == 0) { [var] } else {
      var i = 0;
      let a = Prim.Array_init<Inode>(fs.count, #Reserved(fs.root));
      label l loop {
        if (i >= fs.count) break l;
        a[i] := fs.inodes[i];
        i += 1;
      };
      a
    }
  };

  func open( fs : Filesystem, p : Path, eid : Principal, _c : Bool, _h : Bool ) : Return<Index> {
    if ( not Path.is_valid(p) ) return #err(#Invalid p);
    var inode = fs.inodes[0];
    if ( Path.is_root(p) ) return #ok(0);
    let target : Depth = Path.depth(p);
    var current : Depth = 0;
    while( current <= target ){
      switch inode {
        case ( #Directory(dir) ){
          if ( is_permitted(dir, eid, #read) or Principal.equal(fs.root, eid) ) {
            let elem = Option.get<Text>( Path.index(p, current), Path.Root );
            switch ( Array.find<Dentry>(dir.contents, func(x) : Bool {Text.equal(x.2, elem)} ) ) {
              case ( ?dentry ) {
                switch( dentry.3 ){
                  case ( #Valid ) {
                    if ( current == target ) {
                      if ( _c == false ) return #ok(dentry.0);
                      if ( is_permitted(dir,eid, #write)or Principal.equal(fs.root, eid) ) return #ok(dentry.0);
                      return #err(#Unauthorized);
                    };
                    inode := fs.inodes[dentry.0];
                    current += 1;
                  };
                  case ( #Hidden ) {
                    if ( _h and not _c ){
                      if ( (current == target) ) return #ok(dentry.0);
                      inode := fs.inodes[dentry.0];
                      current += 1;
                    } else return #err(#NotFound p);
                  };
                  case _ return #err(#NotFound p);
                };
              };
              case null {
                if ( (current == target) and _c ) {
                  if ( not is_permitted(dir, eid, #write) ) return #err(#Unauthorized);
                  let updated = Buffer.fromArray<Dentry>(dir.contents);
                  let new_inode : Index = reserve_inode(fs, eid);
                  updated.add( (new_inode, dir.inode, elem, #Valid) : Dentry );
                  fs.inodes[dir.inode] := #Directory({
                    inode = dir.inode;
                    parent = dir.parent;
                    name = dir.name;
                    owner = dir.owner;
                    group = dir.group;
                    mode = dir.mode;
                    contents = Buffer.toArray(updated);
                  });
                  return #ok(new_inode);
                } else {
                  return #err(#NotFound p);
                };
              };
            };
          } else return #err(#Unauthorized);
        };
        case _ return #err(#NotFound p);
      }};
    #err(#NotFound p);
  };

  public func is_permitted(acl : DACL, eid : Principal, op : Operation) : Bool {
    // if ( is_root( eid ) ) return true;
    if ( Principal.equal(eid, acl.owner) ) return true;
    var perms : Priv = #NO;
    switch ( Array.find<Principal>(acl.group, func x = Principal.equal(x, eid)) ){
      case ( ?match) perms := acl.mode.0;
      case null perms := acl.mode.1;
    };
    switch op {
      case ( #read ) {
        switch( perms ){
          case ( #NO ) false;
          case ( #WO ) false;
          case _ true;
        };
      };
      case ( #write ){
        switch( perms ){
          case ( #NO ) false;
          case ( #RO ) false;
          case _ true;
        };
      };
    };
  };

  func reserve_inode(fs : Filesystem, eid: Principal): Index {
    if ( fs.count == fs.inodes.size()) {
      let size = 2 * fs.inodes.size();
      let elems2 = Array.init<Inode>(size, #Reserved(eid));
      var i = 0;
      label l loop {
        if (i >= fs.count) break l;
        elems2[i] := fs.inodes[i];
        i += 1;
      };
      fs.inodes := elems2;
    };
    fs.inodes[fs.count] := #Reserved(eid);
    let index : Index = fs.count;
    fs.count += 1;
    index;
  };

}