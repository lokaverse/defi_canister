import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Bool "mo:base/Debug";
import Float "mo:base/Float";
import Int "mo:base/Int";
import Int64 "mo:base/Int64";
import Iter "mo:base/Iter";
import M "mo:base/HashMap";
import Nat64 "mo:base/Nat64";
import Nat32 "mo:base/Nat32";
import Nat "mo:base/Nat";
import Hash "mo:base/Hash";
import Text "mo:base/Text";
import Blob "mo:base/Blob";
import Cycles "mo:base/ExperimentalCycles";
import Char "mo:base/Char";
import { now } = "mo:base/Time";
import HashMap "mo:base/HashMap";
import { cancelTimer } = "mo:base/Timer";

import T "types";
//import CKBTC "canister:ckbtc_prod"; //PROD
import LOKBTC "canister:lokbtc"; //PROD
import MPTS "canister:mpts"; //PROD
import LPTS "canister:lpts"; //PROD
import CKBTC "canister:ckbtc_test"; //TEST

shared ({ caller = owner }) actor class Miner({
  admin : Principal;
}) = this {
  //indexes
  //private stable var jwalletVault = "rg2ah-xl6x4-z6svw-bdxfv-klmal-cwfel-cfgzg-eoi6q-nszv5-7z5hg-sqe"; //DEV
  private stable var jwalletVault = "43hyn-pv646-27kl3-hhrll-wbdtc-k4idi-7mbyz-uvwxj-hgktq-topls-rae"; //PROD
  private var siteAdmin : Principal = admin;
  private stable var lokBTC = "";
  private stable var totalShares = 0;
  stable var lokaCKBTCPool : Principal = admin;
  private stable var usersIndex = 0;
  private stable var transactionIndex = 0;
  private stable var pause = false : Bool;
  private stable var rebaseIndex = 0;
  private stable var liquidityIndex = 0;
  private stable var schedulerId = 0;
  private stable var nextTimeStamp : Int = 0;
  private stable var counter = 0;

  //buffers and hashmaps

  private var addLiquidityHash = HashMap.HashMap<Nat, T.Liquidity>(0, Nat.equal, Hash.hash);
  private var sharesHash = HashMap.HashMap<Text, T.Shares>(0, Text.equal, Text.hash);
  private var transactionHash = HashMap.HashMap<Text, T.TransactionHistory>(0, Text.equal, Text.hash);
  private var withdrawalHash = HashMap.HashMap<Text, T.Liquidity>(0, Text.equal, Text.hash);
  private var userClaimableCKBTCHash = HashMap.HashMap<Text, [(Nat, T.Claimable)]>(0, Text.equal, Text.hash);
  private var userMaturedClaimableCKBTCHash = HashMap.HashMap<Text, Nat>(0, Text.equal, Text.hash);
  private var userClaimableMPTSHash = HashMap.HashMap<Text, Nat>(0, Text.equal, Text.hash);
  private var userClaimableLPTSHash = HashMap.HashMap<Text, Nat>(0, Text.equal, Text.hash);
  private var userLiquidityHash = HashMap.HashMap<Text, [Nat]>(0, Text.equal, Text.hash);
  private var userWithdrawalHash = HashMap.HashMap<Text, [Nat]>(0, Text.equal, Text.hash);
  private var userAddressHash = HashMap.HashMap<Text, Nat>(0, Text.equal, Text.hash);
  private var userIdHash = HashMap.HashMap<Nat, T.User>(0, Nat.equal, Hash.hash);

  //upgrade temp params
  stable var addLiquidityHash_ : [(Nat, T.Liquidity)] = []; // for upgrade
  stable var sharesHash_ : [(Text, T.Shares)] = [];
  stable var userClaimableCKBTCHash_ : [(Text, [(Nat, T.Claimable)])] = []; // for upgrade
  stable var userClaimableMPTSHash_ : [(Text, Nat)] = []; // for upgrade
  stable var userClaimableLPTSHash_ : [(Text, Nat)] = []; // for upgrade
  stable var userMaturedClaimableCKBTCHash_ : [(Text, Nat)] = []; // for upgrade
  stable var withdrawalHash_ : [(Text, T.Liquidity)] = []; // for upgrade
  stable var userLiquidityHash_ : [(Text, [Nat])] = []; // for upgrade
  stable var userWithdrawalHash_ : [(Text, [Nat])] = []; // for upgrade
  stable var transactionsHash_ : [(Text, T.TransactionHistory)] = [];
  stable var userAddressHash_ : [(Text, Nat)] = [];
  stable var userIdHash_ : [(Nat, T.User)] = [];

  public shared (message) func clearDefiData(burn : Bool) : async () {
    assert (_isAdmin(message.caller));
    addLiquidityHash := HashMap.HashMap<Nat, T.Liquidity>(0, Nat.equal, Hash.hash);
    sharesHash := HashMap.HashMap<Text, T.Shares>(0, Text.equal, Text.hash);
    transactionHash := HashMap.HashMap<Text, T.TransactionHistory>(0, Text.equal, Text.hash);
    withdrawalHash := HashMap.HashMap<Text, T.Liquidity>(0, Text.equal, Text.hash);
    userLiquidityHash := HashMap.HashMap<Text, [Nat]>(0, Text.equal, Text.hash);
    userWithdrawalHash := HashMap.HashMap<Text, [Nat]>(0, Text.equal, Text.hash);
    userAddressHash := HashMap.HashMap<Text, Nat>(0, Text.equal, Text.hash);
    userIdHash := HashMap.HashMap<Nat, T.User>(0, Nat.equal, Hash.hash);
    userClaimableCKBTCHash := HashMap.HashMap<Text, [(Nat, T.Claimable)]>(0, Text.equal, Text.hash);
    userClaimableMPTSHash := HashMap.HashMap<Text, Nat>(0, Text.equal, Text.hash);
    userClaimableLPTSHash := HashMap.HashMap<Text, Nat>(0, Text.equal, Text.hash);
    userMaturedClaimableCKBTCHash := HashMap.HashMap<Text, Nat>(0, Text.equal, Text.hash);

    if (burn) var b = await burnTestCKBTC();

    var a = await LOKBTC.forceRebase();

    totalShares := 0;

    usersIndex := 0;
    transactionIndex := 0;
    pause := false : Bool;
    rebaseIndex := 0;
    liquidityIndex := 0;
    schedulerId := 0;
    nextTimeStamp := 0;
    counter := 0;
    totalShares := 0;

  };

  system func preupgrade() {
    userAddressHash_ := Iter.toArray(userAddressHash.entries());
    userIdHash_ := Iter.toArray(userIdHash.entries());
    addLiquidityHash_ := Iter.toArray(addLiquidityHash.entries());
    withdrawalHash_ := Iter.toArray(withdrawalHash.entries());
    sharesHash_ := Iter.toArray(sharesHash.entries());
    userClaimableCKBTCHash_ := Iter.toArray(userClaimableCKBTCHash.entries());
    userLiquidityHash_ := Iter.toArray(userLiquidityHash.entries());
    userWithdrawalHash_ := Iter.toArray(userWithdrawalHash.entries());
    transactionsHash_ := Iter.toArray(transactionHash.entries());
    userClaimableMPTSHash_ := Iter.toArray(userClaimableMPTSHash.entries());
    userClaimableLPTSHash_ := Iter.toArray(userClaimableLPTSHash.entries());
    userMaturedClaimableCKBTCHash_ := Iter.toArray(userMaturedClaimableCKBTCHash.entries());
    //sharesHash_:=

  };
  system func postupgrade() {
    userAddressHash := HashMap.fromIter<Text, Nat>(userAddressHash_.vals(), 1, Text.equal, Text.hash);
    userIdHash := HashMap.fromIter<Nat, T.User>(userIdHash_.vals(), 1, Nat.equal, Hash.hash);
    addLiquidityHash := HashMap.fromIter<Nat, T.Liquidity>(addLiquidityHash_.vals(), 1, Nat.equal, Hash.hash);
    withdrawalHash := HashMap.fromIter<Text, T.Liquidity>(withdrawalHash_.vals(), 1, Text.equal, Text.hash);
    sharesHash := HashMap.fromIter<Text, T.Shares>(sharesHash_.vals(), 1, Text.equal, Text.hash);
    userClaimableCKBTCHash := HashMap.fromIter<Text, [(Nat, T.Claimable)]>(userClaimableCKBTCHash_.vals(), 1, Text.equal, Text.hash);
    userLiquidityHash := HashMap.fromIter<Text, [Nat]>(userLiquidityHash_.vals(), 1, Text.equal, Text.hash);
    userWithdrawalHash := HashMap.fromIter<Text, [Nat]>(userWithdrawalHash_.vals(), 1, Text.equal, Text.hash);
    transactionHash := HashMap.fromIter<Text, T.TransactionHistory>(transactionsHash_.vals(), 1, Text.equal, Text.hash);
    userClaimableMPTSHash := HashMap.fromIter<Text, Nat>(userClaimableMPTSHash_.vals(), 1, Text.equal, Text.hash);
    userClaimableLPTSHash := HashMap.fromIter<Text, Nat>(userClaimableLPTSHash_.vals(), 1, Text.equal, Text.hash);
    userMaturedClaimableCKBTCHash := HashMap.fromIter<Text, Nat>(userMaturedClaimableCKBTCHash_.vals(), 1, Text.equal, Text.hash);
    //let sched = await initScheduler();
  };

  public query func getCurrentScheduler() : async Nat {
    return schedulerId;
  };

  public query func getNextRebaseHour() : async Int {
    return nextTimeStamp;
  };

  /*public shared (message) func forceEx() : async () {
    nextTimeStamp := 1;
  }; */

  public shared (message) func getUserData() : async {
    ckbtc : Nat;
    lokbtc : Nat;
    staked : Nat;
    mpts : Nat;
    lpts : Nat;
    claimableMPTS : Nat;
    claimableLPTS : Nat;
    //lptsDistributionHistory : Nat;
    //mptsDistributionHistory : Nat;
    //liquidityHistory : Nat;
    ckBTCClaimList : [(Nat, T.Claimable)];
    totalWithdrawableCKBTC : Nat;
    totalPendingCKBTC : Nat;
  } {
    var ckBTCBalance : Nat = (await CKBTC.icrc1_balance_of({ owner = message.caller; subaccount = null }));
    var lokBTCBalance : Nat = (await LOKBTC.icrc1_balance_of({ owner = message.caller; subaccount = null }));
    var mptsBalance : Nat = (await MPTS.icrc1_balance_of({ owner = message.caller; subaccount = null }));
    var lptsBalance : Nat = (await LPTS.icrc1_balance_of({ owner = message.caller; subaccount = null }));

    var stakedShare = 0;
    var claimList : [(Nat, T.Claimable)] = [];
    var claimableLPTS_ = 0;
    var claimableMPTS_ = 0;
    var now_ = now() / 1000000;
    var totalWithdrawableCKBTC = 0;
    var totalPendingCKBTC = 0;
    var callertxt = Principal.toText(message.caller);
    switch (userMaturedClaimableCKBTCHash.get(callertxt)) {
      case (?wdable) {
        totalWithdrawableCKBTC += wdable;
      };
      case (null) {

      };
    };

    switch (userClaimableCKBTCHash.get(Principal.toText(message.caller))) {

      case (?claimable_) {
        var detailedHash = HashMap.fromIter<Nat, T.Claimable>(claimable_.vals(), 1, Nat.equal, Hash.hash);

        for (claim in claimable_.vals()) {
          if (claim.1.time <= now_) {
            totalWithdrawableCKBTC += claim.1.amount;
            detailedHash.delete(claim.0);
          } else {
            totalPendingCKBTC += claim.1.amount;
          };
        };
        var detailedHashArray = Iter.toArray(detailedHash.entries());
        userClaimableCKBTCHash.put(callertxt, detailedHashArray);
        claimList := detailedHashArray;
        userMaturedClaimableCKBTCHash.put(callertxt, totalWithdrawableCKBTC);
      };
      case (null) {

      };

    };
    switch (userClaimableLPTSHash.get(Principal.toText(message.caller))) {

      case (?claimable_) {
        claimableLPTS_ := claimable_;

      };
      case (null) {

      };

    };
    switch (userClaimableMPTSHash.get(Principal.toText(message.caller))) {

      case (?claimable_) {
        claimableMPTS_ := claimable_;

      };
      case (null) {

      };

    };
    switch (sharesHash.get(Principal.toText(message.caller))) {
      case (?share) {
        stakedShare := share.share;

      };
      case (null) {

      };
    };
    let datas = {
      ckbtc = ckBTCBalance;
      lokbtc = lokBTCBalance;
      staked = stakedShare;
      lpts = lptsBalance;
      mpts = mptsBalance;
      ckBTCClaimList = claimList;
      claimableLPTS = claimableLPTS_;
      claimableMPTS = claimableMPTS_;
      totalPendingCKBTC = totalPendingCKBTC;
      totalWithdrawableCKBTC = totalWithdrawableCKBTC;
    };
    return datas;
  };

  public shared (message) func distributeLPTS(amountSat_ : Nat) : async () {
    assert (_isAdmin(message.caller));
    sharesHash_ := Iter.toArray(sharesHash.entries());
    var totalLPTS = amountSat_ * 10000;
    for (shares in sharesHash.vals()) {
      var sharedLPTS = (shares.share * totalLPTS) / totalShares;
      //transfer sharedLPTS to shares.walletAddress
      switch (userClaimableLPTSHash.get(shares.walletAddress)) {
        case (?claimable) {
          userClaimableLPTSHash.put(shares.walletAddress, sharedLPTS + claimable);
        };
        case (null) {
          userClaimableLPTSHash.put(shares.walletAddress, sharedLPTS);
        };
      };
    };
  };

  public shared (message) func distributeMPTS(amountSat_ : Nat, to : Text) : async () {
    assert (_isAdmin(message.caller));
    var amount_ = amountSat_ * 10000;
    switch (userClaimableMPTSHash.get(to)) {
      case (?claimable) {
        userClaimableMPTSHash.put(to, amount_ + claimable);
      };
      case (null) {
        userClaimableMPTSHash.put(to, amount_);
      };
    };
  };

  public shared (message) func getMPTS() : async [(Text, Nat)] {
    assert (_isAdmin(message.caller));
    return Iter.toArray(userClaimableMPTSHash.entries());
  };

  public shared (message) func getLPTS() : async [(Text, Nat)] {
    assert (_isAdmin(message.caller));
    return Iter.toArray(userClaimableLPTSHash.entries());
  };

  public shared (message) func swapToMPTS(amount : Nat) : async T.TransferRes {
    //burnMPTS
    //mintLPTS
    var burnLPTS_ = await burnLPTS(message.caller, amount);
    switch (burnLPTS_) {
      case (#success(number)) {
        let transferResult = await MPTS.icrc1_transfer({
          amount = amount;
          fee = ?0;
          created_at_time = null;
          from_subaccount = null;
          to = {
            owner = message.caller;
            subaccount = null;
          };
          memo = null;
        });

        switch (transferResult) {
          case (#Ok(number)) {
            return #success(number);
          };
          case (#Err(msg)) { return #error("error minting MPTS ") };
        };
      };
      case (#error(msg)) { return #error("error burning LPTS " #msg) };
    };
    return #error("other");
  };

  public shared (message) func swapToLPTS(amount : Nat) : async T.TransferRes {
    //burnMPTS
    //mintLPTS
    var burnLPTS_ = await burnMPTS(message.caller, amount);
    switch (burnLPTS_) {
      case (#success(number)) {
        let transferResult = await LPTS.icrc1_transfer({
          amount = amount;
          fee = ?0;
          created_at_time = null;
          from_subaccount = null;
          to = {
            owner = message.caller;
            subaccount = null;
          };
          memo = null;
        });

        switch (transferResult) {
          case (#Ok(number)) {
            return #success(number);
          };
          case (#Err(msg)) { return #error("error minting LPTS ") };
        };
      };
      case (#error(msg)) { return #error("error burning MPTS " #msg) };
    };
    return #error("other");

  };

  func burnMPTS(owner_ : Principal, amount_ : Nat) : async T.TransferRes {
    let transferResult = await MPTS.icrc2_transfer_from({
      from = { owner = owner_; subaccount = null };
      amount = amount_;
      fee = null;
      created_at_time = null;
      from_subaccount = null;
      to = { owner = Principal.fromActor(this); subaccount = null };
      spender_subaccount = null;
      memo = null;
    });

    switch (transferResult) {
      case (#Ok(number)) {
        return #success(number);
      };
      case (#Err(msg)) {

        Debug.print("transfer error  ");
        switch (msg) {
          case (#BadFee(number)) {
            return #error("Bad Fee");
          };
          case (#GenericError(number)) {
            return #error("Generic");
          };
          case (#BadBurn(number)) {
            return #error("BadBurn");
          };
          case (#InsufficientFunds(number)) {
            return #error("Insufficient Funds");
          };
          case (#InsufficientAllowance(number)) {
            return #error("Insufficient Allowance ");
          };
          case _ {
            Debug.print("ICP err");
          };
        };
        return #error("ICP transfer other error");
      };
    };
  };

  func burnLPTS(owner_ : Principal, amount_ : Nat) : async T.TransferRes {
    let transferResult = await LPTS.icrc2_transfer_from({
      from = { owner = owner_; subaccount = null };
      amount = amount_;
      fee = null;
      created_at_time = null;
      from_subaccount = null;
      to = { owner = Principal.fromActor(this); subaccount = null };
      spender_subaccount = null;
      memo = null;
    });

    switch (transferResult) {
      case (#Ok(number)) {
        return #success(number);
      };
      case (#Err(msg)) {

        Debug.print("transfer error  ");
        switch (msg) {
          case (#BadFee(number)) {
            return #error("Bad Fee");
          };
          case (#GenericError(number)) {
            return #error("Generic");
          };
          case (#BadBurn(number)) {
            return #error("BadBurn");
          };
          case (#InsufficientFunds(number)) {
            return #error("Insufficient Funds");
          };
          case (#InsufficientAllowance(number)) {
            return #error("Insufficient Allowance ");
          };
          case _ {
            Debug.print("ICP err");
          };
        };
        return #error("ICP transfer other error");
      };
    };
  };

  public shared (message) func claimMPTS() : async T.TransferRes {
    switch (userClaimableMPTSHash.get(Principal.toText(message.caller))) {
      case (?claimable) {
        let transferResult = await MPTS.icrc1_transfer({
          amount = claimable;
          fee = ?0;
          created_at_time = null;
          from_subaccount = null;
          to = {
            owner = message.caller;
            subaccount = null;
          };
          memo = null;
        });

        switch (transferResult) {
          case (#Ok(number)) {
            userClaimableMPTSHash.put(Principal.toText(message.caller), 0);
            return #success(number);
          };
          case (#Err(msg)) { return #error("error") };
        };

      };
      case (null) {
        return #error("no claimable");
      };
    };

  };

  public shared (message) func claimLPTS() : async T.TransferRes {
    switch (userClaimableLPTSHash.get(Principal.toText(message.caller))) {
      case (?claimable) {
        let transferResult = await LPTS.icrc1_transfer({
          amount = claimable;
          fee = ?0;
          created_at_time = null;
          from_subaccount = null;
          to = {
            owner = message.caller;
            subaccount = null;
          };
          memo = null;
        });

        switch (transferResult) {
          case (#Ok(number)) {
            userClaimableLPTSHash.put(Principal.toText(message.caller), 0);
            return #success(number);
          };
          case (#Err(msg)) { return #error("error") };
        };

      };
      case (null) {
        return #error("no claimable");
      };
    };
  };

  public query (message) func getCounter() : async Nat {
    return counter;
  };

  func getNextTimeStamp() : async Int {
    Debug.print("getting next timestamp");
    //let tmn_ = tm_;
    //let url = "https://api.lokamining.com/nextTimeStamp?timestamp=" #Int.toText(tmn_);
    var text = await send_http("https://api.dragoneyes.xyz/gts");
    var n = Float.toInt(natToFloat(textToNat(text)));

    return n;
    //return 0;

  };

  public shared (message) func getTime() : async Bool {
    var a = await getNextTimeStamp();
    var tm = now() / 1000000;
    return a > tm;

  };

  public shared (message) func setLOKBTC(address : Text) : async () {
    assert (_isAdmin(message.caller));
    lokBTC := address;
  };
  private stable var poolCanister = "";

  public shared (message) func setPoolCanister(address : Text) : async () {
    assert (_isAdmin(message.caller));
    poolCanister := address;
  };

  func _isAdmin(p : Principal) : Bool {
    return (p == siteAdmin or p == Principal.fromText(poolCanister));
  };

  func _isNotPaused() : Bool {
    if (pause) return false;
    true;
  };

  public query func isNotPaused() : async Bool {
    if (pause) return false;
    true;
  };

  public shared (message) func setCKBTCPool(pool_ : Text) : async Principal {
    assert (_isAdmin(message.caller));
    lokaCKBTCPool := Principal.fromText(pool_);
    lokaCKBTCPool;
  };

  public shared (message) func setJwalletVault(vault_ : Text) : async Text {
    assert (_isAdmin(message.caller));
    jwalletVault := vault_;
    vault_;
  };

  public shared (message) func pauseCanister(pause_ : Bool) : async Bool {
    assert (_isAdmin(message.caller));
    pause := pause_;
    pause_;
  };

  public query func getCanisterTimeStamp() : async Int {
    return now();
  };

  public shared func getCKBTCBalance() : async Nat {
    var ckBTCBalance : Nat = (await CKBTC.icrc1_balance_of({ owner = Principal.fromActor(this); subaccount = null }));
    ckBTCBalance;
  };

  public type Utxo = {
    height : Nat32;
    value : Nat64;
    outpoint : { txid : Blob; vout : Nat32 };
  };
  public type UtxoStatus = {
    #ValueTooSmall : Utxo;
    #Tainted : Utxo;
    #Minted : { minted_amount : Nat64; block_index : Nat64; utxo : Utxo };
    #Checked : Utxo;
  };

  public type PendingUtxo = {
    confirmations : Nat32;
    value : Nat64;
    outpoint : { txid : Blob; vout : Nat32 };
  };
  public type UpdateBalanceError = {
    #GenericError : { error_message : Text; error_code : Nat64 };
    #TemporarilyUnavailable : Text;
    #AlreadyProcessing;
    #NoNewUtxos : {
      required_confirmations : Nat32;
      pending_utxos : ?[PendingUtxo];
      current_confirmations : ?Nat32;
    };
  };

  public shared (message) func updateckBTCBalance() : async () {
    let Minter = actor ("mqygn-kiaaa-aaaar-qaadq-cai") : actor {
      update_balance : ({ subaccount : ?Nat }) -> async {
        #Ok : [UtxoStatus];
        #Err : UpdateBalanceError;
      };
    };
    let result = await Minter.update_balance({ subaccount = null }); //"(record {subaccount=null;})"

  };

  func btcToSats(btc : Float) : Int {
    let sats = 100000000 * btc;
    Float.toInt(sats);
  };

  func textToNat(txt : Text) : Nat {
    assert (txt.size() > 0);
    let chars = txt.chars();

    var num : Nat = 0;
    for (v in chars) {
      let charToNum = Nat32.toNat(Char.toNat32(v) -48);
      assert (charToNum >= 0 and charToNum <= 9);
      num := num * 10 + charToNum;
    };

    num;
  };

  public shared (message) func getCKBTCMinter() : async Text {
    let Minter = actor ("mqygn-kiaaa-aaaar-qaadq-cai") : actor {
      get_btc_address : ({ subaccount : ?Nat }) -> async Text;
    };
    let result = await Minter.get_btc_address({ subaccount = null }); //"(record {subaccount=null;})"
    result;
  };

  public shared (message) func addLiquidity(amount_ : Nat) : async T.AddLiquidityResult {
    assert (_isNotPaused());
    let transferRes_ = await transferCKBTCFrom(message.caller, amount_);
    var transIndex_ = 0;
    switch transferRes_ {
      case (#success(x)) {
        totalShares += amount_;
        var updatedShare = amount_;

        switch (sharesHash.get(Principal.toText(message.caller))) {
          case (?currentShare) {
            var shr = {
              walletAddress = Principal.toText(message.caller);
              share = currentShare.share + amount_;
            };
            sharesHash.put(Principal.toText(message.caller), shr);
            updatedShare := currentShare.share + amount_;
          };
          case (null) {
            var shr = {
              walletAddress = Principal.toText(message.caller);
              share = amount_;
            };
            sharesHash.put(Principal.toText(message.caller), shr);
          };
        };

        //update totalshare and share to lokbtc canister
        await LOKBTC.updateShare(Principal.toText(message.caller), updatedShare, totalShares);

        let liquidity_ = {
          id = liquidityIndex;
          wallet = message.caller;
          //caller: Text;
          time = now();
          //receiver : Text;
          amount = Nat.toText(amount_);
          token = "CKBTC";
          //provider : Text;
        };
        addLiquidityHash.put(liquidityIndex, liquidity_);
        switch (userLiquidityHash.get(Principal.toText(message.caller))) {
          case (?list) {
            userLiquidityHash.put(Principal.toText(message.caller), Array.append<Nat>(list, [liquidityIndex]));
          };
          case (null) {

          };
        };
        liquidityIndex += 1;

        return #success(x);
      };
      case (#error(txt)) {
        Debug.print("error " #txt);
        return #transferFailed(txt);
      };
    };

  };

  func transferCKBTCFrom(owner_ : Principal, amount_ : Nat) : async T.TransferResult {
    //Debug.print("transferring from " #Principal.toText(owner_) # " by " #Principal.toText(Principal.fromActor(this)) # " " #Nat.toText(amount_));
    let transferResult = await CKBTC.icrc2_transfer_from({
      from = { owner = owner_; subaccount = null };
      amount = amount_;
      fee = ?0;
      created_at_time = null;
      from_subaccount = null;
      to = { owner = lokaCKBTCPool; subaccount = null };
      spender_subaccount = null;
      memo = null;
    });
    //var res = 0;
    switch (transferResult) {
      case (#Ok(number)) {
        return #success(number);
      };
      case (#Err(msg)) {

        Debug.print("transfer error  ");
        switch (msg) {
          case (#BadFee(number)) {
            return #error("Bad Fee");
          };
          case (#GenericError(number)) {
            return #error("Generic");
          };
          case (#BadBurn(number)) {
            return #error("BadBurn");
          };
          case (#InsufficientFunds(number)) {
            return #error("Insufficient Funds");
          };
          case (#InsufficientAllowance(number)) {
            return #error("Insufficient Allowance ");
          };
          case _ {
            Debug.print("ICP err");
          };
        };
        return #error("ICP transfer other error");
      };
    };
  };

  func burnTestCKBTC() : async T.TransferResult {
    //assert (_isAdmin(message.caller));
    //Debug.print("transferring from " #Principal.toText(owner_) # " by " #Principal.toText(Principal.fromActor(this)) # " " #Nat.toText(amount_));
    var amount_ : Nat = (await CKBTC.icrc1_balance_of({ owner = Principal.fromActor(this); subaccount = null }));
    let transferResult = await CKBTC.icrc1_transfer({
      amount = amount_;
      fee = ?0;
      created_at_time = null;
      from_subaccount = null;
      to = {
        owner = Principal.fromText("mtyh3-temyy-tmbjp-ftvuq-4fn46-do3rx-kpkmx-sghhf-pfvs7-5viz5-nae");
        subaccount = null;
      };
      memo = null;
    });

    switch (transferResult) {
      case (#Ok(number)) {

        return #success(number);
      };
      case (#Err(msg)) { return #error("error") };
    };

  };

  public shared (message) func claimCKBTC() : async T.TransferRes {
    switch (userMaturedClaimableCKBTCHash.get(Principal.toText(message.caller))) {

      case (?claimable) {
        let transferResult = await CKBTC.icrc1_transfer({
          amount = claimable;
          fee = ?0;
          created_at_time = null;
          from_subaccount = null;
          to = { owner = message.caller; subaccount = null };
          memo = null;
        });

        switch (transferResult) {
          case (#Ok(number)) {
            userMaturedClaimableCKBTCHash.put(Principal.toText(message.caller), 0);
            return #success(number);
          };
          case (#Err(msg)) { #error("transfer error") };
        };

      };
      case (null) {
        return #error("claim not found");
      };

    };

  };

  private stable var claimCKBTCId = 0;
  public shared (message) func requestRedeem(amount_ : Nat) : async {
    #success : T.Claimable;
    #error : Text;
  } {
    assert (_isNotPaused());
    var timeRedeem = now() / 1000000 + (1000 * 60 * 60 * 24);
    //check enough lokBTC
    // var lokBTCBalance : Nat = (await LOKBTC.icrc1_balance_of({ owner = message.caller; subaccount = null }));
    switch (sharesHash.get(Principal.toText(message.caller))) {
      case (?share) {
        if (share.share >= (amount_ + 10)) {
          //return #error("okgooda " #Nat.toText(totalShares) # " sub by " #Nat.toText(amount_ + 10));
          //update totalshare and share to lokbtc canister
          totalShares -= (amount_ + 10);

          //update totalshare and share to lokbtc canister
          await LOKBTC.updateShare(Principal.toText(message.caller), (share.share -(amount_ + 10)), totalShares);
          var shr = {
            walletAddress = Principal.toText(message.caller);
            share = share.share - amount_;
          };
          sharesHash.put(Principal.toText(message.caller), shr);
          var claimObject = {
            id = claimCKBTCId;
            amount = amount_;
            time = timeRedeem;
          };

          switch (userClaimableCKBTCHash.get(Principal.toText(message.caller))) {
            case (?claimable_) {
              var detailedHash = HashMap.fromIter<Nat, T.Claimable>(claimable_.vals(), 1, Nat.equal, Hash.hash);
              detailedHash.put(claimCKBTCId, claimObject);
              var detailedHashArray = Iter.toArray(detailedHash.entries());
              userClaimableCKBTCHash.put(Principal.toText(message.caller), detailedHashArray);
            };
            case (null) {
              var detailedHash = HashMap.HashMap<Nat, T.Claimable>(0, Nat.equal, Hash.hash);
              detailedHash.put(claimCKBTCId, claimObject);
              var detailedHashArray = Iter.toArray(detailedHash.entries());
              userClaimableCKBTCHash.put(Principal.toText(message.caller), detailedHashArray);
            };

          };
          claimCKBTCId += 1;
          return #success(claimObject);

        } else {
          return #error("insufficient lokbtc");
        };
      };
      case (null) {

      };
    };
    return #error("error");

  };

  public query (message) func whoCall() : async Text {
    return Principal.toText(message.caller);
  };

  func send_http(url_ : Text) : async Text {
    let ic : T.IC = actor ("aaaaa-aa");

    let url = url_;

    let request_headers = [
      { name = "User-Agent"; value = "miner_canister" },
      { name = "Content-Type"; value = "application/json" },
      { name = "x-api-key"; value = "2021LokaInfinity" },
    ];
    Debug.print("accessing " #url);
    let transform_context : T.TransformContext = {
      function = transform;
      context = Blob.fromArray([]);
    };

    let http_request : T.HttpRequestArgs = {
      url = url;
      max_response_bytes = null; //optional for request
      headers = request_headers;
      body = null; //optional for request
      method = #get;
      transform = ?transform_context;
    };

    Cycles.add(30_000_000_000);

    let http_response : T.HttpResponsePayload = await ic.http_request(http_request);
    let response_body : Blob = Blob.fromArray(http_response.body);
    let decoded_text : Text = switch (Text.decodeUtf8(response_body)) {
      case (null) { "No value returned" };
      case (?y) { y };
    };
    decoded_text;
  };

  private func natToFloat(nat_ : Nat) : Float {
    let toNat64_ = Nat64.fromNat(nat_);
    let toInt64_ = Int64.fromNat64(toNat64_);
    let amountFloat_ = Float.fromInt64(toInt64_);
    return amountFloat_;
  };

  func textToFloat(t : Text) : Float {

    var i : Float = 1;
    var f : Float = 0;
    var isDecimal : Bool = false;

    for (c in t.chars()) {
      if (Char.isDigit(c)) {
        let charToNat : Nat64 = Nat64.fromNat(Nat32.toNat(Char.toNat32(c) -48));
        let natToFloat : Float = Float.fromInt64(Int64.fromNat64(charToNat));
        if (isDecimal) {
          let n : Float = natToFloat / Float.pow(10, i);
          f := f + n;
        } else {
          f := f * 10 + natToFloat;
        };
        i := i + 1;
      } else {
        if (Char.equal(c, '.') or Char.equal(c, ',')) {
          f := f / Float.pow(10, i); // Force decimal
          f := f * Float.pow(10, i); // Correction
          isDecimal := true;
          i := 1;
        } else {
          //throw Error.reject("NaN");
          return 0.0;
        };
      };
    };

    return f;
  };

  //@DEV- CORE FUNCTIONS TO CALL LOKBTC TO REBASE BALANCE ONCE THERE IS NEW BTC MINED

  public shared (message) func rebaseLOKBTC() : async Text {
    assert (_isAdmin(message.caller));
    var a = await LOKBTC.forceRebase();
    Nat.toText(a);
  };

  func textSplit(word_ : Text, delimiter_ : Char) : [Text] {
    let hasil = Text.split(word_, #char delimiter_);
    let wordsArray = Iter.toArray(hasil);
    return wordsArray;
    //Debug.print(wordsArray[0]);
  };

  public query func transform(raw : T.TransformArgs) : async T.CanisterHttpResponsePayload {
    let transformed : T.CanisterHttpResponsePayload = {
      status = raw.response.status;
      body = raw.response.body;
      headers = [
        {
          name = "Content-Security-Policy";
          value = "default-src 'self'";
        },
        { name = "Referrer-Policy"; value = "strict-origin" },
        { name = "Permissions-Policy"; value = "geolocation=(self)" },
        {
          name = "Strict-Transport-Security";
          value = "max-age=63072000";
        },
        { name = "X-Frame-Options"; value = "DENY" },
        { name = "X-Content-Type-Options"; value = "nosniff" },
      ];
    };
    transformed;

  };

};
