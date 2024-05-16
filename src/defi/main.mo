import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
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
import Time "mo:base/Time";
import Result "mo:base/Result";
import Blob "mo:base/Blob";
import Cycles "mo:base/ExperimentalCycles";
import Char "mo:base/Char";
import { now } = "mo:base/Time";
import { abs } = "mo:base/Int";
import HashMap "mo:base/HashMap";
import { setTimer; cancelTimer; recurringTimer } = "mo:base/Timer";

import T "types";
//import CKBTC "canister:ckbtc_prod"; //PROD
import LOKBTC "canister:lokbtc"; //PROD
import CKBTC "canister:ckbtc_test"; //TEST

shared ({ caller = owner }) actor class Miner({
  admin : Principal;
}) = this {
  //indexes
  //private stable var jwalletVault = "rg2ah-xl6x4-z6svw-bdxfv-klmal-cwfel-cfgzg-eoi6q-nszv5-7z5hg-sqe"; //DEV
  private stable var jwalletVault = "43hyn-pv646-27kl3-hhrll-wbdtc-k4idi-7mbyz-uvwxj-hgktq-topls-rae"; //PROD
  private var siteAdmin : Principal = admin;
  private var lokBTC = "";
  private var totalShares = 0;
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
  private var sharesHash = HashMap.HashMap<Text, Nat>(0, Text.equal, Text.hash);
  private var transactionHash = HashMap.HashMap<Text, T.TransactionHistory>(0, Text.equal, Text.hash);
  private var withdrawalHash = HashMap.HashMap<Text, T.Liquidity>(0, Text.equal, Text.hash);
  private var userLiquidityHash = HashMap.HashMap<Text, [Nat]>(0, Text.equal, Text.hash);
  private var userWithdrawalHash = HashMap.HashMap<Text, [Nat]>(0, Text.equal, Text.hash);
  private var userAddressHash = HashMap.HashMap<Text, Nat>(0, Text.equal, Text.hash);
  private var userIdHash = HashMap.HashMap<Nat, T.User>(0, Nat.equal, Hash.hash);
  private var jwalletId = HashMap.HashMap<Text, Text>(0, Text.equal, Text.hash);

  //upgrade temp params
  stable var addLiquidityHash_ : [(Nat, T.Liquidity)] = []; // for upgrade
  stable var withdrawalHash_ : [(Text, T.Liquidity)] = []; // for upgrade
  stable var userLiquidityHash_ : [(Text, [Nat])] = []; // for upgrade
  stable var userWithdrawalHash_ : [(Text, [Nat])] = []; // for upgrade
  stable var transactionsHash_ : [(Text, T.TransactionHistory)] = [];
  stable var userAddressHash_ : [(Text, Nat)] = [];
  stable var userIdHash_ : [(Nat, T.User)] = [];

  public shared (message) func clearData() : async () {
    assert (_isAdmin(message.caller));
    addLiquidityHash := HashMap.HashMap<Nat, T.Liquidity>(0, Nat.equal, Hash.hash);
    sharesHash := HashMap.HashMap<Text, Nat>(0, Text.equal, Text.hash);
    transactionHash := HashMap.HashMap<Text, T.TransactionHistory>(0, Text.equal, Text.hash);
    withdrawalHash := HashMap.HashMap<Text, T.Liquidity>(0, Text.equal, Text.hash);
    userLiquidityHash := HashMap.HashMap<Text, [Nat]>(0, Text.equal, Text.hash);
    userWithdrawalHash := HashMap.HashMap<Text, [Nat]>(0, Text.equal, Text.hash);
    userAddressHash := HashMap.HashMap<Text, Nat>(0, Text.equal, Text.hash);
    userIdHash := HashMap.HashMap<Nat, T.User>(0, Nat.equal, Hash.hash);

    totalShares := 0;

    usersIndex := 0;
    transactionIndex := 0;
    pause := false : Bool;
    rebaseIndex := 0;
    liquidityIndex := 0;
    schedulerId := 0;
    nextTimeStamp := 0;
    counter := 0;

  };

  system func preupgrade() {
    userAddressHash_ := Iter.toArray(userAddressHash.entries());
    userIdHash_ := Iter.toArray(userIdHash.entries());
    addLiquidityHash_ := Iter.toArray(addLiquidityHash.entries());
    //sharesHash_:=

  };
  system func postupgrade() {

    //let sched = await initScheduler();
  };

  public query func getCurrentScheduler() : async Nat {
    return schedulerId;
  };

  public query func getNextRebaseHour() : async Int {
    return nextTimeStamp;
  };

  //function to check scheduler / scheduler
  //returns counter+10 each 10 seconds when waiting for night time, and only adds +1 when already active

  func stopScheduler(id_ : Nat) : Bool {
    let res = cancelTimer(id_);
    true;
  };

  /*public shared (message) func forceEx() : async () {
    nextTimeStamp := 1;
  }; */

  public shared (message) func startScheduler() : async Nat {
    assert (_isAdmin(message.caller));
    let t_ = now() / 1000000;
    await initScheduler(t_);
  };

  public shared (message) func getUserData() : async {
    ckbtc : Nat;
    lokbtc : Nat;
    staked : Nat;
  } {
    var ckBTCBalance : Nat = (await CKBTC.icrc1_balance_of({ owner = message.caller; subaccount = null }));
    var lokBTCBalance : Nat = (await LOKBTC.icrc1_balance_of({ owner = message.caller; subaccount = null }));
    var stakedShare = 0;
    switch (sharesHash.get(Principal.toText(message.caller))) {
      case (?share) {
        stakedShare := share;
      };
      case (null) {

      };
    };
    let datas = {
      ckbtc = ckBTCBalance;
      lokbtc = lokBTCBalance;
      staked = stakedShare;
    };
    return datas;
  };

  func initScheduler<system>(t_ : Int) : async Nat {

    cancelTimer(schedulerId);
    let currentTimeStamp_ = t_;
    counter := 0;
    nextTimeStamp := 0;
    nextTimeStamp := await getNextTimeStamp();
    Debug.print("stamp " #Int.toText(nextTimeStamp));
    if (nextTimeStamp == 0) return 0;
    schedulerId := recurringTimer(
      #seconds(10),
      func() : async () {
        if (counter < 100) { counter += 10 } else { counter := 0 };
        let time_ = now() / 1000000;
        if (time_ >= nextTimeStamp) {
          counter := 200;

          let res = await routine24();

          //cancelTimer(schedulerId);
          // schedulerId := scheduler();

        };
      },
    );
    schedulerId;
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

  public shared (message) func setLOKBTC(address : Text) : async () {
    assert (_isAdmin(message.caller));
    lokBTC := address;
  };

  func _isAdmin(p : Principal) : Bool {
    return (p == siteAdmin);
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
            sharesHash.put(Principal.toText(message.caller), currentShare + amount_);
            updatedShare := currentShare + amount_;
          };
          case (null) {
            sharesHash.put(Principal.toText(message.caller), amount_);
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

  public shared (message) func burnTestCKBTC() : async T.TransferResult {
    assert (_isAdmin(message.caller));
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

  public shared (message) func withdrawCKBTC(amount_ : Nat) : async T.TransferRes {
    assert (_isNotPaused());

    //check enough lokBTC
    // var lokBTCBalance : Nat = (await LOKBTC.icrc1_balance_of({ owner = message.caller; subaccount = null }));
    switch (sharesHash.get(Principal.toText(message.caller))) {
      case (?share) {
        if (share >= (amount_ + 10)) {
          //update totalshare and share to lokbtc canister
          totalShares -= (amount_ + 10);
          //update totalshare and share to lokbtc canister
          await LOKBTC.updateShare(Principal.toText(message.caller), (share -(amount_ + 10)), totalShares);
          let transferResult = await CKBTC.icrc1_transfer({
            amount = amount_;
            fee = ?0;
            created_at_time = null;
            from_subaccount = null;
            to = { owner = message.caller; subaccount = null };
            memo = null;
          });
          var res = 0;
          switch (transferResult) {
            case (#Ok(number)) {

              return #success(number);
            };
            case (#Err(msg)) { res := 0 };
          };
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

  /*public query (message) func getMinerP() : async Text {

    var miner_id : Nat = 0;
    let emptyMiner = {
      id = 0;
      walletAddress = siteAdmin;
      var username = "<empty>";
      hashrate = 0;
    };
    let miner_ = minerHash.get(Principal.toText(message.caller));
    switch (miner_) {
      case (?m) {
        return "miner found";
      };
      case (null) {
        "Null";
      };
    };
  }; */

  public query (message) func fetchUserByPrincipal(p : Principal) : async () {

  };

  public query (message) func fetchUserById(p : Nat) : async () {

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

  //@DEV- CORE FUNCTIONS TO CALCULATE 24 HOUR HASHRATE REWARD AND DISTRIBUTE IT PROPORTIONALLLY TO ALL MINERS
  // public shared(message) func routine24() : async Text {
  //"https://btc.lokamining.com:8443/v1/transaction/earnings"
  private func routine24() : async Text {
    "";
  };

  public shared (message) func routine24Force() : async Text {
    "";
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
