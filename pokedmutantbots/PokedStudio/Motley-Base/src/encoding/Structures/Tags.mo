module Tags = {

  // OCTET 0: Context Tag
  public let GLOBAL : Nat32 = 0x00000000;

  // OCTET 1: Class Tag
  public module Prim    = { public func tag() : Nat32 { GLOBAL | 0x00000000 } };
  public module Var     = { public func tag() : Nat32 { GLOBAL | 0x00010000 } };
  public module Con     = { public func tag() : Nat32 { GLOBAL | 0x00020000 } };
  public module Array   = { public func tag() : Nat32 { GLOBAL | 0x00030000 } };
  public module Tuple   = { public func tag() : Nat32 { GLOBAL | 0x00040000 } };
  public module Func    = { public func tag() : Nat32 { GLOBAL | 0x00050000 } };
  public module Option  = { public func tag() : Nat32 { GLOBAL | 0x00060000 } };
  public module Async   = { public func tag() : Nat32 { GLOBAL | 0x00070000 } };
  public module Obj     = { public func tag() : Nat32 { GLOBAL | 0x00080000 } };
  public module Variant = { public func tag() : Nat32 { GLOBAL | 0x00090000 } };
  public module Mutable = { public func tag() : Nat32 { GLOBAL | 0x000A0000 } };
  public module Any     = { public func tag() : Nat32 { GLOBAL | 0x000B0000 } };
  public module None    = { public func tag() : Nat32 { GLOBAL | 0x000C0000 } };
  public module Pre     = { public func tag() : Nat32 { GLOBAL | 0x000D0000 } };
  public module Type    = { public func tag() : Nat32 { GLOBAL | 0x000E0000 } };
  public module Strct   = { public func tag() : Nat32 { GLOBAL | 0x000F0000 } };
  public module Candid  = { public func tag() : Nat32 { GLOBAL | 0x00100000 } };

  // OCTET 2: Category Tag
  public module LocalFn  = { public func tag() : Nat32 { Func.tag() | 0x00000000 } };
  public module QueryFn  = { public func tag() : Nat32 { Func.tag() | 0x00000100 } };
  public module UpdateFn = { public func tag() : Nat32 { Func.tag() | 0x00000200 } };

  public module Object = { public func tag() : Nat32 { Obj.tag() | 0x00000000 } };
  public module Module = { public func tag() : Nat32 { Obj.tag() | 0x00000100 } };
  public module Actor  = { public func tag() : Nat32 { Obj.tag() | 0x00000200 } };
  public module Memory = { public func tag() : Nat32 { Obj.tag() | 0x00000300 } };

  public module Struct   = { public func tag() : Nat32 { Obj.tag() | 0x00000000 } };
  public module SArray   = { public func tag() : Nat32 { Obj.tag() | 0x00000100 } };
  public module SRecord  = { public func tag() : Nat32 { Obj.tag() | 0x00000200 } };
  public module Pipeline = { public func tag() : Nat32 { Obj.tag() | 0x00000300 } };

  // OCTET 3: Type Tag
  public module Null      = { public func tag() : Nat32 { Prim.tag() | 0x00000000 } };
  public module Bool      = { public func tag() : Nat32 { Prim.tag() | 0x00000001 } };
  public module Nat       = { public func tag() : Nat32 { Prim.tag() | 0x00000002 } };
  public module Nat8      = { public func tag() : Nat32 { Prim.tag() | 0x00000003 } };
  public module Nat16     = { public func tag() : Nat32 { Prim.tag() | 0x00000004 } };
  public module Nat32     = { public func tag() : Nat32 { Prim.tag() | 0x00000005 } };
  public module Nat64     = { public func tag() : Nat32 { Prim.tag() | 0x00000006 } };
  public module Int       = { public func tag() : Nat32 { Prim.tag() | 0x00000007 } };
  public module Int8      = { public func tag() : Nat32 { Prim.tag() | 0x00000008 } };
  public module Int16     = { public func tag() : Nat32 { Prim.tag() | 0x00000009 } };
  public module Int32     = { public func tag() : Nat32 { Prim.tag() | 0x0000000A } };
  public module Int64     = { public func tag() : Nat32 { Prim.tag() | 0x0000000B } };
  public module Float     = { public func tag() : Nat32 { Prim.tag() | 0x0000000C } }; // Not Supported - Yet
  public module Char      = { public func tag() : Nat32 { Prim.tag() | 0x0000000D } };
  public module Text      = { public func tag() : Nat32 { Prim.tag() | 0x0000000E } };
  public module Blob      = { public func tag() : Nat32 { Prim.tag() | 0x0000000F } };
  public module Error     = { public func tag() : Nat32 { Prim.tag() | 0x00000010 } }; // Not Supported
  public module Principal = { public func tag() : Nat32 { Prim.tag() | 0x00000011 } };

};