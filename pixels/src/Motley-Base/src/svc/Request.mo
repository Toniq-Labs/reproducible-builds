import Blob "../base/Blob";

module {

  type Request = { #change; #data; #event; #identity; #unknown };

  let service_tag : [Nat8] = [10, 0, 2, 0]; // \x0A000200

  public class ServiceRequest( b : Blob ) = {

    let size  : Nat = b.size(); 
    let bytes : [var Nat8] = Blob.toArrayMut( b );

    assert match(service_tag, (0, 3));
    assert size == Binary.BigEndian.toNat([bytes[4], bytes[5], bytes[6], bytes[7]]);

    public func source() : Blob {
      var cnt : Nat = 0;
      var idx : Nat = 12;
      let src = Array.init<Nat8>(291, 0);
      label l loop {
        if ( idx > 303 ) break l;
        src[cnt] := bytes[idx];
        cnt += 1;
        idx += 1;
      };
      Blob.fromArrayMut( src );
    };

    public func destination() : Blob {
      var cnt : Nat = 0;
      var idx : Nat = 308;
      let src : [var Nat8] = Array.init(291, 0);
      label l loop {
        if ( idx > 599 ) break l;
        src[cnt] := bytes[idx];
        cnt += 1;
        idx += 1;
      };
      Blob.fromArrayMut( src );
    };

    public func check_type() : Request {
      if match(change_request, (600, 603)) #change
      else if match(data_request, (600, 603)) #data
      else if match(identity_request, (600, 603)) #identity
      else if match(event_request, (600, 603)) #event
      else #unknown
    };

    func match( arr : [Nat8], span : (Nat,Nat) ) : Bool {
      let count : Nat = 0;
      let index : Nat = span.0;
      var test : Bool = true;
      label l loop {
        if ( not test ) break l;
        if ( index > span.1 ) break l;
        test := bytes[index] == arr[count];
        index += 1;
        count += 1;
      };
      test
    }; 

  }

  // Request            : 004 Bytes : 0
  //// Length           : 004 Bytes : 4
  //// Source           : 004 Bytes : 8
  ////// Label          : 004 Bytes : 12
  //////// Handle       : 004 Bytes : 16
  ////////// Length     : 001 Bytes : 20
  ////////// Data       : 063 Bytes : 21
  //////// Domain       : 004 Bytes : 84
  ////////// Tier0      : 004 Bytes : 88
  //////////// Handle   : 004 Bytes : 92
  ////////////// Length : 001 Bytes : 96
  ////////////// Data   : 063 Bytes : 97
  ////////// Tier1      : 004 Bytes : 160
  //////////// Handle   : 004 Bytes : 164
  ////////////// Length : 001 Bytes : 168
  ////////////// Data   : 063 Bytes : 169
  ////////// Tier0      : 004 Bytes : 232
  //////////// Handle   : 004 Bytes : 236
  ////////////// Length : 001 Bytes : 240
  ////////////// Data   : 063 Bytes : 241
  //// Destination      : 004 Bytes : 304
  ////// Label          : 004 Bytes : 308
  //////// Handle       : 004 Bytes : 312
  ////////// Length     : 001 Bytes : 316
  ////////// Data       : 063 Bytes : 317
  //////// Domain       : 004 Bytes : 380
  ////////// Tier0      : 004 Bytes : 384
  //////////// Handle   : 004 Bytes : 388
  ////////////// Length : 001 Bytes : 392
  ////////////// Data   : 063 Bytes : 393
  ////////// Tier1      : 004 Bytes : 456
  //////////// Handle   : 004 Bytes : 460
  ////////////// Length : 001 Bytes : 464
  ////////////// Data   : 063 Bytes : 465
  ////////// Tier0      : 004 Bytes : 528
  //////////// Handle   : 004 Bytes : 532
  ////////////// Length : 001 Bytes : 536
  ////////////// Data   : 063 Bytes : 537
  //// SubRequest       : 004 Bytes : 600
  ////// Length         : 004 Bytes : 604

  ////// [payload]      : XXX Bytes : 

}