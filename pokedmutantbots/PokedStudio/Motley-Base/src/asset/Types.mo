import Prim "mo:⛔";
import HB "../heartbeat/Types";
import Blob "mo:base/Blob";
import Time "mo:base/Time";
import Order "mo:base/Order";
import Result "mo:base/Result";
import Buffer "mo:base/Buffer";
import Nat "mo:base/Nat";
import Http "Http";
import Debug "mo:base/Debug";
import Nat32 "mo:base/Nat32";
import Nat8 "mo:base/Nat8";
import Array "mo:base/Array";
import Text "mo:base/Text";
import Path "Path";
import Hex "../encoding/Hex";
import Binary "mo:encoding/Binary";
import SHA256 "mo:crypto/SHA/SHA256";

module {

  public type Handle = Text;
  public type MimeType = Text;
  public type Path = Path.Path;
  public type Index = Nat;
  public type Bytes = Nat;
  public type StagedFiles = [(Index, StorageStrategy)];
  public type Mapping = (Index,Principal,Range);
  public type Range   = (Point,Point);
  public type Point   = (Index,Index);
  public type Priv = { #RO; #WO; #RW; #NO };
  public type Mode = (Priv,Priv); // ( Group, World )
  public type Manifest = [(Index, Filedata)];
  public type Filedata = {name : Handle; size : Bytes; ftype : MimeType};
  public type Strategy = [(Text,[Instruction])];
  public type Instruction = (Handle,Index,Nat);
  public type UploadStrategy = (Bytes,BlockCount,BlockCount,Strategy);
  public type Transition = {#Mapped; #Finished};
  public type ChainReport = HB.ChainReport;
  public type Mount = [Inode];

  public type FileshareService = actor {
    export : shared (Path, ?[Principal], ?Mode) -> async Return<Mount>;
  };

  public type IC = actor {
    update_settings : shared ({
      canister_id : Principal;
      settings : {
        controllers : [Principal];
      }
    }) -> async () };

  public type Error = {
    #FatalFault;
    #FailedInit : Text;
    #NotPermitted;
    #NotFound : Path;
    #Corrupted;
    #EmptyPath : Path;
    #AlreadyExists : Path;
    #NotFile : Path;
    #NotDirectory : Path;
    #Unauthorized;
    #IncompatibleInode;
    #Invalid : Path;
    #ServiceLimit;
    #TryAgain;
    #Busy;
  };

  public type Return<T> = Result.Result<T,Error>;

  public type ManagerSvc = actor {
    write_request : shared (WriteRequest,SaveCmd) -> async Return<Index>;
    request_report : shared () -> ();
    clock : shared () -> ();
  };

  public type SaveCmd = shared ([(Index,File)]) -> async ();
  public type RegisterCmd = shared (HB.Task,HB.Task) -> async ();

  public type Inode = {
    #Reserved : Principal;
    #Directory : Directory;
    #File : File;
  };

  public type Directory = {
    inode : Index;
    parent : Index;
    name : Handle;
    owner : Principal;
    group : [Principal];
    mode : Mode;
    contents : [Dentry];
  };

  public type File = {
    name : Handle;
    size : Bytes;
    ftype : MimeType;
    timestamp : Time.Time;
    owner : Principal;
    group : [Principal];
    mode : Mode;
    pointer : {
      callback : Http.StreamingCallback;
      token    : Http.StreamingToken;
    };
  };

  public type Stat = {
    name : Text;
    inode : Index;
    parent : Index;
    validity : DState;
    global : Bool;
    owners : [Principal];
  };

  public type Dentry = (Index,Index,Handle,DState); 

  public type DState = { #Valid; #Hidden };

  public type TempFile = {
    var name : Handle;
    var size : Bytes;
    var ftype : MimeType;
    var owner : Principal;
    var timestamp : Time.Time;
    var owners : [Principal];
  };

  public type OptStrategyMethod = () -> async ?UploadStrategy;
  public type Status = {
    #Finished : (OptStrategyMethod,Principal);
    #Busy;
    #Staged;
    #Ready;
    #Mapped;
    #Delete;
    #Reserved;
    #Null;
  };

  public type UploadRequest = {
    path : Path;
    delegate : Principal;
    owners : [Principal];
    manifest : [Filedata];
    secret : Text;
  };

  public type StorageRequest = { 
    name : Handle;
    parent : ?Handle;
    delegate : Principal;
    owners : [Principal];
    metadata : [Metadata];
  };

  public type WriteRequest = {
    delegate : Principal;
    owners : [Principal];
    manifest : Manifest;
  };

  public type StorageDevice = {
    open      : shared (FormatRequest) -> async Return<FormatResponse>;
    close     : shared (Index) -> async ();
    principal : Principal;
    available : BlockCount;
  };

  public type StorageStrategy = {
    #Direct : BlockCount;
    #Distributed : (SectorCount, BlockCount);
  };

  public type FormatRequest = [(Index,Principal,BlockCount,Text)];
  public type FormatResponse = {
    callback : Http.StreamingCallback;
    tokens   : [(Index,Index,Http.StreamingToken)];
  };

  public type UploadData = {
    index  : Index;
    blocks : [(Index,Index,Blob)];
  };

  public type Metadata = {
    owner : Principal;
    range : Range;
    key   : Text;
    open  : Bool;
  };

  public type BlockCount = Nat;
  public type PageCount = Nat;
  public type SectorCount = Nat;

  public type StorageArray = [var Object];
  public type Object = [var Blob];

  public let BLOCK_SIZE : Bytes = 4000;
  public let PAGE_SIZE : Bytes = 2000000;
  public let SECTOR_SIZE : Bytes = 2000000000;

  private func mul( x : Nat, y : Bytes ) : Bytes { x * y };

  private func div( x : Bytes, y : Bytes ) : Nat {
    var ret : Nat = x / y;
    let rem : Nat = x % y;
    if (rem > 0){ ret += 1 };
    ret;  
  };

  public module Filedata = {
    public func compare( x : (Index, Filedata), y : (Index, Filedata) ) : Order.Order {
      Nat.compare(x.1.size, y.1.size);
    };
  };

  public module BlockCount = {
    public func bytes( x : BlockCount ) : Bytes {
      mul(x, BLOCK_SIZE);
    };
    public func from_bytes( x : Bytes ) : BlockCount {
      div(x, BLOCK_SIZE);
    };
  };

  public module PageCount = {
    public func bytes( x : PageCount ) : Bytes {
      mul(x, PAGE_SIZE);
    };
    public func from_bytes( x : Bytes ) : PageCount {
      div(x, PAGE_SIZE);
    };
    public func blocks( x : PageCount ) : BlockCount {
      BlockCount.from_bytes( bytes(x) );
    };
    public func from_blocks( x : BlockCount ) : PageCount {
      from_bytes( BlockCount.bytes(x) );
    };
  };

  public module SectorCount = {
    public func bytes( x : SectorCount ) : Bytes {
      mul(x, SECTOR_SIZE);
    };
    public func from_bytes( x : Bytes ) : SectorCount {
      div(x, SECTOR_SIZE);
    };
    public func blocks( x : SectorCount ) : BlockCount {
      BlockCount.from_bytes( bytes(x) );
    };
    public func from_blocks( x : BlockCount ) : SectorCount {
      from_bytes( BlockCount.bytes(x) );
    };
    public func pages( x : SectorCount ) : PageCount {
      PageCount.bytes( bytes(x) );
    };
    public func from_pages( x : PageCount ) : SectorCount {
      from_bytes( PageCount.bytes(x) );
    };
  };

  public func asset_key( data : Blob, salt : [Nat8] ) : Blob {
    let bytes = Buffer.fromArray<Nat8>(Blob.toArray(data));
    for ( val in salt.vals() ){ bytes.add(val) };
    let ba : [Nat8] = SHA256.sum(Buffer.toArray(bytes));
    Blob.fromArray([ba[0],ba[1],ba[2],ba[3],ba[28],ba[29],ba[30],ba[31]]);
  };

  public module Index = {

    public func hash( index : Index ) : Nat32 {
      var ba : [Nat8] = Blob.toArray( Text.encodeUtf8( Nat.toText(index) ) );
      ba := SHA256.sum(ba);
      Binary.BigEndian.toNat32([ba[0],ba[1],ba[30],ba[31]]);
    };

    public func equal( x : Index, y : Index ) : Bool { Nat.equal(x,y) };

    public func compare ( x : Index, y : Index ) : Order.Order {
      Nat.compare(x,y);
    };


  };

};