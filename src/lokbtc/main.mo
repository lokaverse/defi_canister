/////////////////////
///
/// Sample token with lotto burn
///
/// This token uses the base sample token but adds functions to that are called once a transfer occures.
/// In this instance we look for a burn. If we find a burn we flip a coin and if it comes up heads we give the user back double the tokens they burned.
///
/// The only changes to the base code are the regitstraion of a tokens_transfered_listenier in the ICRC1 class. Supporting infrastructure can be found at the end of the actor file.
///
/////////////////////

import Buffer "mo:base/Buffer";
import D "mo:base/Debug";
import ExperimentalCycles "mo:base/ExperimentalCycles";
import Int "mo:base/Int";
import Principal "mo:base/Principal";
import Nat64 "mo:base/Nat64";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Timer "mo:base/Timer";
import Random "mo:base/Random";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";

import CertTree "mo:cert/CertTree";

import ICRC1 "mo:icrc1-mo/ICRC1";
import ICRC2 "mo:icrc2-mo/ICRC2";
import ICRC3 "mo:icrc3-mo/";
import ICRC4 "mo:icrc4-mo/ICRC4";
import CKBTC "canister:ckbtc_prod"; //PROD;

shared ({ caller = _owner }) actor class Token(
  args : ?{
    icrc1 : ?ICRC1.InitArgs;
    icrc2 : ?ICRC2.InitArgs;
    icrc3 : ICRC3.InitArgs; //already typed nullable

    icrc4 : ?ICRC4.InitArgs;
  }
) = this {
  //VARS///////////////////////////
  private stable var siteAdmin = _owner;
  private stable var minter = "";
  private stable var lokaCKBTCPool = "";

  private var adminHash = HashMap.HashMap<Text, Nat>(0, Text.equal, Text.hash);

  let default_icrc1_args : ICRC1.InitArgs = {
    name = ?"LKBTC";
    symbol = ?"LOK";
    logo = ?"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADIAAAAyCAIAAACRXR/mAAAB/klEQVR4nO2YLcvyUByH/3uYyoYDX2Do0sBgWDGKbVWxiZhEP4VRm8GPoVjFpN0hLo2VBcEXNCiCgugUGXLuIM+82e2tOw+CTzhXvHb8eTHkBCmEEPx//Pl0wGNIFg4kCweShQPJwoFk4UCycCBZOJAsHEgWDvesVqtFUVStVvtczJ13vi3TNL1eb7/ff2I+kKUoimVZz41b0F+azSYAVKtV9Dvz+bxUKgmC4PF4wuFwNptVVfX2KJPJfJ8dDAY/zfOF72BkLRYLnuclSVIU5XA4GIaRTqd9Pt/t+xBC9XodAHq9nv0Rh3m58C9ZxWIRADRNs81ut2NZNplMusx6uWDj9reFEOp2u6IoJhIJWwaDwVQqNRqNttvtexfcZq3X6/1+H4vFHF4URQAYj8fvXXCbZZomALAs6/AMw9hP37jgNsvv9wPA+Xx2+NPpBAAcx713wW1WJBIJhUKTycThp9MpRVHxePy9CxjXaS6Xm81mmqbZZrPZDIdDWZYDgQAA0DQNANfr1T7gMC8X7ri/IFarlSAIkiSpqno8HnVdl2WZ4zhd128HOp0OAFQqlcvlYprmT/Ny4dd76yGNRuN2ZrlclsvlaDRK0zTP84VCwTAMe8GyrHw+zzAMx3Htdvuheb5gQyHyb6B7SBYOJAsHkoUDycKBZOFAsnAgWTh8AXVUeZJo9EsOAAAAAElFTkSuQmCC";
    decimals = 8;
    fee = ? #Fixed(0);
    minting_account = ?{
      owner = _owner;
      subaccount = null;
    };
    max_supply = null;
    min_burn_amount = ?10000;
    max_memo = ?64;
    advanced_settings = null;
    metadata = null;
    fee_collector = null;
    transaction_window = null;
    permitted_drift = null;
    max_accounts = ?100000000;
    settle_to_accounts = ?99999000;
  };

  let default_icrc2_args : ICRC2.InitArgs = {
    max_approvals_per_account = ?10000;
    max_allowance = ? #TotalSupply;
    fee = ? #ICRC1;
    advanced_settings = null;
    max_approvals = ?10000000;
    settle_to_approvals = ?9990000;
  };

  let default_icrc3_args : ICRC3.InitArgs = ?{
    maxActiveRecords = 3000;
    settleToRecords = 2000;
    maxRecordsInArchiveInstance = 100000000;
    maxArchivePages = 62500;
    archiveIndexType = #Stable;
    maxRecordsToArchive = 8000;
    archiveCycles = 20_000_000_000_000;
    archiveControllers = null; //??[put cycle ops prinicpal here];
    supportedBlocks = [
      {
        block_type = "1xfer";
        url = "https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-3";
      },
      {
        block_type = "2xfer";
        url = "https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-3";
      },
      {
        block_type = "2approve";
        url = "https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-3";
      },

      {
        block_type = "1mint";
        url = "https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-3";
      },
      {
        block_type = "1burn";
        url = "https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-3";
      },
    ];
  };

  let default_icrc4_args : ICRC4.InitArgs = {
    max_balances = ?3000;
    max_transfers = ?3000;
    fee = ? #ICRC1;
  };

  let icrc1_args : ICRC1.InitArgs = switch (args) {
    case (null) default_icrc1_args;
    case (?args) {
      switch (args.icrc1) {
        case (null) default_icrc1_args;
        case (?val) {
          {
            val with minting_account = switch (
              val.minting_account
            ) {
              case (?val) ?val;
              case (null) {
                ?{
                  owner = _owner;
                  subaccount = null;
                };
              };
            };
          };
        };
      };
    };
  };

  let icrc2_args : ICRC2.InitArgs = switch (args) {
    case (null) default_icrc2_args;
    case (?args) {
      switch (args.icrc2) {
        case (null) default_icrc2_args;
        case (?val) val;
      };
    };
  };

  let icrc3_args : ICRC3.InitArgs = switch (args) {
    case (null) default_icrc3_args;
    case (?args) {
      switch (args.icrc3) {
        case (null) default_icrc3_args;
        case (?val) ?val;
      };
    };
  };

  let icrc4_args : ICRC4.InitArgs = switch (args) {
    case (null) default_icrc4_args;
    case (?args) {
      switch (args.icrc4) {
        case (null) default_icrc4_args;
        case (?val) val;
      };
    };
  };

  stable let icrc1_migration_state = ICRC1.init(ICRC1.initialState(), #v0_1_0(#id), ?icrc1_args, _owner);
  stable let icrc2_migration_state = ICRC2.init(ICRC2.initialState(), #v0_1_0(#id), ?icrc2_args, _owner);
  stable let icrc3_migration_state = ICRC3.init(ICRC3.initialState(), #v0_1_0(#id), icrc3_args, _owner);
  stable let icrc4_migration_state = ICRC4.init(ICRC4.initialState(), #v0_1_0(#id), ?icrc4_args, _owner);
  stable let cert_store : CertTree.Store = CertTree.newStore();
  let ct = CertTree.Ops(cert_store);

  stable var owner = _owner;

  private stable var rebasedSupply = 0;
  private var sharesHash = HashMap.HashMap<Text, Nat>(0, Text.equal, Text.hash);
  private stable var shareHash_ : [(Text, Nat)] = []; // for upgrade
  private stable var totalShare = 0;

  let #v0_1_0(#data(icrc1_state_current)) = icrc1_migration_state;

  private var _icrc1 : ?ICRC1.ICRC1 = null;

  private func rebase() : async Nat {
    var ckBTCBalance : Nat = (await CKBTC.icrc1_balance_of({ owner = Principal.fromText(lokaCKBTCPool); subaccount = null }));
    icrc1().rebase(ckBTCBalance);
    rebasedSupply := ckBTCBalance;
    rebasedSupply;
  };

  public shared (message) func forceRebase() : async Nat {
    assert (_isAdmin(message.caller));
    await rebase();
  };

  public shared (message) func setCKBTCPool(address : Text) : async () {
    assert (_isAdmin(message.caller));
    lokaCKBTCPool := address;
  };

  public shared (message) func setMinter(minter_ : Text) : async () {
    assert (_isAdmin(message.caller));
    minter := minter_;
  };

  private func get_icrc1_state() : ICRC1.CurrentState {
    return icrc1_state_current;
  };

  public shared (message) func addAdmin(p : Text) : async Nat {
    if (message.caller != siteAdmin) return 0;
    switch (adminHash.get(p)) {
      case (?a) {
        return 0;
      };
      case (null) {
        adminHash.put(p, 1);
        return 1;
      };
    };
  };

  func _isAdmin(p : Principal) : Bool {
    switch (adminHash.get(Principal.toText(p))) {
      case (?a) {
        return true;
      };
      case (null) {
        return false;
      };
    };

  };

  private func get_icrc1_environment() : ICRC1.Environment {
    {
      get_time = null;
      get_fee = null;
      add_ledger_transaction = ?icrc3().add_record;
    };
  };

  func icrc1() : ICRC1.ICRC1 {
    switch (_icrc1) {
      case (null) {
        let initclass : ICRC1.ICRC1 = ICRC1.ICRC1(?icrc1_migration_state, Principal.fromActor(this), get_icrc1_environment());
        ignore initclass.register_supported_standards({
          name = "ICRC-3";
          url = "https://github.com/dfinity/ICRC-1/tree/icrc-3/standards/ICRC-3";
        });
        _icrc1 := ?initclass;
        initclass;
      };
      case (?val) val;
    };
  };

  let #v0_1_0(#data(icrc2_state_current)) = icrc2_migration_state;

  private var _icrc2 : ?ICRC2.ICRC2 = null;

  private func get_icrc2_state() : ICRC2.CurrentState {
    return icrc2_state_current;
  };

  private func get_icrc2_environment() : ICRC2.Environment {
    {
      icrc1 = icrc1();
      get_fee = null;
    };
  };

  func icrc2() : ICRC2.ICRC2 {
    switch (_icrc2) {
      case (null) {
        let initclass : ICRC2.ICRC2 = ICRC2.ICRC2(?icrc2_migration_state, Principal.fromActor(this), get_icrc2_environment());
        _icrc2 := ?initclass;
        initclass;
      };
      case (?val) val;
    };
  };

  let #v0_1_0(#data(icrc4_state_current)) = icrc4_migration_state;

  private var _icrc4 : ?ICRC4.ICRC4 = null;

  private func get_icrc4_state() : ICRC4.CurrentState {
    return icrc4_state_current;
  };

  private func get_icrc4_environment() : ICRC4.Environment {
    {
      icrc1 = icrc1();
      get_fee = null;
      can_approve = null; //set to a function to intercept and add validation logic for approvals
      can_transfer_from = null; //set to a function to intercept and add validation logic for transfer froms
    };
  };

  func icrc4() : ICRC4.ICRC4 {
    switch (_icrc4) {
      case (null) {
        let initclass : ICRC4.ICRC4 = ICRC4.ICRC4(?icrc4_migration_state, Principal.fromActor(this), get_icrc4_environment());
        _icrc4 := ?initclass;
        initclass;
      };
      case (?val) val;
    };
  };

  let #v0_1_0(#data(icrc3_state_current)) = icrc3_migration_state;

  private var _icrc3 : ?ICRC3.ICRC3 = null;

  private func get_icrc3_state() : ICRC3.CurrentState {
    return icrc3_state_current;
  };

  func get_state() : ICRC3.CurrentState {
    return icrc3_state_current;
  };

  private func get_icrc3_environment() : ICRC3.Environment {
    ?{
      updated_certification = ?updated_certification;
      get_certificate_store = ?get_certificate_store;
    };
  };

  func ensure_block_types(icrc3Class : ICRC3.ICRC3) : () {
    let supportedBlocks = Buffer.fromIter<ICRC3.BlockType>(icrc3Class.supported_block_types().vals());

    let blockequal = func(a : { block_type : Text }, b : { block_type : Text }) : Bool {
      a.block_type == b.block_type;
    };

    if (Buffer.indexOf<ICRC3.BlockType>({ block_type = "1xfer"; url = "" }, supportedBlocks, blockequal) == null) {
      supportedBlocks.add({
        block_type = "1xfer";
        url = "https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-3";
      });
    };

    if (Buffer.indexOf<ICRC3.BlockType>({ block_type = "2xfer"; url = "" }, supportedBlocks, blockequal) == null) {
      supportedBlocks.add({
        block_type = "2xfer";
        url = "https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-3";
      });
    };

    if (Buffer.indexOf<ICRC3.BlockType>({ block_type = "2approve"; url = "" }, supportedBlocks, blockequal) == null) {
      supportedBlocks.add({
        block_type = "2approve";
        url = "https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-3";
      });
    };

    if (Buffer.indexOf<ICRC3.BlockType>({ block_type = "1mint"; url = "" }, supportedBlocks, blockequal) == null) {
      supportedBlocks.add({
        block_type = "1mint";
        url = "https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-3";
      });
    };

    if (Buffer.indexOf<ICRC3.BlockType>({ block_type = "1burn"; url = "" }, supportedBlocks, blockequal) == null) {
      supportedBlocks.add({
        block_type = "1burn";
        url = "https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-3";
      });
    };

    icrc3Class.update_supported_blocks(Buffer.toArray(supportedBlocks));
  };

  func icrc3() : ICRC3.ICRC3 {
    switch (_icrc3) {
      case (null) {
        let initclass : ICRC3.ICRC3 = ICRC3.ICRC3(?icrc3_migration_state, Principal.fromActor(this), get_icrc3_environment());
        _icrc3 := ?initclass;
        ensure_block_types(initclass);
        initclass;
      };
      case (?val) val;
    };
  };

  private func updated_certification(cert : Blob, lastIndex : Nat) : Bool {

    ct.setCertifiedData();
    return true;
  };

  private func get_certificate_store() : CertTree.Store {
    return cert_store;
  };

  /// Functions for the ICRC1 token standard
  public shared query func icrc1_name() : async Text {
    icrc1().name();
  };

  public shared query func icrc1_symbol() : async Text {
    icrc1().symbol();
  };

  public shared query func icrc1_decimals() : async Nat8 {
    icrc1().decimals();
  };

  public shared query func icrc1_fee() : async ICRC1.Balance {
    icrc1().fee();
  };

  public shared query func icrc1_metadata() : async [ICRC1.MetaDatum] {
    icrc1().metadata();
  };

  public shared query func icrc1_total_supply() : async ICRC1.Balance {
    //icrc1().total_supply();
    rebasedSupply;
  };

  public shared query func icrc1_minting_account() : async ?ICRC1.Account {
    ?icrc1().minting_account();
  };

  public shared (message) func updateShare(address : Text, amount : Nat, totalShare_ : Nat) : async () {
    assert (_isAdmin(message.caller));
    sharesHash.put(address, amount);
    totalShare := totalShare_;
  };

  public shared (message) func updateTotalShare(amount : Nat) : async () {
    assert (_isAdmin(message.caller));
    totalShare := amount;
  };

  public shared query func icrc1_balance_of(args : ICRC1.Account) : async ICRC1.Balance {
    //icrc1().balance_of(args);
    return getBalance(args.owner);

  };

  func getBalance(addr : Principal) : ICRC1.Balance {
    var share_ = sharesHash.get(Principal.toText(addr));
    switch (share_) {
      case (?share) {
        return (share * rebasedSupply) / totalShare;
      };
      case (null) {
        return 0;
      };
    };
  };

  public shared query func icrc1_supported_standards() : async [ICRC1.SupportedStandard] {
    icrc1().supported_standards();
  };

  public shared ({ caller }) func icrc1_transfer(args : ICRC1.TransferArgs) : async ICRC1.TransferResult {
    assert (args.amount <= getBalance(caller));
    var to = args.to.owner;
    if (to == Principal.fromText(minter) and _isAdmin(caller) == false) {
      return D.trap("burn not allowed");
    };
    switch (await* icrc1().transfer_tokens(caller, args, false, null)) {
      case (#trappable(val)) val;
      case (#awaited(val)) val;
      case (#err(#trappable(err))) D.trap(err);
      case (#err(#awaited(err))) D.trap(err);
    };
  };

  public shared ({ caller }) func burn(args : ICRC1.BurnArgs) : async ICRC1.TransferResult {
    assert (_isAdmin(caller));
    switch (await* icrc1().burn_tokens(caller, args, false)) {
      case (#trappable(val)) val;
      case (#awaited(val)) val;
      case (#err(#trappable(err))) D.trap(err);
      case (#err(#awaited(err))) D.trap(err);
    };
  };

  public query ({ caller }) func icrc2_allowance(args : ICRC2.AllowanceArgs) : async ICRC2.Allowance {
    return icrc2().allowance(args.spender, args.account, false);
  };

  public shared ({ caller }) func icrc2_approve(args : ICRC2.ApproveArgs) : async ICRC2.ApproveResponse {
    switch (await* icrc2().approve_transfers(caller, args, false, null)) {
      case (#trappable(val)) val;
      case (#awaited(val)) val;
      case (#err(#trappable(err))) D.trap(err);
      case (#err(#awaited(err))) D.trap(err);
    };
  };

  public shared ({ caller }) func icrc2_transfer_from(args : ICRC2.TransferFromArgs) : async ICRC2.TransferFromResponse {
    var to = args.to.owner;
    if (to == Principal.fromText(minter) and _isAdmin(caller) == false) {
      return D.trap("burn not allowed");
    };
    switch (await* icrc2().transfer_tokens_from(caller, args, null)) {
      case (#trappable(val)) val;
      case (#awaited(val)) val;
      case (#err(#trappable(err))) D.trap(err);
      case (#err(#awaited(err))) D.trap(err);
    };
  };

  public query func icrc3_get_blocks(args : ICRC3.GetBlocksArgs) : async ICRC3.GetBlocksResult {
    return icrc3().get_blocks(args);
  };

  public query func icrc3_get_archives(args : ICRC3.GetArchivesArgs) : async ICRC3.GetArchivesResult {
    return icrc3().get_archives(args);
  };

  public query func icrc3_get_tip_certificate() : async ?ICRC3.DataCertificate {
    return icrc3().get_tip_certificate();
  };

  public query func get_tip() : async ICRC3.Tip {
    return icrc3().get_tip();
  };

  public shared ({ caller }) func icrc4_transfer_batch(args : ICRC4.TransferBatchArgs) : async ICRC4.TransferBatchResults {
    switch (await* icrc4().transfer_batch_tokens(caller, args, null, null)) {
      case (#trappable(val)) val;
      case (#awaited(val)) val;
      case (#err(#trappable(err))) err;
      case (#err(#awaited(err))) err;
    };
  };

  public shared query func icrc4_balance_of_batch(request : ICRC4.BalanceQueryArgs) : async ICRC4.BalanceQueryResult {
    icrc4().balance_of_batch(request);
  };

  public shared ({ caller }) func admin_update_owner(new_owner : Principal) : async Bool {
    if (caller != owner) { D.trap("Unauthorized") };
    owner := new_owner;
    return true;
  };

  public shared ({ caller }) func admin_update_icrc1(requests : [ICRC1.UpdateLedgerInfoRequest]) : async [Bool] {
    if (caller != owner) { D.trap("Unauthorized") };
    return icrc1().update_ledger_info(requests);
  };

  public shared ({ caller }) func admin_update_icrc2(requests : [ICRC2.UpdateLedgerInfoRequest]) : async [Bool] {
    if (caller != owner) { D.trap("Unauthorized") };
    return icrc2().update_ledger_info(requests);
  };

  private stable var _init = false;
  public shared (msg) func admin_init() : async () {
    //can only be called once

    if (_init == false) {
      //ensure metadata has been registered
      let test1 = icrc1().metadata();
      let test2 = icrc2().metadata();
      let test3 = icrc3().stats();

    };
    _init := true;
  };

  // Deposit cycles into this canister.
  public shared func deposit_cycles() : async () {
    let amount = ExperimentalCycles.available();
    let accepted = ExperimentalCycles.accept(amount);
    assert (accepted == amount);
  };

  //////////////////////
  ///
  /// Custom code for implementing rebase-able token
  ///
  //////////////////////

  /// faucet
  public shared ({ caller }) func faucet(account : ICRC1.Account) : async ICRC1.TransferResult {
    assert (_isAdmin(caller));
    switch (
      await* icrc1().mint_tokens(
        icrc1().minting_account().owner,
        {
          to = account;
          amount = 100000000000;
          memo = ?Text.encodeUtf8("Mint!");
          created_at_time = null;
        },
      )
    ) {
      case (#trappable(val)) val;
      case (#awaited(val)) val;
      case (#err(#trappable(err))) D.trap(err);
      case (#err(#awaited(err))) D.trap(err);
    };
  };

  system func preupgrade() {
    shareHash_ := Iter.toArray(sharesHash.entries());
  };

  system func postupgrade() {
    //re wire up the listener after upgrade
    sharesHash := HashMap.fromIter<Text, Nat>(shareHash_.vals(), 1, Text.equal, Text.hash);
  };
};
