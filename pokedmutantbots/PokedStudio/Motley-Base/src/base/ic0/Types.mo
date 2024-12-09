import Hash "mo:base/Hash";

module Types {


  public module Ledger {


      public type Memo = Nat64;
      public type Tokens = { e8s : Nat64 };
      public type TimeStamp = { TimeStamp_nanos: Nat64 };
      public type AccountIdentifier = Blob;
      public type SubAccount = Blob;
      // public type SubAccount = [Nat8];


      public module Chain {
    
        public type Blocks = [Block];
        public type Index = Nat64;

        public type Block = {
          parent_hash : Hash.Hash;
          transaction : Transaction;
          TimeStamp : TimeStamp;
        };

        public type Transaction = {
          memo : Memo;
          transfer : Transfer;
          created_at_time : TimeStamp;
        };

        public type Transfer = {
          #Mint: {
            to : AccountIdentifier;
            amount : Tokens;
          };
          #Burn: {
            from: AccountIdentifier;
            amount: Tokens;
          };
          #Send : {
            from: AccountIdentifier;
            to: AccountIdentifier;
            amount: Tokens;
          };
        };
      };


      public module Archive {

        public type QueryArchiveFn = shared query (GetBlocksArgs) -> async QueryBlocksResponse;

        public type Archives = { archives: [Archive] };

        public type Archive = { canister_id : Principal };

        public type QueryBlocksResponse = {
          chain_length : Nat64;
          certificate : ?Blob;
          blocks : Chain.Blocks;
          first_block_index : Chain.Index;
          archived_blocks : [{
            start : Chain.Index;
            length : Nat64;
            callback : QueryArchiveFn;
          }];
        };

        public type GetBlocksArgs = {
          start : Chain.Index;
          length : Nat64;
        };

        public type BlockRange = {
          blocks : Chain.Blocks;
        };

      };

      public module Interface {

        public type Interface = actor {
          name : Q_Name;
          symbol : Q_Symbol;
          archives : Q_Archives;
          transfer : C_Transfer;
          query_blocks : Q_Query_Blocks;
          transfer_fee : Q_Transfer_Fee;
          account_balance : Q_Account_Balance;
        };

        public type C_Transfer = shared (TransferArgs) -> async TransferResult;
        public type Q_Account_Balance = shared query (AccountBalanceArgs) -> async Tokens;
        public type Q_Query_Blocks = shared query () -> async Archive.QueryBlocksResponse;
        public type Q_Archives = shared query () -> async Archive.Archives;
        public type Q_Transfer_Fee = shared query () -> async Nat64;
        public type Q_Symbol = shared query () -> async Text;
        public type Q_Name = shared query () -> async Text;

        public type AccountBalanceArgs = {
          account : AccountIdentifier;
        };

        public type TransferArgs = {
          memo : Memo;
          amount : Tokens;
          to: AccountIdentifier;
          fee : Tokens; // Must be 10000 e8s
          from_subaccount : ?SubAccount;
          created_at_time : ?TimeStamp;
        };

        public type TransferError = {
          #BadFee : { expected_fee : Tokens; };
          #InsufficientFunds : { balance: Tokens; };
          #TxTooOld : { allowed_window_nanos: Nat64 };
          #TxDuplicate : { duplicate_of: Chain.Index; };
          #TxCreatedInFuture;
        };

        public type TransferResult = {
          #Ok : Chain.Index;
          #Err : TransferError;
        };

      };

  }

};