import R "mo:base/Random";
import Iter "mo:base/Iter";
import Buffer "mo:base/Buffer";

actor {

  public func final_test() : async [Nat] {
    let buffer = Buffer.Buffer<Nat>(20);
    for ( i in Iter.range(1,20) ){
      let b : Blob = await R.blob();
      let f = R.Finite(b);
      switch( f.coin() ){
        case null buffer.add(500);
        case ( ?b ) {
          if b buffer.add(1)
          else buffer.add(0)
        }
      }
    };
    Buffer.toArray(buffer);
  };

};