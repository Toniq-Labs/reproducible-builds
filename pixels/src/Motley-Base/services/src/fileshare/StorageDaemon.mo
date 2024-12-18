import Heap "mo:base/Heap";
import Nat "mo:base/Nat";
import Bool "mo:base/Bool";
import Iter "mo:base/Iter";
import Time "mo:base/Time";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import TrieSet "mo:base/TrieSet";
import Index "../../../Motley-Base/src/base/Index";
import DD "Driver";
import T "Types";

module {

  type Index = Index.Index;
  type Set<T> = TrieSet.Set<T>;
  type StagedFiles = [(Index,T.StorageStrategy)];

  public class ServiceDaemon (

    index        : Index,
    request      : T.WriteRequest,
    save_files   : T.SaveCmd,
    change_state : (Index, T.Status) -> (),
    reserve      : (T.BlockCount) -> async T.StorageDevice,
    release      : (T.StorageDevice) -> (),
    secret       : Blob,

  ) = {
    
    public var state : T.Status        = #Staged;
    let _secret      : Blob            = secret;
    let _manifest    : T.Manifest      = request.manifest;
    var _delegate    : Principal       = request.delegate;
    var _owners      : [Principal]     = request.owners;
    var _processed   : Set<Index>    = TrieSet.empty<Index>();
    var _mapped      : Set<Index>    = TrieSet.empty<Index>();
    var _indices     : [Index]       = [];

    func evaluate( count : T.BlockCount ) : T.StorageStrategy {
      if ( T.BlockCount.bytes(count) <= T.SECTOR_SIZE ){
        #Direct(count);
      } else {
        let total : T.Bytes = T.BlockCount.bytes(count);
        var required : T.Bytes = total / T.SECTOR_SIZE;
        let rem : T.Bytes = total % T.SECTOR_SIZE;
        let blocks_in_last_sector = T.BlockCount.from_bytes(rem);
        if ( rem > 0 ){ required += 1 };
        #Distributed((required,blocks_in_last_sector));
      };
    };

    func stage() : T.StagedFiles {
      let heap = Heap.fromIter<(Index,T.Filedata)>( _manifest.vals(), T.Filedata.compare );
      let index_buffer = Buffer.Buffer<Index>(_manifest.size());
      let file_buffer = Buffer.Buffer<(Index,T.StorageStrategy)>(_manifest.size());
      var looping : Bool = true;
      while looping {
        switch ( heap.removeMin() ){
          case( null ){ looping := false };
          case( ?(inode,md) ){
            index_buffer.add(inode);
            let file : T.TempFile = {
              var name = md.name;
              var size = T.BlockCount.from_bytes(md.size);
              var ftype = md.ftype;
              var timestamp = Time.now();
              var owner = _delegate;
              var owners = _owners;
              var pointer = #Null;
            };
            _driver.register_file(inode,file);
            let strategy : T.StorageStrategy = evaluate(file.size);
            file_buffer.add((inode, strategy));
        }}};
      _indices := Buffer.toArray(index_buffer);
      Buffer.toArray(file_buffer);
    };

    func state_change( s : T.Status) : () {
      state := s;
      change_state(index,s);
    };

    func state_transition( t : T.Transition ) : () {
      switch(t){
        case( #Mapped ){
          switch( state ){
            case( #Ready ){ state_change(#Mapped) };
            case(_){};
          };
        };
        case( #Finished ){
          switch( state ){
            case( #Mapped ){ state_change(#Finished(strategy, _delegate)) };
            case(_){};
          };
        };
      };
    };

    let _driver : DD.DeviceDriver = DD.DeviceDriver(_delegate, _secret);

    public func strategy() : async ?T.UploadStrategy {
      state_change(#Busy);
      try { 
        await save_files(_driver.export_files());
      } catch (e) {
        Debug.print("Failed to save files");
        state_change(#Finished(strategy, _delegate));
        return null;
      };
      let strat : T.Strategy = _driver.get_strategy();
      state_change(#Delete);
      ?(T.BLOCK_SIZE, T.PageCount.blocks(1), T.SectorCount.blocks(1), strat);
    };

    _driver.init(state_transition);
    var _staged  : T.StagedFiles   = stage();
    state := #Ready;

    public func map() : async () {
      if ( not mapped() ){
        if ( all_files_mapped() ){ Debug.print("Finished Mapping"); state_transition(#Mapped) }
        else { await map_devices() };
      };
    };

    public func format() : async () {
      if ( not finished() ){
        if ( _driver.all_formatted() ){ Debug.print("Finished Formatting"); state_transition(#Finished) }
        else { await _driver.format() };
      };
    };

    func map_devices() : async () {
      let min_blocks : T.BlockCount = T.BlockCount.from_bytes((_staged.size() * T.BLOCK_SIZE));
      // var device : T.StorageDevice = await reserve(min_blocks);
      for ( entry in _staged.vals() ){
        if ( not being_processed(entry.0) ){
          add_processed_file(entry.0);
          switch( entry.1 ){
            case( #Direct(blocks) ){
              // if ( device.available >= blocks ) {
              //   device := _driver.map_file(device, entry.0, blocks);
              //   release(device)
              //   device := await reserve(min_blocks);
              // } else {
              //   if ( device.available >= T.PageCount.blocks(1) ){
              //     release(device);
              //     device := await reserve(blocks);
              //     device := _driver.map_file(device, entry.0, blocks);
              //   } else {
              //     device := await reserve(blocks);
              //     device := _driver.map_file(device, entry.0, blocks);
              //   };
              // };
              // add_mapped_file(entry.0);
              var device : T.StorageDevice = await reserve(blocks);
              device := _driver.map_file(device, entry.0, blocks);
              add_mapped_file(entry.0);
              release(device)
            };
            case( #Distributed(sectors,blocks) ){
              // if ( device.available >= T.PAGE_SIZE ){ release(device) };
              let buffer = Buffer.Buffer<T.StorageDevice>(sectors);
              for ( inc in Iter.range(1,sectors) ){
                var device = await reserve( T.BlockCount.from_bytes(T.PAGE_SIZE) );
                buffer.add(device);
                if ( inc == sectors ){
                  let used_device : T.StorageDevice = {
                    open = device.open;
                    close = device.close;
                    principal = device.principal;
                    available = device.available - blocks;
                  };
                  release(used_device);
                };
              };
              _driver.map_distributed_file(entry.0, Buffer.toArray(buffer), blocks);
              add_mapped_file(entry.0);
            };
          };
        };
      };
      // release(device);
    };

    func add_processed_file( index : Index ) : () {
      _processed := TrieSet.put<Index>(
        _processed, index, Index.hash(index), Index.equal);
    };

    func being_processed( index : Index ) : Bool {
      TrieSet.mem<Index>(_processed, index, Index.hash(index), Index.equal);
    };

    func add_mapped_file( index : Index ) : () {
      _mapped := TrieSet.put<Index>(
        _mapped, index, Index.hash(index), Index.equal);
    };

    func mapped() : Bool {
      switch( state ){
        case( #Mapped ){ true };
        case(_){ false };
      };
    };

    func finished() : Bool {
      switch( state ){
        case( #Finished(val) ){ true };
        case(_){ false };
      };
    };

    func all_files_mapped() : Bool {
      let all_files : Set<Index> = TrieSet.fromArray<Index>(_indices, Index.hash, Index.equal);
      for ( index in _indices.vals() ){
        if ( Bool.lognot( TrieSet.mem<Index>( _mapped, index, Index.hash(index), Index.equal ) ) ){
            return false;
        };
      };
      return true;
    };
    
  };

};