import ICTypes "Types";
import Blob "mo:base/Blob";
import AccountId "../AccountId";
import Option "mo:base/Option";

module IC {

  public module Ledger {

    public let canister_id : Text = "ryjl3-tyaaa-aaaaa-aaaba-cai";

    public let expected_fee : Nat64 = 10000;

    /// Basic Types
    public type Memo = ICTypes.Ledger.Memo;
    public type Tokens = ICTypes.Ledger.Tokens;
    public type TimeStamp = ICTypes.Ledger.TimeStamp;
    public type AccountIdentifier = ICTypes.Ledger.AccountIdentifier;
    public type SubAccount = ICTypes.Ledger.SubAccount;

    /// Transfer & Balance Types
    public type Interface = ICTypes.Ledger.Interface.Interface; // actor type
    public type TransferArgs = ICTypes.Ledger.Interface.TransferArgs;
    public type TransferError = ICTypes.Ledger.Interface.TransferError;
    public type TransferResult = ICTypes.Ledger.Interface.TransferResult;
    public type AccountBalanceArgs = ICTypes.Ledger.Interface.AccountBalanceArgs;

    /// Interface Types
    public type C_Transfer = ICTypes.Ledger.Interface.C_Transfer; 
    public type Q_Account_Balance = ICTypes.Ledger.Interface.Q_Account_Balance;
    public type Q_Query_Blocks = ICTypes.Ledger.Interface.Q_Query_Blocks;
    public type Q_Archives = ICTypes.Ledger.Interface.Q_Archives;
    public type Q_Transfer_Fee = ICTypes.Ledger.Interface.Q_Transfer_Fee;
    public type Q_Symbol = ICTypes.Ledger.Interface.Q_Symbol;
      public type Q_Name = ICTypes.Ledger.Interface.Q_Name;

    /// Transaction Ledger Types
    public type Blocks = ICTypes.Ledger.Chain.Blocks;
    public type Block = ICTypes.Ledger.Chain.Block;
    public type BlockIndex = ICTypes.Ledger.Chain.Index;
    public type Transaction = ICTypes.Ledger.Chain.Transaction;
    public type Transfer = ICTypes.Ledger.Chain.Transfer;

    /// Text representation of a 32-byte IC AccountIdentifier
    public type AccountId = AccountId.AccountId;

    public func transfer ( _amount : Nat64, _to : AccountId, _from_subaccount : ?SubAccount ) : async TransferResult {
      
      assert AccountId.valid( _to );

      switch( AccountId.toBlob( _to ) ){
        case null #Err( #BadFee({ expected_fee = { e8s = 10000 } }) );
        case ( ?address ){
      
          let ledger : Interface = actor( canister_id );
      
          let args : TransferArgs = {
            to = address;
            from_subaccount = _from_subaccount;
            created_at_time = null;
            fee = { e8s = expected_fee };
            amount = { e8s = _amount };
            memo = 0;
          };
      
          await ledger.transfer( args );

        }
      }
    };

    public func account_balance( _account : AccountId ) : async Tokens {
      
      assert AccountId.valid(_account);

      switch( AccountId.toBlob( _account ) ){
        case null { { e8s = 0 : Nat64 } };
        case ( ?address ){

          let ledger : Interface = actor( canister_id );
          await ledger.account_balance({ account = address })
        
        }
      }
    };

  };

};