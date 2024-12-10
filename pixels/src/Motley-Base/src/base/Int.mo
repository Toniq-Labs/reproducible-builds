import Prim "mo:⛔";
import Int "mo:base/Int";
import Nat8 "mo:base/Nat8";
import Nat16 "mo:base/Nat16";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Option "mo:base/Option";
import Struct "../encoding/Struct";
import Binary "../encoding/Binary";


module {

  public type Int = Prim.Types.Int;
  public let abs = Int.abs;
  public let toText = Int.toText;
  public let min = Int.min;
  public let max = Int.max;
  public let hash = Int.hash;
  public let hashAcc = Int.hashAcc;
  public let equal = Int.equal;
  public let notEqual = Int.notEqual;
  public let less = Int.less;
  public let lessOrEqual = Int.lessOrEqual;
  public let greater = Int.greater;
  public let greaterOrEqual = Int.greaterOrEqual;
  public let compare = Int.compare;

  public func neg(x : Int) : Int { -x };
  public func add(x : Int, y : Int) : Int { x + y };
  public func sub(x : Int, y : Int) : Int { x - y };
  public func mul(x : Int, y : Int) : Int { x * y };
  public func div(x : Int, y : Int) : Int { x / y };
  public func rem(x : Int, y : Int) : Int { x % y };
  public func pow(x : Int, y : Int) : Int { x ** y };

  public let struct_tag : Nat32 = 0x0A000001;

  public let struct_err : Text = "0x0A000001 - Int";

  public func validStruct( s : Struct.Struct ) : Bool {
    if ( Struct.Tag.notEqual(s, struct_tag) ) false
    else Struct.Instruction.raw(s) < 2
  };

  public func toStruct( i : Int ) : Struct.Struct {
    var b : [Nat8] = [];
    var instr : Nat64 = 0;
    if ( i >= 0 ) instr := 1;
    let n : Nat = abs(i);
    if ( n <= 255 ) b := [Nat8.fromNat( n )]
    else if ( n <= 65535 ) b := Binary.BigEndian.fromNat16( Nat16.fromNat( n) ) 
    else if ( n <= 4294967295 ) b := Binary.BigEndian.fromNat32( Nat32.fromNat( n ) )
    else b := Binary.BigEndian.fromNat64( Nat64.fromNat( n ) );
    Struct.build(struct_tag, ?instr, #array( b ) );
  };

  public func fromStruct( s : Struct.Struct ) : Text {
    if ( Struct.Tag.notEqual(s, struct_tag) ) Struct.trap(struct_err);
    let text : ?Text = Text.decodeUtf8( Struct.Value.raw(s) );
    if ( Option.isNull( text ) ) Struct.trap(struct_err);
    Option.get<Text>(text, "");
  }; 

}