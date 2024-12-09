let upstream = https://github.com/dfinity/vessel-package-set/releases/download/mo-0.6.21-20220215/package-set.dhall
let Package =
    { name : Text, version : Text, repo : Text, dependencies : List Text }

let
  additions =
  [{ name = "cap"
  , repo = "https://github.com/stephenandrews/cap-motoko-library"
  , version = "v1.0.4-alt"
  , dependencies = [] : List Text
  },
  { name = "base"
  , repo = "https://github.com/dfinity/motoko-base"
  , version = "moc-0.7.4"
  , dependencies = [] : List Text
  },
  { name = "stableRBT"
  , repo = "https://github.com/canscale/StableRBTree"
  , version = "v0.6.0"
  , dependencies = [] : List Text
  },
  { name = "stableBuffer"
  , repo = "https://github.com/canscale/StableBuffer"
  , version = "v0.2.0"
  , dependencies = [] : List Text
  },
  { name = "canistergeek"
  , repo = "https://github.com/usergeek/canistergeek-ic-motoko"
  , version = "v0.0.3"
  , dependencies = ["base"] : List Text
  },
  { name = "crypto"
  , repo = "https://github.com/aviate-labs/crypto.mo"
  , version = "v0.2.0"
  , dependencies = [ "base", "encoding" ] : List Text
  },
  { name = "encoding"
  , repo = "https://github.com/aviate-labs/encoding.mo"
  , version = "v0.3.1"
  , dependencies = [ "array", "base" ] : List Text
  },
  { name = "array"
  , repo = "https://github.com/aviate-labs/array.mo"
  , version = "v0.1.1"
  , dependencies = [ "base" ] : List Text
  },] : List Package

in  upstream # additions