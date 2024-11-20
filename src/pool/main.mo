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
import Prim "mo:prim";
import { setTimer; cancelTimer; recurringTimer } = "mo:base/Timer";

import T "types";
//import Minter "canister:ckbtc_minter";
import CKBTC "canister:ckbtc_prod"; //PROD
import DEFI "canister:defi";
//import Minter "ic:mqygn-kiaaa-aaaar-qaadq-cai";
//import CKBTC "canister:lbtc"; //DEV
//import LBTC "canister:lbtc";

shared ({ caller = owner }) actor class Miner({
  admin : Principal;
}) = this {
  //indexes
  //private stable var jwalletVault = "rg2ah-xl6x4-z6svw-bdxfv-klmal-cwfel-cfgzg-eoi6q-nszv5-7z5hg-sqe"; //DEV
  private stable var jwalletVault = "43hyn-pv646-27kl3-hhrll-wbdtc-k4idi-7mbyz-uvwxj-hgktq-topls-rae"; //PROD
  private var siteAdmin : Principal = admin;

  private stable var totalBalance = 0;
  private stable var totalWithdrawn = 0;

  //vautls
  stable var lokaCKBTCVault : Principal = admin;
  private stable var minerCKBTCVault : Principal = admin;
  //stables
  private stable var minersIndex = 0;
  private stable var transactionIndex = 0;
  private stable var pause = false : Bool;
  private stable var totalHashrate = 0;
  stable var lastF2poolCheck : Int = 0;
  private stable var distributionIndex = 0;
  private stable var errorIndex = 0;
  private stable var timeStarted = false;
  stable var distributionHistoryList : [{ time : Int; data : Text }] = [];
  private stable var withdrawalIndex = 0;
  //buffers and hashmaps
  var minerStatus = Buffer.Buffer<T.MinerStatus>(0);
  var miners = Buffer.Buffer<T.Miner>(0);
  var transactions = Buffer.Buffer<T.TransactionHistory>(0);

  private var minerHash = HashMap.HashMap<Text, T.Miner>(0, Text.equal, Text.hash);
  private var errorHash = HashMap.HashMap<Text, T.ErrorLog>(0, Text.equal, Text.hash);
  stable var errorHash_ : [(Text, T.ErrorLog)] = [];
  private var withdrawalHash = HashMap.HashMap<Text, [(Text, T.WithdrawalHistory)]>(0, Text.equal, Text.hash);
  stable var withdrawalHash_ : [(Text, [(Text, T.WithdrawalHistory)])] = [];
  private var allWithdrawalHash = HashMap.HashMap<Text, T.WithdrawalHistory>(0, Text.equal, Text.hash);
  private var allSuccessfulWithdrawalHash = HashMap.HashMap<Text, T.WithdrawalHistory>(0, Text.equal, Text.hash);
  stable var allWithdrawalHash_ : [(Text, T.WithdrawalHistory)] = [];
  stable var allSuccessfulWithdrawalHash_ : [(Text, T.WithdrawalHistory)] = [];
  private var failedWithdrawalHash = HashMap.HashMap<Text, T.WithdrawalHistory>(0, Text.equal, Text.hash);
  stable var failedWithdrawalHash_ : [(Text, T.WithdrawalHistory)] = [];
  private var revenueShareHash = HashMap.HashMap<Text, [(Text, T.RevenueShare)]>(0, Text.equal, Text.hash);
  private var receivedRevenueShareHash = HashMap.HashMap<Text, [(Text, T.RevenueShare)]>(0, Text.equal, Text.hash);
  private stable var receivedRevenueShareHash_ : [(Text, [(Text, T.RevenueShare)])] = [];

  private stable var revenueShareHash_ : [(Text, [(Text, T.RevenueShare)])] = [];

  private var userErrorHash = HashMap.HashMap<Text, [Text]>(0, Text.equal, Text.hash);
  stable var userErrorHash_ : [(Text, [Text])] = [];
  private var jwalletId = HashMap.HashMap<Text, Text>(0, Text.equal, Text.hash);
  private var minerStatusAndRewardHash = HashMap.HashMap<Text, T.MinerStatus>(0, Text.equal, Text.hash);
  private var usernameHash = HashMap.HashMap<Text, Nat>(0, Text.equal, Text.hash);
  private var revenueHash = HashMap.HashMap<Text, [T.DistributionHistory]>(0, Text.equal, Text.hash);
  private var distributionHistoryByTimeStamp = HashMap.HashMap<Text, T.Distribution>(0, Text.equal, Text.hash);
  private var distributionTimestampById = HashMap.HashMap<Text, Text>(0, Text.equal, Text.hash);

  //keys
  stable var f2poolKey : Text = "gxq33xia5tdocncubl0ivy91aetpiqm514wm6z77emrruwlg0l1d7lnrvctr4f5h";
  private var dappsKey = "0xSet";

  //upgrade temp params
  stable var minerStatus_ : [T.MinerStatus] = []; // for upgrade
  stable var miners_ : [T.Miner] = []; // for upgrade
  stable var transactions_ : [T.TransactionHistory] = [];
  stable var minerHash_ : [(Text, T.Miner)] = [];
  stable var minerStatusAndRewardHash_ : [(Text, T.MinerStatus)] = [];
  stable var usernameHash_ : [(Text, Nat)] = [];
  stable var distributionHistoryByTimeStamp_ : [(Text, T.Distribution)] = [];
  stable var distributionTimestampById_ : [(Text, Text)] = [];
  stable var revenueHash_ : [(Text, [T.DistributionHistory])] = [];
  stable var jwalletId_ : [(Text, Text)] = [];
  stable var schedulerId = 0;
  stable var nextTimeStamp : Int = 0;
  stable var schedulerSecondsInterval = 10;
  stable var counter = 0;

  system func preupgrade() {
    miners_ := Buffer.toArray<T.Miner>(miners);
    minerStatus_ := Buffer.toArray<T.MinerStatus>(minerStatus);
    transactions_ := Buffer.toArray<T.TransactionHistory>(transactions);

    minerHash_ := Iter.toArray(minerHash.entries());
    revenueShareHash_ := Iter.toArray(revenueShareHash.entries());
    receivedRevenueShareHash_ := Iter.toArray(receivedRevenueShareHash.entries());
    withdrawalHash_ := Iter.toArray(withdrawalHash.entries());
    allWithdrawalHash_ := Iter.toArray(allWithdrawalHash.entries());
    allSuccessfulWithdrawalHash_ := Iter.toArray(allSuccessfulWithdrawalHash.entries());
    failedWithdrawalHash_ := Iter.toArray(failedWithdrawalHash.entries());
    usernameHash_ := Iter.toArray(usernameHash.entries());
    revenueHash_ := Iter.toArray(revenueHash.entries());

    minerStatusAndRewardHash_ := Iter.toArray(minerStatusAndRewardHash.entries());
    jwalletId_ := Iter.toArray(jwalletId.entries());

    distributionHistoryByTimeStamp_ := Iter.toArray(distributionHistoryByTimeStamp.entries());
    distributionTimestampById_ := Iter.toArray(distributionTimestampById.entries());

    errorHash_ := Iter.toArray(errorHash.entries());
    userErrorHash_ := Iter.toArray(userErrorHash.entries());
  };

  system func postupgrade() {
    miners := Buffer.fromArray<T.Miner>(miners_);
    minerStatus := Buffer.fromArray<(T.MinerStatus)>(minerStatus_);
    transactions := Buffer.fromArray<T.TransactionHistory>(transactions_);

    revenueShareHash := HashMap.fromIter<Text, [(Text, T.RevenueShare)]>(revenueShareHash_.vals(), 1, Text.equal, Text.hash);
    receivedRevenueShareHash := HashMap.fromIter<Text, [(Text, T.RevenueShare)]>(receivedRevenueShareHash_.vals(), 1, Text.equal, Text.hash);

    withdrawalHash := HashMap.fromIter<Text, [(Text, T.WithdrawalHistory)]>(withdrawalHash_.vals(), 1, Text.equal, Text.hash);
    allWithdrawalHash := HashMap.fromIter<Text, T.WithdrawalHistory>(allWithdrawalHash_.vals(), 1, Text.equal, Text.hash);
    allSuccessfulWithdrawalHash := HashMap.fromIter<Text, T.WithdrawalHistory>(allSuccessfulWithdrawalHash_.vals(), 1, Text.equal, Text.hash);
    failedWithdrawalHash := HashMap.fromIter<Text, T.WithdrawalHistory>(failedWithdrawalHash_.vals(), 1, Text.equal, Text.hash);

    minerHash := HashMap.fromIter<Text, T.Miner>(minerHash_.vals(), 1, Text.equal, Text.hash);
    usernameHash := HashMap.fromIter<Text, Nat>(usernameHash_.vals(), 1, Text.equal, Text.hash);
    revenueHash := HashMap.fromIter<Text, [T.DistributionHistory]>(revenueHash_.vals(), 1, Text.equal, Text.hash);

    minerStatusAndRewardHash := HashMap.fromIter<Text, T.MinerStatus>(minerStatusAndRewardHash_.vals(), 1, Text.equal, Text.hash);
    jwalletId := HashMap.fromIter<Text, Text>(jwalletId_.vals(), 1, Text.equal, Text.hash);

    distributionHistoryByTimeStamp := HashMap.fromIter<Text, T.Distribution>(distributionHistoryByTimeStamp_.vals(), 1, Text.equal, Text.hash);
    distributionTimestampById := HashMap.fromIter<Text, Text>(distributionTimestampById_.vals(), 1, Text.equal, Text.hash);

    userErrorHash := HashMap.fromIter<Text, [Text]>(userErrorHash_.vals(), 1, Text.equal, Text.hash);
    errorHash := HashMap.fromIter<Text, T.ErrorLog>(errorHash_.vals(), 1, Text.equal, Text.hash);

    distributionStatus := "none";
    //let sched = await initScheduler();
  };

  public shared (message) func getCurrentScheduler() : async Nat {
    return schedulerId;
  };

  public shared (message) func logError(errorMessage : Text, username : Text) : async () {
    // Verify that the caller is authorized
    assert (_isVerified(message.caller, username));

    // Create an error log entry
    let currentTime = now() / 1000000;
    let err : T.ErrorLog = {
      id = errorIndex;
      time = currentTime;
      error = errorMessage;
      wallet = Principal.toText(message.caller);
      time_text = Int.toText(currentTime);
      username = username;
    };

    // Update the user error hash with the new error index
    let callerText = Principal.toText(message.caller);

    switch (userErrorHash.get(callerText)) {
      case (?errData) {
        let newData = Array.append<Text>(errData, [Nat.toText(errorIndex)]);
        userErrorHash.put(callerText, newData);
      };
      case (null) {
        userErrorHash.put(callerText, [Nat.toText(errorIndex)]);
      };
    };

    // Store the error log entry in the error hash
    errorHash.put(Nat.toText(errorIndex), err);

    // Increment the error index for the next error log entry
    errorIndex += 1;
  };

  public shared (message) func getICPTimeString() : async Text {
    Debug.print("getting next timestamp");

    let tmn_ = now() / 1000000;
    let url = "https://api.lokamining.com/timeFromStamp?timestamp=" #Int.toText(tmn_);

    let decoded_text = await send_http(url);
    Debug.print(decoded_text);
    return decoded_text;
  };

  public shared (message) func getNext() : async Int {
    assert (_isAdmin(message.caller));
    nextTimeStamp;
    //return 0;

  };

  public shared (message) func compareNow() : async Bool {
    assert (_isAdmin(message.caller));
    Debug.print("getting next timestamp");
    let tmn_ = now() / 1000000;
    let url = "https://api.lokamining.com/nextTimeStamp?timestamp=" #Int.toText(tmn_);

    let decoded_text = await send_http(url);
    Debug.print(decoded_text);
    return tmn_ > textToNat(decoded_text);
    //return 0;

  };

  public shared (message) func getStamp() : async Int {
    assert (_isAdmin(message.caller));
    Debug.print("getting next timestamp");
    let tmn_ = now() / 1000000;

    return tmn_;
    //return 0;

  };

  public shared (message) func getShareList() : async [(Text, [(Text, T.RevenueShare)])] {
    revenueShareHash_ := Iter.toArray(revenueShareHash.entries());
    return revenueShareHash_;
  };

  public shared (message) func getReceivedShareList() : async [(Text, [(Text, T.RevenueShare)])] {
    revenueShareHash_ := Iter.toArray(receivedRevenueShareHash.entries());
    return revenueShareHash_;
  };

  public query (message) func initialDistributionHour() : async Int {
    return nextTimeStamp;
  };
  //function to check scheduler / scheduler
  //returns counter+10 each 10 seconds when waiting for night time, and only adds +1 when already active
  public query (message) func getCounter() : async Nat {
    return counter;
  };

  /*public shared (message) func getTimeStamp(tm_ : Int) : async Nat {
    Debug.print("getting next timestamp");
    let nn = tm_ / 1000000;
    //return Int.toText(nn);
    let url = "https://api.lokamining.com/nextTimeStamp?timestamp=" #Int.toText(nn);

    let decoded_text = await send_http(url);
    Debug.print(decoded_text);
    //return "";
    return textToNat(decoded_text);
    //return url;

  }; */

  public shared (message) func stopScheduler(id_ : Nat) : async Bool {
    assert (_isAdmin(message.caller));
    let res = cancelTimer(id_);
    true;
  };

  /*public shared (message) func forceEx() : async () {
    nextTimeStamp := 1;
  }; */

  public shared (message) func init(fetchNewTime : Bool) : async Nat {
    assert (_isAdmin(message.caller));
    let t_ = now() / 1000000;
    await initScheduler(t_, fetchNewTime);
  };

  private stable var distributionStatus : Text = "none";

  public shared (message) func migrateJwallet() : async [(Text, Text)] {
    assert (_isAdmin(message.caller));
    let LokaMiner = actor ("rfrec-ciaaa-aaaam-ab4zq-cai") : actor {
      gwa : () -> async [(Text, Text)];
    };

    try {
      let result = await LokaMiner.gwa(); //"(record {subaccount=null;})"
      jwalletId_ := result;
      jwalletId := HashMap.fromIter<Text, Text>(jwalletId_.vals(), 1, Text.equal, Text.hash);

    } catch e {

    };
    return jwalletId_;
  };
  private stable var enableDist_ = true;

  public shared (message) func enableDistribution(enable : Bool) : async Bool {
    assert (_isAdmin(message.caller));
    enableDist_ := enable;
    enableDist_;
  };

  func reattempt<system>() : async Nat {
    cancelTimer(schedulerId);
    //let currentTimeStamp_ = t_;
    counter := 700;
    //nextTimeStamp := 0;
    //nextTimeStamp := await getNextTimeStamp(currentTimeStamp_);
    //Debug.print("stamp " #Int.toText(nextTimeStamp));
    if (nextTimeStamp == 0) return 0;

    schedulerId := recurringTimer(
      #seconds(900),
      func() : async () {
        if (counter < 800) { counter += 10 } else { counter := 700 };
        let time_ = now() / 1000000;
        if (time_ >= nextTimeStamp) {
          //counter := 200;
          //if (distributionStatus != "none") {

          let res = await routine24();
          //schedulerSecondsInterval := 24 * 60 * 60;
          if (res == "done") {
            let t_ = now() / 1000000;
            let i = await initScheduler(t_, true);
            //nextTimeStamp := time_ + (24 * 60 * 60 * 1000);
            distributionStatus := "none";
          };
          //};
          //cancelTimer(schedulerId);
          // schedulerId := scheduler();

        };
      },
    );
    schedulerId;
  };

  public shared (message) func setTS_(ts : Int) : async Bool {
    assert (_isAdmin(message.caller));
    nextTimeStamp := ts;
    true;
  };

  func initScheduler<system>(t_ : Int, fetchNewTime : Bool) : async Nat {
    cancelTimer(schedulerId);
    let currentTimeStamp_ = t_;
    counter := 0;
    if (fetchNewTime) {
      nextTimeStamp := 0;
      nextTimeStamp := await getNextTimeStamp(currentTimeStamp_);
      Debug.print("stamp " #Int.toText(nextTimeStamp));
    };
    if (nextTimeStamp == 0) return 0;
    schedulerId := recurringTimer(
      #seconds(10),
      func() : async () {
        if (counter < 100) { counter += 10 } else { counter := 0 };
        let time_ = now() / 1000000;
        if (time_ >= nextTimeStamp) {
          //counter := 200;
          //if (distributionStatus != "none") {
          if (enableDist_) {
            let res = await routine24();
            //schedulerSecondsInterval := 24 * 60 * 60;
            if (res == "done") {

              nextTimeStamp := nextTimeStamp + (24 * 60 * 60 * 1000);
              distributionStatus := "none";
            };
          };
          //};
          //cancelTimer(schedulerId);
          // schedulerId := scheduler();

        };
      },
    );
    schedulerId;
  };

  func scheduler<system>() : Nat {
    schedulerId := recurringTimer(
      // #seconds(24 * 60 * 60),
      #seconds(24 * 60 * 60),
      func() : async () {
        if (counter < 300) { counter += 1 } else { counter := 0 };
        let res = await routine24();
      },
    );
    schedulerId;
  };

  func getNextTimeStamp(tm_ : Int) : async Nat {
    Debug.print("getting next timestamp");
    let tmn_ = tm_;
    let url = "https://api.lokamining.com/nextTimeStamp?timestamp=" #Int.toText(tmn_);
    try {
      let decoded_text = await send_http(url);
      Debug.print(decoded_text);
      return textToNat(decoded_text);
    } catch (e) {
      return 0;
    };

    //return 0;

  };

  public shared (message) func clearData() : async () {
    assert (_isAdmin(message.caller));
    revenueShareHash := HashMap.HashMap<Text, [(Text, T.RevenueShare)]>(0, Text.equal, Text.hash);
    revenueShareHash_ := [];
    minerStatus := Buffer.Buffer<T.MinerStatus>(0);
    miners := Buffer.Buffer<T.Miner>(0);
    transactions := Buffer.Buffer<T.TransactionHistory>(0);
    minerHash := HashMap.HashMap<Text, T.Miner>(0, Text.equal, Text.hash);
    minerStatusAndRewardHash := HashMap.HashMap<Text, T.MinerStatus>(0, Text.equal, Text.hash);
    usernameHash := HashMap.HashMap<Text, Nat>(0, Text.equal, Text.hash);
    revenueHash := HashMap.HashMap<Text, [T.DistributionHistory]>(0, Text.equal, Text.hash);
    distributionHistoryByTimeStamp := HashMap.HashMap<Text, T.Distribution>(0, Text.equal, Text.hash);
    distributionTimestampById := HashMap.HashMap<Text, Text>(0, Text.equal, Text.hash);
    distributionIndex := 0;

    distributionHistoryList := [];

    minerStatus_ := []; // for upgrade
    miners_ := []; // for upgrade
    transactions_ := [];
    minerHash_ := [];
    minerStatusAndRewardHash_ := [];
    usernameHash_ := [];

    totalBalance := 0;
    minersIndex := 0;
    totalWithdrawn := 0;
    lastF2poolCheck := 0;
    transactionIndex := 0;
    timeStarted := false;

    schedulerId := 0;
    nextTimeStamp := 0;
    schedulerSecondsInterval := 10;
    counter := 0;
  };

  public shared (message) func clearDistribution() : async () {
    assert (_isAdmin(message.caller));
    revenueHash := HashMap.HashMap<Text, [T.DistributionHistory]>(0, Text.equal, Text.hash);
    distributionHistoryByTimeStamp := HashMap.HashMap<Text, T.Distribution>(0, Text.equal, Text.hash);
    distributionTimestampById := HashMap.HashMap<Text, Text>(0, Text.equal, Text.hash);
    distributionIndex := 0;
    //revenueShareHash := HashMap.HashMap<Text, [(Text, T.RevenueShare)]>(0, Text.equal, Text.hash);
    //revenueShareHash_ := [];
    distributionHistoryList := [];

  };

  func _isAdmin(p : Principal) : Bool {
    return (p == siteAdmin or p == Principal.fromText("o4k35-i6lb3-mfi6a-6mwzo-iuxj6-qci6k-l7whg-3ntvl-2vcum-dq7ac-2qe") or p == Principal.fromText("2ro3m-uoe3m-ncjvu-4wjbl-7empr-mbh6d-s5emx-awswx-b2hxg-vvjcj-mae"));
  };

  func _isApp(key : Text) : Bool {
    return (key == dappsKey);
  };

  func _isNotPaused() : Bool {
    if (pause) return false;
    true;
  };

  public query func isNotPaused() : async Bool {
    if (pause) return false;
    true;
  };

  public shared (message) func setCKBTCVault(vault_ : Principal) : async Principal {
    assert (_isAdmin(message.caller));
    lokaCKBTCVault := vault_;
    vault_;
  };

  public shared (message) func setJwalletVault(vault_ : Text) : async Text {
    assert (_isAdmin(message.caller));
    jwalletVault := vault_;
    vault_;
  };

  public shared (message) func setMinerCKBTCVault(vault_ : Principal) : async Principal {
    assert (_isAdmin(message.caller));
    minerCKBTCVault := vault_;
    vault_;
  };

  public query (message) func getCurrentIndex() : async Nat {
    minersIndex;
  };

  public shared (message) func pauseCanister(pause_ : Bool) : async Bool {
    assert (_isAdmin(message.caller));
    pause := pause_;
    pause_;
  };

  func _isNotRegistered(p : Principal, username_ : Text) : Bool {
    var notReg = true;
    let miner_ = minerHash.get(Principal.toText(p));

    switch (miner_) {
      case (?m) {
        notReg := false;
      };
      case (null) {

      };
    };

    let username = usernameHash.get(username_);

    switch (username) {
      case (?m) {
        notReg := false;
      };
      case (null) {

      };
    };
    return notReg;
  };

  func _isVerified(p : Principal, username_ : Text) : Bool {
    switch (minerHash.get(Principal.toText(p))) {
      case (?x) {
        let stats_ = minerStatus.get(x.id);
        // if(stats_.ve)
        return stats_.verified;
      };
      case (null) { return false };
    };

    if (_isNotRegistered(p, username_)) return false;

    let res_ = getMiner(p);
    switch (res_) {
      case (#none) {
        return false;
      };
      case (#ok(m)) {
        let minerStatus_ = minerStatus.get(m.id);
        //if(m.)
        return minerStatus_.verified;
      };
    };
  };

  func _isUsernameVerified(username_ : Text) : Bool {
    switch (usernameHash.get(username_)) {
      case (?x) {
        let stats_ = minerStatus.get(x);
        // if(stats_.ve)
        return stats_.verified;
      };
      case (null) { return false };
    };
  };

  func _isAddressVerified(p : Principal) : Bool {
    //let miner_ = getMiner(p);
    let res_ = getMiner(p);
    switch (res_) {
      case (#none) {
        return false;
      };
      case (#ok(m)) {
        let minerStatus_ = minerStatus.get(m.id);
        //if(m.)
        return minerStatus_.verified;
      };
    };
  };

  func _isRegistered(p : Principal, username_ : Text) : Bool {
    let miner_ = minerHash.get(Principal.toText(p));

    switch (miner_) {
      case (?m) {
        return true;
      };
      case (null) {
        return false;
      };
    };
  };

  // The `isVerified` function is a public query function that checks if a miner associated with a given principal is verified. Here's a step-by-step description of how the function works:
  // 1. **Function Signature**:
  //    - The function is declared as `public query`, meaning it can be called by external actors and does not modify the state.
  //    - It takes a single parameter `p` of type `Principal`, which represents the principal of the miner.
  //    - The function returns a `Bool` indicating whether the miner is verified (`true`) or not (`false`).
  // 2. **Get Miner**:
  //    - The function calls `getMiner(p)` to retrieve the miner associated with the given principal.
  //    - The result is stored in the variable `res_`.
  // 3. **Check Miner Existence**:
  //    - The function uses a `switch` statement to check if the miner exists:
  //      - If the result is `#none`, it means the miner does not exist, and the function returns `false`.
  //      - If the result is `#ok(m)`, it means the miner exists, and the miner's data is stored in the variable `m`.
  // 4. **Get Miner Status**:
  //    - The function retrieves the miner's status using `minerStatusAndRewardHash.get(Nat.toText(m.id))`.
  // 5. **Check Verification Status**:
  //    - The function uses a `switch` statement to check if the miner's status exists:
  //      - If the result is `?m`, it means the miner's status exists, and the function returns the `verified` field of the miner's status.
  //      - If the result is `null`, it means the miner's status does not exist, and the function returns `false`.
  // In summary, the `isVerified` function checks if a miner associated with a given principal is verified by retrieving the miner's status and returning the `verified` field. If the miner or the miner's status does not exist, the function returns `false`.
  //
  public query (message) func isVerified(p : Principal) : async Bool {
    let res_ = getMiner(p);

    switch (res_) {
      case (#none) {
        return false;
      };
      case (#ok(m)) {
        switch (minerStatusAndRewardHash.get(Nat.toText(m.id))) {
          case (?m) {
            return m.verified;
          };
          case (null) {
            return false;
          };
        };
      };
    };

  };

  func _isNotVerified(p : Principal, username_ : Text) : Bool {
    if (_isVerified(p, username_)) return false;
    true;
  };

  public shared (message) func setDappsKey(key : Text) : async Text {
    assert (_isAdmin(message.caller));
    dappsKey := key;
    key;
  };

  public shared (message) func setF2PoolKey(key : Text) : async Text {
    assert (_isAdmin(message.caller));
    f2poolKey := key;
    key;
  };

  // The `addMiner` function is a private asynchronous function that adds a new miner to the system. Here's a step-by-step description of how the function works:
  // 1. **Function Signature**:
  //    - The function is declared as `private` and `async`, meaning it can only be called within the same module and performs asynchronous operations.
  //    - It takes three parameters:
  //      - `requestUsername`: The username of the new miner (as `Text`).
  //      - `hashrate_`: The hashrate of the new miner (as `Nat`).
  //      - `wallet`: The wallet address of the new miner (as `Principal`).
  //    - The function returns a `Bool` indicating the success (`true`) or failure (`false`) of adding the miner.
  // 2. **Ensure Wallet is Not Registered and System is Not Paused**:
  //    - The function ensures that the wallet is not already registered by calling `assert(_isNotRegistered(wallet, requestUsername))`.
  //    - It ensures that the system is not paused by calling `assert(_isNotPaused())`.
  // 3. **Get Miner**:
  //    - The function retrieves the miner associated with the wallet by calling `getMiner(wallet)` and stores it in the variable `miner_`.
  // 4. **Calculate Hashrate**:
  //    - The function calculates the hashrate by multiplying `hashrate_` by `1000000000000` and stores it in the variable `hash_`.
  // 5. **Check Again if Wallet is Not Registered**:
  //    - The function checks again if the wallet is not registered by calling `_isNotRegistered(wallet, requestUsername)`.
  // 6. **Create New Miner Entry**:
  //    - If the wallet is not registered, the function creates a new miner entry with the following details:
  //      - `id`: The current value of `minersIndex`.
  //      - `walletAddress`: The wallet address of the miner.
  //      - `username`: The username of the miner.
  //      - `hashrate`: The calculated hashrate.
  // 7. **Store Miner Information**:
  //    - The function stores the miner information in the respective hashes:
  //      - `minerHash`: Maps the wallet address to the miner.
  //      - `usernameHash`: Maps the username to the miner's ID.
  //      - `miners`: Adds the miner to the list of miners.
  // 8. **Log Miner Addition**:
  //    - The function logs the miner addition by calling `logMiner(minersIndex, requestUsername, Nat.toText(hashrate_), Principal.toText(wallet))`.
  // 9. **Create New Miner Status Entry**:
  //    - The function creates a new miner status entry with the following details:
  //      - `id`: The current value of `minersIndex`.
  //      - `verified`: Set to `true`.
  //      - `balance`: Set to `0`.
  //      - `totalWithdrawn`: Set to `0`.
  //      - `walletAddress`: An empty list.
  //      - `bankAddress`: An empty list.
  //      - `transactions`: An empty list.
  //      - `totalSharedRevenue`: Set to `0`.
  // 10. **Store Miner Status Information**:
  //     - The function stores the miner status information in the respective hashes:
  //       - `minerStatusAndRewardHash`: Maps the miner's ID to the miner status.
  //       - `minerStatus`: Adds the miner status to the list of miner statuses.
  // 11. **Update Indexes and Total Hashrate**:
  //     - The function increments the `minersIndex` by 1.
  //     - It adds the calculated hashrate to `totalHashrate`.
  // 12. **Return Success**:
  //     - The function returns `true` to indicate that the miner was successfully added.
  // 13. **Return Failure**:
  //     - If the wallet is already registered, the function returns `false`.
  // In summary, the `addMiner` function adds a new miner to the system by creating and storing the miner's information and status, logging the addition, and updating the relevant indexes and total hashrate.
  // It ensures that the wallet is not already registered and the system is not paused before proceeding. If the miner is successfully added, it returns `true`; otherwise, it returns `false`.
  //
  private func addMiner(requestUsername : Text, hashrate_ : Nat, wallet : Principal) : async Bool {
    // Ensure the wallet is not already registered and the system is not paused
    assert (_isNotRegistered(wallet, requestUsername));
    assert (_isNotPaused());

    let miner_ = getMiner(wallet);
    let hash_ = hashrate_ * 1000000000000;

    // Check again if the wallet is not registered
    if (_isNotRegistered(wallet, requestUsername)) {
      // Create a new miner entry
      let miner_ : T.Miner = {
        id = minersIndex;
        walletAddress = wallet;
        var username = requestUsername;
        hashrate = hash_;
      };

      // Store the miner information in the respective hashes
      minerHash.put(Principal.toText(wallet), miner_);
      usernameHash.put(requestUsername, minersIndex);
      miners.add(miner_);

      Debug.print("miner added");

      // Log the miner addition
      logMiner(minersIndex, requestUsername, Nat.toText(hashrate_), Principal.toText(wallet));

      // Create a new miner status entry
      let minerStatus_ : T.MinerStatus = {
        id = minersIndex;
        var verified = true;
        var balance = 0;
        var totalWithdrawn = 0;
        var walletAddress = [];
        var bankAddress = [];
        var transactions = [];
        var totalSharedRevenue = 0;
      };

      // Store the miner status information in the respective hashes
      minerStatusAndRewardHash.put(Nat.toText(minersIndex), minerStatus_);
      minerStatus.add(minerStatus_);

      // Update the indexes and total hashrate
      minersIndex += 1;
      totalHashrate += hash_;
      true;
    } else {
      // If the miner is already registered, return false
      false;
    };
  };

  private stable var dcr = 10;
  private stable var can = true;

  public shared (message) func access() : async Bool {

    if (can == true) can := false;
    return can;
  };

  public query func geta() : async Nat {
    dcr;
  };

  public shared (message) func toggleRoutine(b_ : Bool) : async Bool {
    timeStarted := b_;
    timeStarted;
  };

  // The `getBalance` function is a public query function that retrieves the current balance, total withdrawn, total balance, and claimable balances for all miners.
  // Here's a step-by-step description of how the function works:
  // 1. **Function Signature**:
  //    - The function is declared as `public query`, meaning it can be called by external actors and does not modify the state.
  //    - It takes no parameters.
  //    - The function returns an object with four fields:
  //      - `currentBalance`: The current total balance of all miners.
  //      - `withdrawn`: The total amount withdrawn by all miners.
  //      - `total`: The sum of the current balance and the total withdrawn.
  //      - `claimables`: The total claimable balance of all miners.
  // 2. **Retrieve User List**:
  //    - The function retrieves all entries from `usernameHash` and converts them to an array `ls`.
  // 3. **Initialize Total Revenue**:
  //    - The function initializes a variable `totalRev` to 0, which will be used to accumulate the total claimable balance.
  // 4. **Loop Through Users**:
  //    - The function iterates over each user in `ls`.
  // 5. **Get Miner and Status**:
  //    - For each user, the function retrieves the miner's data using `miners.get(usr.1)` and stores it in the variable `miner_`.
  //    - It retrieves the miner's status using `minerStatus.get(miner_.id)` and stores it in the variable `minerStat_`.
  // 6. **Accumulate Claimable Balance**:
  //    - The function adds the miner's balance (`minerStat_.balance`) to `totalRev`.
  // 7. **Return Balances**:
  //    - The function returns an object with the following fields:
  //      - `currentBalance`: The value of `totalBalance`.
  //      - `withdrawn`: The value of `totalWithdrawn`.
  //      - `total`: The sum of `totalWithdrawn` and `totalBalance`.
  //      - `claimables`: The accumulated total claimable balance (`totalRev`).
  // In summary, the `getBalance` function retrieves and returns the current balance, total withdrawn, total balance, and claimable balances for all miners. It iterates through the list of users, retrieves each miner's balance, and accumulates the claimable balances.
  // The function ensures that the data is returned in a structured format.
  //
  public query func getBalance() : async {
    currentBalance : Nat;
    withdrawn : Nat;
    total : Nat;
    claimables : Nat;
  } {
    var ls = Iter.toArray(usernameHash.entries());
    var totalRev = 0;
    for (usr in ls.vals()) {
      let miner_ = miners.get(usr.1);
      let minerStat_ = minerStatus.get(miner_.id);

      totalRev += minerStat_.balance;

    };

    return {
      currentBalance = totalBalance;
      withdrawn = totalWithdrawn;
      total = totalWithdrawn + totalBalance;
      claimables = totalRev;
    };
  };

  public query (message) func getDistributionList() : async [(Text, T.Distribution)] {
    //distributionHistoryList;
    assert (_isAdmin(message.caller));
    return Iter.toArray(distributionHistoryByTimeStamp.entries());
  };

  public query (message) func withdrawalList() : async [(Text, T.WithdrawalHistory)] {
    //distributionHistoryList;
    assert (_isAdmin(message.caller));
    return Iter.toArray(allWithdrawalHash.entries());
  };

  public query (message) func failedWithdrawalList() : async [(Text, T.WithdrawalHistory)] {
    //distributionHistoryList;
    assert (_isAdmin(message.caller));
    return Iter.toArray(failedWithdrawalHash.entries());
  };

  public shared (message) func getCKBTCBalance() : async Nat {
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

  public shared (message) func updateBalance() : async {
    #Ok : [UtxoStatus];
    #Err : UpdateBalanceError;
  } {
    assert (_isAdmin(message.caller));
    await updateCKBTCBalance();
  };

  func updateCKBTCBalance() : async {
    #Ok : [UtxoStatus];
    #Err : UpdateBalanceError;
  } {
    let Minter = actor ("mqygn-kiaaa-aaaar-qaadq-cai") : actor {
      update_balance : ({ subaccount : ?Nat }) -> async {
        #Ok : [UtxoStatus];
        #Err : UpdateBalanceError;
      };
    };
    let result = await Minter.update_balance({ subaccount = null }); //"(record {subaccount=null;})"
    return result;

  };

  //public shared(message) func getCKBTCMintAddress() : async Text {
  // var ckBTCBalance : Nat= (await CKBTC.icrc1_balance_of({owner=Principal.fromActor(this);subaccount=null}));
  //ckBTCBalance;
  //};

  // The `sendCKBTC` function is a public shared asynchronous function that transfers a specified amount of ckBTC to a given wallet. Here's a step-by-step description of how the function works:
  // 1. **Function Signature**:
  //    - The function is declared as `public shared (message)`, meaning it can be called by external actors.
  //    - It takes three parameters:
  //      - `wallet_`: The wallet address to which the ckBTC will be sent (as `Text`).
  //      - `subAccount`: The sub-account associated with the wallet (as `Text`).
  //      - `amount_`: The amount of ckBTC to be transferred (as `Nat`).
  //    - The function returns a `Bool` indicating the success (`true`) or failure (`false`) of the transfer.
  // 2. **Convert Wallet Address**:
  //    - The function converts the `wallet_` text to a `Principal` type using `Principal.fromText(wallet_)`.
  // 3. **Admin Check**:
  //    - The function ensures that the caller is an admin by calling `assert(_isAdmin(message.caller))`.
  // 4. **Amount Check**:
  //    - The function ensures that the amount to be transferred is greater than 0 by calling `assert(amount_ > 0)`.
  // 5. **Get Current ckBTC Balance**:
  //    - The function retrieves the current ckBTC balance of the actor using `CKBTC.icrc1_balance_of`.
  //    - The balance is stored in the variable `ckBTCBalance`.
  // 6. **Deduct Fixed Fee**:
  //    - The function deducts a fixed fee (e.g., 12 units) from the balance by subtracting 12 from `ckBTCBalance`.
  // 7. **Perform the Transfer**:
  //    - The function performs the transfer using `CKBTC.icrc1_transfer` with the following details:
  //      - `amount`: The amount of ckBTC to be transferred.
  //      - `fee`: An optional fee of 10 units.
  //      - `created_at_time`: Not set (null).
  //      - `from_subaccount`: Not set (null).
  //      - `to`: The destination wallet and sub-account.
  //      - `memo`: Not set (null).
  // 8. **Handle the Transfer Result**:
  //    - The function uses a `switch` statement to handle the result of the transfer:
  //      - If the transfer is successful (`#Ok(number)`), it returns `true`.
  //      - If the transfer fails (`#Err(msg)`), it sets `res` to 0.
  // 9. **Return Default Value**:
  //    - The function returns `true` by default (consider revising this logic).
  // In summary, the `sendCKBTC` function transfers a specified amount of ckBTC to a given wallet, ensuring that the caller is an admin and the amount is greater than 0. It retrieves the current ckBTC balance, deducts a fixed fee, performs the transfer, and handles the transfer result. The function returns `true` if the transfer is successful and `true` by default (consider revising this logic).
  //
  public shared (message) func sendCKBTC(wallet_ : Text, subAccount : Text, amount_ : Nat) : async Bool {
    let wallet : Principal = Principal.fromText(wallet_);

    // Ensure the caller is an admin
    assert (_isAdmin(message.caller));

    // Ensure amount is greater than 0
    assert (amount_ > 0);

    // Get the current ckBTC balance of the actor
    var ckBTCBalance : Nat = await CKBTC.icrc1_balance_of({
      owner = Principal.fromActor(this);
      subaccount = null;
    });

    // Deduct a fixed fee from the balance (e.g., 12 units)
    ckBTCBalance -= 12;

    // Perform the transfer
    let transferResult = await CKBTC.icrc1_transfer({
      amount = amount_;
      fee = ?10;
      created_at_time = null;
      from_subaccount = null;
      to = { owner = wallet; subaccount = null };
      memo = null;
    });

    // Handle the transfer result
    var res = 0;
    switch (transferResult) {
      case (#Ok(number)) {
        return true;
      };
      case (#Err(msg)) {
        res := 0;
      };
    };

    // Return true by default (consider revising this logic)
    true;
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

  public shared (message) func getJwalletId(type_ : Text, acc_ : Text) : async {
    #uuid : Text;
    #none : Text;
  } {
    if (_isAdmin(message.caller) == false) assert (_isAddressVerified(message.caller));
    switch (jwalletId.get(type_ #acc_)) {
      case (?j) {
        return #uuid(j);
      };
      case (null) {
        return #none("Account not found");
      };
    };
    return #none("Account not found");
  };

  public shared (message) func recordJwalletId(type_ : Text, acc_ : Text, uuid_ : Text) : async {
    #exist : Text;
    #ok;
  } {
    if (_isAdmin(message.caller) == false) assert (_isAddressVerified(message.caller));
    switch (jwalletId.get(type_ #acc_)) {
      case (?j) {

        return #exist(j);
      };
      case (null) {
        jwalletId.put(type_ #acc_, uuid_);
        return #ok;
      };
    };
    //return #ok("yo");
  };

  public shared (message) func getCKBTCMinter() : async Text {
    let Minter = actor ("mqygn-kiaaa-aaaar-qaadq-cai") : actor {
      get_btc_address : ({ subaccount : ?Nat }) -> async Text;
    };
    let result = await Minter.get_btc_address({ subaccount = null }); //"(record {subaccount=null;})"
    result;
  };

  //)

  // The `withdrawIDR` function is a public shared asynchronous function that handles the withdrawal of IDR (Indonesian Rupiah) for a miner. Here's a step-by-step description of how the function works:
  // 1. **Function Signature**:
  //    - The function is declared as `public shared (message)`, meaning it can be called by external actors.
  //    - It takes four parameters:
  //      - `quoteId_`: The quote ID associated with the withdrawal.
  //      - `amount_`: The amount of IDR to be withdrawn.
  //      - `bankID_`: The bank ID to which the IDR will be sent.
  //      - `memoParam_`: An array of `Nat8` representing the memo parameter.
  //    - The function returns a `T.TransferRes` indicating the result of the withdrawal.
  // 2. **Pause Check**:
  //    - The function ensures that the system is not paused by calling `assert(_isNotPaused())`.
  // 3. **Address Verification**:
  //    - The function ensures that the caller's address is verified by calling `assert(_isAddressVerified(message.caller))`.
  // 4. **Amount Check**:
  //    - The function ensures that the amount is greater than 10 by calling `assert(amount_ > 10)`.
  // 5. **Increment Withdrawal Index**:
  //    - The function increments the `withdrawalIndex` by 1.
  // 6. **Get Miner**:
  //    - The function calls `getMiner(message.caller)` to retrieve the miner associated with the caller.
  //    - The result is stored in the variable `res_`.
  // 7. **Check Miner Existence**:
  //    - The function uses a `switch` statement to check if the miner exists:
  //      - If the result is `#none`, it returns an error indicating that the miner is not found.
  //      - If the result is `#ok(m)`, it assigns the miner's ID to `id_` and the miner's username to `usernm`.
  // 8. **Encode Memo**:
  //    - The function encodes the memo using `Text.encodeUtf8` and stores it in the variable `memo_`.
  // 9. **Get Miner Status**:
  //    - The function retrieves the miner's status using `minerStatus.get(id_)` and stores it in the variable `minerStatus_`.
  // 10. **Check Sufficient Balance**:
  //     - The function checks if the miner has sufficient balance to cover the withdrawal amount plus a fee of 10 units.
  //     - If the balance is insufficient, it returns an error indicating the insufficient balance.
  // 11. **Convert Memo Parameter to Blob**:
  //     - The function converts the memo parameter to a `Blob` using `Blob.fromArray` and stores it in the variable `blob_`.
  // 12. **Define CKBTC Actor**:
  //     - The function defines an actor `CKBTC_` with the method `icrc1_transfer`.
  // 13. **Log Pre-Transfer Transaction**:
  //     - The function logs the pre-transfer transaction by calling `logTransaction`.
  // 14. **Update Balances and Total Withdrawn**:
  //     - The function updates the miner's balance, total withdrawn, and total shared revenue by subtracting the withdrawal amount plus the fee.
  //     - It also updates the global `totalBalance` and `totalWithdrawn`.
  // 15. **Update Miner Status and Reward Hash**:
  //     - The function updates the `minerStatusAndRewardHash` with the new miner status.
  // 16. **Create Withdrawal History Entry**:
  //     - The function creates a `T.WithdrawalHistory` record with the withdrawal details and stores it in the variable `wdh`.
  // 17. **Update Withdrawal Hash**:
  //     - The function updates the `withdrawalHash` and `allWithdrawalHash` with the new withdrawal history.
  // 18. **Perform Transfer**:
  //     - The function attempts to perform the transfer using the `CKBTC_.icrc1_transfer` method.
  //     - If an error occurs during the transfer, it reverts the balance updates, logs the failed transaction, and returns an error indicating the failure.
  // 19. **Handle Transfer Result**:
  //     - The function uses a `switch` statement to handle the result of the transfer:
  //       - If the transfer is successful (`#Ok(number)`), it logs the successful transaction, updates the `allSuccessfulWithdrawalHash`, and returns `#success(amount_)`.
  //       - If the transfer fails (`#Err(msg)`), it reverts the balance updates, logs the failed transaction, and returns an error with the error message.
  // In summary, the `withdrawIDR` function handles the withdrawal of IDR for a miner, ensuring that the system is not paused, the caller's address is verified, and the miner has sufficient balance. It logs the transaction, updates the relevant balances, performs the transfer, and handles various error cases. If the withdrawal is successful, it logs the transaction and returns the success result. If any errors occur, it reverts the balance updates and returns an error.
  //
  public shared (message) func withdrawIDR(
    quoteId_ : Text,
    amount_ : Nat,
    bankID_ : Text,
    memoParam_ : [Nat8],
  ) : async T.TransferRes {
    // Ensure the system is not paused
    assert (_isNotPaused());
    // Ensure the caller's address is verified
    assert (_isAddressVerified(message.caller));
    // Ensure the amount is greater than 10
    assert (amount_ > 10);

    // Increment the withdrawal index
    withdrawalIndex += 1;
    let amountNat_ : Nat = amount_;
    let res_ = getMiner(message.caller);
    var id_ = 0;
    var usernm = "";

    // Check if the miner exists
    switch (res_) {
      case (#none) {
        return #error("miner not found");
      };
      case (#ok(m)) {
        id_ := m.id;
        usernm := m.username;
      };
    };

    // Encode the memo
    var memo_ : Blob = Text.encodeUtf8(bankID_ # "." # quoteId_);
    var minerStatus_ : T.MinerStatus = minerStatus.get(id_);

    // Check if the miner has sufficient balance
    if ((minerStatus_.balance < (amount_ + 10)) == true) {
      return #error("insufficient balance");
    };

    let blob_ = Blob.fromArray(memoParam_);

    // Define the CKBTC actor
    let CKBTC_ = actor ("mxzaz-hqaaa-aaaar-qaada-cai") : actor {
      icrc1_transfer : (T.TransferArg) -> async T.Result;
    };

    var tme = now();

    // Log the transaction before transfer
    logTransaction(id_, "{\"action\":\"withdraw IDR\",\"receiver\":\"" # quoteId_ # "\"}", Nat.toText(amount_), "pre transfer", "{\"currency\":\"IDR\",\"bank\":\"" # bankID_ # "\"}", usernm, Principal.toText(message.caller));

    // Update balances and total withdrawn
    totalBalance -= (amount_ + 10);
    minerStatus_.balance -= (amount_ + 10);
    minerStatus_.totalWithdrawn += (amount_ + 10);
    var tsr = minerStatus_.totalSharedRevenue;

    // Update miner status and reward hash
    if (minerStatus_.totalSharedRevenue > 0) {
      if (minerStatus_.totalSharedRevenue > minerStatus_.balance) {
        //minerStatus_.totalSharedRevenue := minerStatus_.balance;
      };
    };

    totalWithdrawn += (amount_ + 10);
    switch (minerStatusAndRewardHash.get(Nat.toText(id_))) {
      case (?mStat) {
        minerStatusAndRewardHash.put(Nat.toText(id_), minerStatus_);
      };
      case (null) {};
    };

    // Create a withdrawal history entry
    var wdh : T.WithdrawalHistory = {
      id = withdrawalIndex;
      time = tme;
      action = "Withdraw IDR";
      amount = "pretransfer";
      txid = "pretransfer";
      currency = "IDR";
      username = usernm;
      wallet = Principal.toText(message.caller);
      jwalletId = quoteId_;
      bankId = bankID_;
      memo = ?blob_;
    };

    // Update withdrawal hash
    switch (withdrawalHash.get(Nat.toText(id_))) {
      case (?withdrawals) {
        var wd = HashMap.fromIter<Text, T.WithdrawalHistory>(withdrawals.vals(), 1, Text.equal, Text.hash);
        wd.put(Int.toText(tme), wdh);
        allWithdrawalHash.put(Int.toText(tme), wdh);
        withdrawalHash.put(Nat.toText(id_), Iter.toArray(wd.entries()));
      };
      case (null) {
        var wd = HashMap.HashMap<Text, T.WithdrawalHistory>(0, Text.equal, Text.hash);
        wd.put(Int.toText(tme), wdh);
        allWithdrawalHash.put(Int.toText(tme), wdh);
        withdrawalHash.put(Nat.toText(id_), Iter.toArray(wd.entries()));
      };
    };

    var transferResult : T.Result = #Ok(0);
    try {
      // Perform the transfer
      transferResult := await CKBTC_.icrc1_transfer({
        amount = amount_;
        fee = ?10;
        created_at_time = null;
        from_subaccount = null;
        to = { owner = Principal.fromText(jwalletVault); subaccount = null };
        memo = ?blob_;
      });
    } catch (error) {
      // Revert balances and total withdrawn in case of error
      minerStatus_.balance += (amount_ + 10);
      minerStatus_.totalWithdrawn -= (amount_ + 10);
      minerStatus_.totalSharedRevenue := tsr;
      totalWithdrawn -= (amount_ + 10);
      totalBalance += (amount_ + 10);
      switch (minerStatusAndRewardHash.get(Nat.toText(id_))) {
        case (?mStat) {
          minerStatusAndRewardHash.put(Nat.toText(id_), minerStatus_);
        };
        case (null) {};
      };

      // Log the failed transaction
      logTransaction(id_, "{\"action\":\"crashed withdraw IDR\",\"receiver\":\"" # quoteId_ # "\"}", Nat.toText(amount_), "pre transfer", "{\"currency\":\"IDR\",\"bank\":\"" # bankID_ # "\"}", usernm, Principal.toText(message.caller));

      return #error("ckBTC transfer process unexpectedly failed");
    };

    // Handle the transfer result
    switch (transferResult) {
      case (#Ok(number)) {
        // Create a successful withdrawal history entry
        var wdh : T.WithdrawalHistory = {
          id = withdrawalIndex;
          time = tme;
          action = "Withdraw IDR";
          amount = Nat.toText(amount_);
          txid = Int.toText(number);
          currency = "IDR";
          username = usernm;
          wallet = Principal.toText(message.caller);
          jwalletId = quoteId_;
          bankId = bankID_;
          memo = ?blob_;
        };

        // Update withdrawal hash with successful transaction
        switch (withdrawalHash.get(Nat.toText(id_))) {
          case (?withdrawals) {
            var wd = HashMap.fromIter<Text, T.WithdrawalHistory>(withdrawals.vals(), 1, Text.equal, Text.hash);
            wd.put(Int.toText(tme), wdh);
            allWithdrawalHash.put(Int.toText(tme), wdh);
            allSuccessfulWithdrawalHash.put(Int.toText(tme), wdh);
            withdrawalHash.put(Nat.toText(id_), Iter.toArray(wd.entries()));
          };
          case (null) {
            var wd = HashMap.HashMap<Text, T.WithdrawalHistory>(0, Text.equal, Text.hash);
            wd.put(Int.toText(tme), wdh);
            allWithdrawalHash.put(Int.toText(tme), wdh);
            allSuccessfulWithdrawalHash.put(Int.toText(tme), wdh);
            withdrawalHash.put(Nat.toText(id_), Iter.toArray(wd.entries()));
          };
        };

        // Log the successful transaction
        logTransaction(id_, "{\"action\":\"withdraw IDR\",\"receiver\":\"" # quoteId_ # "\"}", Nat.toText(amount_), Nat.toText(number), "{\"currency\":\"IDR\",\"bank\":\"" # bankID_ # "\"}", usernm, Principal.toText(message.caller));

        return #success(amount_);
      };
      case (#Err(msg)) {
        var tme = now() / 1000000;
        var errmsg = "";
        Debug.print("transfer error  ");
        switch (msg) {
          case (#BadFee(number)) {
            Debug.print("Bad Fee");
            errmsg := "Bad Fee";
          };
          case (#GenericError(number)) {
            Debug.print("err " # number.message);
            errmsg := "err " # number.message;
          };
          case (#InsufficientFunds(number)) {
            Debug.print("insufficient funds");
            errmsg := "insufficient funds";
          };
          case _ {
            Debug.print("err");
            errmsg := "other";
          };
        };

        // Create a failed withdrawal history entry
        var wdh : T.WithdrawalHistory = {
          id = withdrawalIndex;
          time = tme;
          action = "FAILED : Withdraw IDR";
          amount = Nat.toText(amount_);
          txid = errmsg;
          currency = "IDR";
          username = usernm;
          wallet = Principal.toText(message.caller);
          jwalletId = quoteId_;
          bankId = bankID_;
          memo = ?blob_;
        };

        // Revert balances and total withdrawn in case of error
        minerStatus_.balance += (amount_ + 10);
        minerStatus_.totalWithdrawn -= (amount_ + 10);
        minerStatus_.totalSharedRevenue := tsr;
        totalWithdrawn -= (amount_ + 10);
        totalBalance += (amount_ + 10);
        switch (minerStatusAndRewardHash.get(Nat.toText(id_))) {
          case (?mStat) {
            minerStatusAndRewardHash.put(Nat.toText(id_), minerStatus_);
          };
          case (null) {};
        };

        // Update withdrawal hash with failed transaction
        allWithdrawalHash.put(Int.toText(tme), wdh);
        failedWithdrawalHash.put(Int.toText(tme), wdh);

        return #error("ckbtc offramp transfer failed: " # errmsg);
      };
    };

    return #error("error");
  };

  public shared (message) func getErrorLogs() : async [(Text, T.ErrorLog)] {
    assert (_isAdmin(message.caller));
    return Iter.toArray(errorHash.entries());
  };

  public shared (message) func getAllWithdrawals() : async [(Text, T.WithdrawalHistory)] {
    assert (_isAdmin(message.caller));
    return Iter.toArray(allWithdrawalHash.entries());
  };

  // The `getTotalRevenue` function is a public shared asynchronous function that calculates and returns the total revenue of a specific miner, excluding adjustments. Here's a step-by-step description of how the function works:
  // 1. **Function Signature**:
  //    - The function is declared as `public shared (message)`, meaning it can be called by external actors.
  //    - It takes a single parameter `principal` of type `Text`, which represents the principal of the miner.
  //    - The function returns a `Nat` value representing the total revenue of the specified miner, excluding adjustments.
  // 2. **Admin Check**:
  //    - The function ensures that the caller is an admin by calling `assert(_isAdmin(message.caller))`.
  // 3. **Get Miner**:
  //    - The function calls `getMiner(Principal.fromText(principal))` to retrieve the miner associated with the given principal.
  //    - The result is stored in the variable `res_`.
  // 4. **Check Miner Existence**:
  //    - The function uses a `switch` statement to check if the miner exists:
  //      - If the result is `#none`, it means the miner does not exist, and the function returns 0.
  //      - If the result is `#ok(miner_)`, it means the miner exists, and the miner's data is stored in the variable `miner_`.
  // 5. **Initialize Revenue History and Total Revenue**:
  //    - The function initializes `revenueHistory_` as an empty array.
  //    - It initializes `totalRev` to 0, which will be used to accumulate the total revenue.
  // 6. **Get Revenue History**:
  //    - The function checks if there is revenue history for the miner using `revenueHash.get(Principal.toText(miner_.walletAddress))`.
  // 7. **Accumulate Revenue**:
  //    - If revenue history exists, the function updates `revenueHistory_` and iterates over each entry in the revenue history:
  //      - If the entry's `from` field is not "adjustment", it adds the `sats` value to `totalRev`.
  // 8. **Return Total Revenue**:
  //    - The function returns the accumulated total revenue `totalRev`.
  // In summary, the `getTotalRevenue` function calculates the total revenue of a specific miner by retrieving the miner's revenue history and accumulating the revenue while excluding adjustments. It ensures that only admins can perform this operation and returns the total revenue as a `Nat` value. If the miner does not exist or has no revenue history, it returns 0.
  //
  public shared (message) func getTotalRevenue(principal : Text) : async Nat {
    assert (_isAdmin(message.caller));

    let res_ = getMiner(Principal.fromText(principal));

    switch (res_) {
      case (#none) {
        return 0;
      };
      case (#ok(miner_)) {
        var revenueHistory_ : [T.DistributionHistory] = [];
        var totalRev = 0;

        switch (revenueHash.get(Principal.toText(miner_.walletAddress))) {
          case (?r) {
            revenueHistory_ := r;

            for (sat in r.vals()) {
              // if (sat.from == "adjustment") adj += sat.sats;
              if (sat.from != "adjustment") totalRev += sat.sats;
            };
            //let hist = Array.size(r);
            return totalRev;
          };
          case (null) {
            return 0;
          };
        };
      };
    };
  };

  // The `getAllRevenue` function is a public shared asynchronous function that calculates and returns the total revenue of all miners, excluding adjustments. Here's a step-by-step description of how the function works:
  // 1. **Function Signature**:
  //    - The function is declared as `public shared (message)`, meaning it can be called by external actors.
  //    - It takes no parameters.
  //    - The function returns a `Nat` value representing the total revenue of all miners, excluding adjustments.
  // 2. **Admin Check**:
  //    - The function ensures that the caller is an admin by calling `assert(_isAdmin(message.caller))`.
  // 3. **Retrieve User List**:
  //    - The function retrieves all entries from `usernameHash` and converts them to an array `ls`.
  // 4. **Initialize Total Revenue and Adjustment**:
  //    - The function initializes two variables:
  //      - `totalRev` to 0, which will be used to accumulate the total revenue.
  //      - `adj` to 0, which will be used to accumulate the total adjustments.
  // 5. **Loop Through Users**:
  //    - The function iterates over each user in `ls`.
  // 6. **Get Miner and Revenue History**:
  //    - For each user, the function retrieves the miner's data using `miners.get(usr.1)` and stores it in the variable `miner_`.
  //    - It initializes `revenueHistory_` as an empty array.
  //    - It checks if there is revenue history for the miner using `revenueHash.get(Principal.toText(miner_.walletAddress))`.
  // 7. **Accumulate Revenue and Adjustments**:
  //    - If revenue history exists, the function updates `revenueHistory_` and iterates over each entry in the revenue history:
  //      - If the entry's `from` field is "adjustment", it adds the `sats` value to `adj`.
  //      - If the entry's `from` field is not "adjustment", it adds the `sats` value to `totalRev`.
  // 8. **Return Total Revenue**:
  //    - The function returns the total revenue excluding adjustments by subtracting `adj` from `totalRev`.
  // In summary, the `getAllRevenue` function calculates the total revenue of all miners by iterating through the list of users, retrieving each miner's revenue history, and accumulating the revenue while excluding adjustments. It ensures that only admins can perform this operation and returns the total revenue as a `Nat` value.
  //
  public shared (message) func getAllRevenue() : async Nat {
    assert (_isAdmin(message.caller));
    var ls = Iter.toArray(usernameHash.entries());
    var totalRev = 0;
    var adj = 0;

    for (usr in ls.vals()) {
      let miner_ = miners.get(usr.1);
      var revenueHistory_ : [T.DistributionHistory] = [];

      switch (revenueHash.get(Principal.toText(miner_.walletAddress))) {
        case (?r) {
          revenueHistory_ := r;
          for (sat in r.vals()) {
            if (sat.from == "adjustment") adj += sat.sats;
            if (sat.from != "adjustment") totalRev += sat.sats;
          };
          //let hist = Array.size(r);

        };
        case (null) {
          //return 0;
        };
      };
    };

    return totalRev -adj;
  };

  public shared (message) func getAllRevenueRaw() : async [(Text, [T.DistributionHistory])] {
    assert (_isAdmin(message.caller));
    // var ls = Iter.toArray(usernameHash.entries());
    return Iter.toArray(revenueHash.entries());

  };

  // The `getAllBalance` function is a public shared asynchronous function that calculates and returns the total balance of all miners. Here's a step-by-step description of how the function works:
  // 1. **Function Signature**:
  //    - The function is declared as `public shared (message)`, meaning it can be called by external actors.
  //    - It takes no parameters.
  //    - The function returns a `Nat` value representing the total balance of all miners.
  // 2. **Admin Check**:
  //    - The function ensures that the caller is an admin by calling `assert(_isAdmin(message.caller))`.
  // 3. **Retrieve User List**:
  //    - The function retrieves all entries from `usernameHash` and converts them to an array `ls`.
  // 4. **Initialize Total Revenue**:
  //    - The function initializes a variable `totalRev` to 0, which will be used to accumulate the total balance.
  // 5. **Loop Through Users**:
  //    - The function iterates over each user in `ls`.
  // 6. **Get Miner and Status**:
  //    - For each user, the function retrieves the miner's data using `miners.get(usr.1)` and stores it in the variable `miner_`.
  //    - It retrieves the miner's status using `minerStatus.get(miner_.id)` and stores it in the variable `minerStat_`.
  // 7. **Accumulate Balance**:
  //    - The function adds the miner's balance (`minerStat_.balance`) to `totalRev`.
  // 8. **Return Total Balance**:
  //    - The function returns the accumulated total balance `totalRev`.
  // In summary, the `getAllBalance` function calculates the total balance of all miners by iterating through the list of users, retrieving each miner's balance, and accumulating the balances. It ensures that only admins can perform this operation and returns the total balance as a `Nat` value.
  //
  public shared (message) func getAllBalance() : async Nat {
    assert (_isAdmin(message.caller));
    var ls = Iter.toArray(usernameHash.entries());
    var totalRev = 0;
    for (usr in ls.vals()) {
      let miner_ = miners.get(usr.1);
      let minerStat_ = minerStatus.get(miner_.id);

      totalRev += minerStat_.balance;

    };
    return totalRev;
  };

  // The `withdrawCKBTC` function is a public shared asynchronous function that handles the withdrawal of ckBTC for a miner. Here's a step-by-step description of how the function works:
  // 1. **Function Signature**:
  //    - The function is declared as `public shared (message)`, meaning it can be called by external actors.
  //    - It takes three parameters:
  //      - `username_`: The username of the miner.
  //      - `amount_`: The amount of ckBTC to be withdrawn.
  //      - `address`: The address to which the ckBTC will be sent.
  //    - The function returns a `T.TransferRes` indicating the result of the withdrawal.
  // 2. **Pause Check**:
  //    - The function ensures that the system is not paused by calling `assert(_isNotPaused())`.
  // 3. **Balance Check**:
  //    - The function ensures that the total balance is greater than the amount to be withdrawn by calling `assert(totalBalance > amount_)`.
  // 4. **Increment Withdrawal Index**:
  //    - The function increments the `withdrawalIndex` by 1.
  // 5. **Get Miner**:
  //    - The function calls `getMiner(message.caller)` to retrieve the miner associated with the caller.
  //    - The result is stored in the variable `res_`.
  // 6. **Check Miner Existence**:
  //    - The function uses a `switch` statement to check if the miner exists:
  //      - If the result is `#none`, it means the miner does not exist, and the function does not proceed.
  //      - If the result is `#ok(m)`, it assigns the miner's ID to `id_` and the miner's username to `uname`.
  // 7. **Get Miner Status**:
  //    - The function retrieves the miner's status using `minerStatus.get(id_)` and stores it in the variable `minerStatus_`.
  // 8. **Check Sufficient Balance**:
  //    - The function checks if the miner has sufficient balance to cover the withdrawal amount plus a fee of 10 units.
  //    - If the balance is insufficient, it returns an error indicating the insufficient funds.
  // 9. **Log Pre-Transfer Transaction**:
  //    - The function logs the pre-transfer transaction by calling `logTransaction`.
  // 10. **Update Balances**:
  //     - The function updates the miner's balance, total withdrawn, and total shared revenue by subtracting the withdrawal amount plus the fee.
  //     - It also updates the `minerStatusAndRewardHash` with the new miner status.
  // 11. **Update Global Balances**:
  //     - The function updates the global `totalWithdrawn` and `totalBalance` by subtracting the withdrawal amount plus the fee.
  // 12. **Create Withdrawal History**:
  //     - The function creates a `T.WithdrawalHistory` record with the withdrawal details and stores it in the variable `wdh`.
  // 13. **Update Withdrawal Hash**:
  //     - The function updates the `withdrawalHash` and `allWithdrawalHash` with the new withdrawal history.
  // 14. **Perform Transfer**:
  //     - The function attempts to perform the ckBTC transfer using the `CKBTC.icrc1_transfer` method.
  //     - If an error occurs during the transfer, it reverts the balance updates, logs the failed transaction, and returns an error indicating the failure.
  // 15. **Handle Transfer Result**:
  //     - The function uses a `switch` statement to handle the result of the transfer:
  //       - If the transfer is successful (`#Ok(number)`), it logs the successful transaction, updates the `allSuccessfulWithdrawalHash`, and returns `#success(number)`.
  //       - If the transfer fails (`#Err(msg)`), it reverts the balance updates, logs the failed transaction, and returns an error with the error message.
  // In summary, the `withdrawCKBTC` function handles the withdrawal of ckBTC for a miner, ensuring that the system is not paused, the caller is verified, and the miner has sufficient balance. It logs the transaction, updates the relevant balances, performs the ckBTC transfer, and handles various error cases. If the withdrawal is successful, it logs the transaction and returns the success result. If any errors occur, it reverts the balance updates and returns an error.
  //
  public shared (message) func withdrawCKBTC(username_ : Text, amount_ : Nat, address : Text) : async T.TransferRes {
    assert (_isNotPaused());
    assert (totalBalance > amount_);
    //assert (_isAdmin(message.caller));
    withdrawalIndex += 1;
    //let addr = Principal.fromText(message.caller);
    let amountNat_ : Nat = amount_;
    let res_ = getMiner(message.caller);
    var id_ = 0;
    var uname = "";
    switch (res_) {
      case (#none) {
        //return false;
      };
      case (#ok(m)) {
        id_ := m.id;
        uname := m.username;
      };
    };
    //let miner_ = miners_[0];
    var minerStatus_ : T.MinerStatus = minerStatus.get(id_);
    if (minerStatus_.balance < (amount_ + 10)) {
      return #error("insufficient balance to withdraw");
    };

    logTransaction(id_, "{\"action\":\"pre-withdraw CKBTC\",\"receiver\":\"" #address # "\"}", Nat.toText(amount_), "pre transfer", "{\"currency\":\"CKBTC\",\"chain\":\"ICP\"}", uname, Principal.toText(message.caller));
    minerStatus_.balance -= (amount_ + 10);
    minerStatus_.totalWithdrawn += (amount_ + 10);
    var tsr = minerStatus_.totalSharedRevenue;
    if (minerStatus_.totalSharedRevenue > 0) {
      if (minerStatus_.totalSharedRevenue > minerStatus_.balance) {
        //minerStatus_.totalSharedRevenue := minerStatus_.balance;
      };
    };
    switch (minerStatusAndRewardHash.get(Nat.toText(id_))) {
      case (?mStat) {

        minerStatusAndRewardHash.put(Nat.toText(id_), minerStatus_);

      };
      case (null) {

      };
    };

    totalWithdrawn += (amount_ + 10);
    totalBalance -= (amount_ + 10);

    var tme = now() / 1000000;
    var wdh : T.WithdrawalHistory = {
      id = withdrawalIndex;
      //caller: Text;
      time = tme;
      action = "PRE Withdraw CKBTC";
      //receiver : Text;
      amount = Nat.toText(amount_);
      txid = "pre transfer";
      currency = "CKBTC";
      username = uname;
      wallet = Principal.toText(message.caller);
      jwalletId = "";
      bankId = "CKBTC";
      memo = null;
      //provider : Text;
    };

    switch (withdrawalHash.get(Nat.toText(id_))) {
      case (?withdrawals) {
        var wd = HashMap.fromIter<Text, T.WithdrawalHistory>(withdrawals.vals(), 1, Text.equal, Text.hash);
        //return #res(list);
        wd.put(Int.toText(tme), wdh);
        allWithdrawalHash.put(Int.toText(tme), wdh);
        withdrawalHash.put(Nat.toText(id_), Iter.toArray(wd.entries()));

      };
      case (null) {

        var wd = HashMap.HashMap<Text, T.WithdrawalHistory>(0, Text.equal, Text.hash);
        //return #res(list);
        wd.put(Int.toText(tme), wdh);
        allWithdrawalHash.put(Int.toText(tme), wdh);
        withdrawalHash.put(Nat.toText(id_), Iter.toArray(wd.entries()));
      };
    };
    var transferResult : T.Result = #Ok(0);
    try {
      transferResult := await CKBTC.icrc1_transfer({
        amount = amount_;
        fee = ?10;
        created_at_time = null;
        from_subaccount = null;
        to = { owner = Principal.fromText(address); subaccount = null };
        memo = null;
      });
      var res = 0;
    } catch (error) {
      minerStatus_.balance += (amount_ + 10);
      minerStatus_.totalWithdrawn -= (amount_ + 10);
      minerStatus_.totalSharedRevenue := tsr;
      totalWithdrawn -= (amount_ + 10);
      totalBalance += (amount_ + 10);
      switch (minerStatusAndRewardHash.get(Nat.toText(id_))) {
        case (?mStat) {

          minerStatusAndRewardHash.put(Nat.toText(id_), minerStatus_);

        };
        case (null) {

        };
      };
      logTransaction(id_, "{\"action\":\"crashed withdraw CKBTC\",\"receiver\":\"" #address # "\"}", Nat.toText(amount_), "pre transfer", "{\"currency\":\"CKBTC\",\"chain\":\"ICP\"}", uname, Principal.toText(message.caller));

      return #error("ckbtc cansiter rejects");
    };

    //var res = 0;
    switch (transferResult) {
      case (#Ok(number)) {

        var wdh : T.WithdrawalHistory = {
          id = withdrawalIndex;
          //caller: Text;
          time = tme;
          action = "Withdraw CKBTC";
          //receiver : Text;
          amount = Nat.toText(amount_);
          txid = Int.toText(number);
          currency = "CKBTC";
          username = uname;
          wallet = Principal.toText(message.caller);
          jwalletId = "";
          bankId = "CKBTC";
          memo = null;
          //provider : Text;
        };

        switch (withdrawalHash.get(Nat.toText(id_))) {
          case (?withdrawals) {
            var wd = HashMap.fromIter<Text, T.WithdrawalHistory>(withdrawals.vals(), 1, Text.equal, Text.hash);
            //return #res(list);
            wd.put(Int.toText(tme), wdh);
            allWithdrawalHash.put(Int.toText(tme), wdh);
            withdrawalHash.put(Nat.toText(id_), Iter.toArray(wd.entries()));
            allSuccessfulWithdrawalHash.put(Int.toText(tme), wdh);

          };
          case (null) {

            var wd = HashMap.HashMap<Text, T.WithdrawalHistory>(0, Text.equal, Text.hash);
            //return #res(list);
            wd.put(Int.toText(tme), wdh);
            allWithdrawalHash.put(Int.toText(tme), wdh);
            withdrawalHash.put(Nat.toText(id_), Iter.toArray(wd.entries()));
            allSuccessfulWithdrawalHash.put(Int.toText(tme), wdh);
          };
        };
        logTransaction(id_, "{\"action\":\"withdraw CKBTC\",\"receiver\":\"" #address # "\"}", Nat.toText(amount_), Nat.toText(number), "{\"currency\":\"CKBTC\",\"chain\":\"ICP\"}", uname, Principal.toText(message.caller));

        return #success(number);
      };
      case (#Err(msg)) {

        var tme = now() / 1000000;
        var errmsg = "";
        Debug.print("transfer error  ");
        switch (msg) {
          case (#BadFee(number)) {
            Debug.print("Bad Fee");
            errmsg := "Bad Fee";
          };
          case (#GenericError(number)) {
            Debug.print("err " #number.message);
            errmsg := "err " #number.message;
          };
          case (#InsufficientFunds(number)) {
            Debug.print("insufficient funds");
            errmsg := "insufficient funds";
          };
          case _ {
            Debug.print("err");
            errmsg := "other";
          };
        };
        //return #error(errmsg);
        var wdh : T.WithdrawalHistory = {
          id = withdrawalIndex;
          //caller: Text;
          time = tme;
          action = "FAILED : Withdraw CKBTC";
          //receiver : Text;
          amount = Nat.toText(amount_);
          txid = errmsg;
          currency = "IDR";
          username = uname;
          wallet = Principal.toText(message.caller);
          jwalletId = "";
          bankId = "CKBTC";
          memo = null;
          //provider : Text;
        };

        minerStatus_.balance += (amount_ + 10);
        minerStatus_.totalWithdrawn -= (amount_ + 10);
        totalWithdrawn -= (amount_ + 10);
        totalBalance += (amount_ + 10);
        minerStatus_.totalSharedRevenue := tsr;
        switch (minerStatusAndRewardHash.get(Nat.toText(id_))) {
          case (?mStat) {

            minerStatusAndRewardHash.put(Nat.toText(id_), minerStatus_);

          };
          case (null) {

          };
        };
        allWithdrawalHash.put(Int.toText(tme), wdh);
        failedWithdrawalHash.put(Int.toText(tme), wdh);
        return #error(errmsg);
      };
    };
    //logTransaction(id_, "{\"action\":\"withdraw CKBTC\",\"receiver\":\"" #address # "\"}", Nat.toText(amount_), "failed", "{\"currency\":\"CKBTC\",\"chain\":\"ICP\"}", uname, Principal.toText(message.caller));

    return #error("Other Error");
  };

  public query (message) func whoCall() : async Text {
    return Principal.toText(message.caller);
  };

  public shared (message) func getTransaction() : async [T.TransactionHistory] {
    assert (_isAdmin(message.caller));
    return Buffer.toArray<T.TransactionHistory>(transactions);
  };

  // The `logTransaction` function is a helper function that logs a transaction for a specific miner. Here's a step-by-step description of how the function works:
  // 1. **Function Signature**:
  //    - The function takes seven parameters:
  //      - `id_`: The ID of the miner.
  //      - `action_`: The action associated with the transaction.
  //      - `amount_`: The amount involved in the transaction.
  //      - `txid_`: The transaction ID.
  //      - `currency_`: The currency involved in the transaction.
  //      - `username`: The username of the miner.
  //      - `caller`: The caller's principal in text format.
  // 2. **Debug Print**:
  //    - The function prints a debug message indicating the action being logged using `Debug.print("logging transaction " #action_)`.
  // 3. **Create Transaction History**:
  //    - The function creates a `T.TransactionHistory` record with the following details:
  //      - `id`: The current value of `transactionIndex`.
  //      - `time`: The current time obtained by calling `now()`.
  //      - `action`: The action associated with the transaction (`action_`).
  //      - `amount`: The amount involved in the transaction (`amount_`).
  //      - `txid`: The transaction ID (`txid_`).
  //      - `currency`: The currency involved in the transaction (`currency_`).
  //      - `provider` and `receiver`: Not used in this context (commented out).
  // 4. **Create Detailed Transaction Log**:
  //    - The function creates another `T.TransactionHistory` record with additional details:
  //      - `id`: The current value of `transactionIndex`.
  //      - `time`: The current time obtained by calling `now()`.
  //      - `action`: The action associated with the transaction, concatenated with the username and caller (`action_ # " by " #username # " " #caller`).
  //      - `amount`: The amount involved in the transaction (`amount_`).
  //      - `txid`: The transaction ID (`txid_`).
  //      - `currency`: The currency involved in the transaction (`currency_`).
  //      - `provider` and `receiver`: Not used in this context (commented out).
  // 5. **Initialize Transaction Array**:
  //    - The function initializes an array `array_` containing the created `transaction`.
  // 6. **Get Miner Status**:
  //    - The function retrieves the miner's status using `minerStatus.get(id_)` and stores it in the variable `status_`.
  // 7. **Update Miner Transactions**:
  //    - The function appends the created `transaction` to the miner's existing transactions using `Array.append`, but only if `txid_` is not "pre transfer".
  // 8. **Add Transaction to Global List**:
  //    - The function adds the detailed `transactionLog` to the global `transactions` list.
  // 9. **Increment Transaction Index**:
  //    - The function increments the `transactionIndex` by 1 to ensure that the next transaction will have a unique ID.
  // In summary, the `logTransaction` function logs a transaction for a specific miner by creating a transaction history record, updating the miner's transactions (if not a pre-transfer), and adding a detailed transaction log to the global list. It includes debug print statements to trace the logging process and ensures that the transaction index is incremented to maintain unique transaction IDs.
  //
  func logTransaction(id_ : Nat, action_ : Text, amount_ : Text, txid_ : Text, currency_ : Text, username : Text, caller : Text) {
    Debug.print("logging transaction " #action_);
    let transaction : T.TransactionHistory = {
      id = transactionIndex;
      //caller = caller_;
      time = now();
      action = action_;
      amount = amount_;
      txid = txid_;
      currency = currency_;
      //provider = provider_;
      //receiver = receiver_;
    };
    let transactionLog : T.TransactionHistory = {
      id = transactionIndex;
      //caller = caller_;
      time = now();
      action = action_ # " by " #username # " " #caller;
      amount = amount_;
      txid = txid_;
      currency = currency_;
      //provider = provider_;
      //receiver = receiver_;
    };

    let array_ : [T.TransactionHistory] = [transaction];
    let status_ = minerStatus.get(id_);
    Debug.print("appending");
    if (txid_ != "pre transfer") status_.transactions := Array.append<T.TransactionHistory>(status_.transactions, array_);

    transactions.add(transactionLog);
    transactionIndex += 1;
  };

  // The `withdrawalLog` function is a helper function that logs a withdrawal transaction for a specific miner. Here's a step-by-step description of how the function works:
  // 1. **Function Signature**:
  //    - The function takes seven parameters:
  //      - `id_`: The ID of the miner.
  //      - `action_`: The action associated with the transaction.
  //      - `amount_`: The amount involved in the transaction.
  //      - `txid_`: The transaction ID.
  //      - `currency_`: The currency involved in the transaction.
  //      - `username`: The username of the miner.
  //      - `caller`: The caller's principal in text format.
  // 2. **Debug Print**:
  //    - The function prints a debug message indicating the action being logged using `Debug.print("logging transaction " #action_)`.
  // 3. **Create Transaction History**:
  //    - The function creates a `T.TransactionHistory` record with the following details:
  //      - `id`: The current value of `transactionIndex`.
  //      - `time`: The current time obtained by calling `now()`.
  //      - `action`: The action associated with the transaction (`action_`).
  //      - `amount`: The amount involved in the transaction (`amount_`).
  //      - `txid`: The transaction ID (`txid_`).
  //      - `currency`: The currency involved in the transaction (`currency_`).
  //      - `provider` and `receiver`: Not used in this context (commented out).
  // 4. **Create Detailed Transaction Log**:
  //    - The function creates another `T.TransactionHistory` record with additional details:
  //      - `id`: The current value of `transactionIndex`.
  //      - `time`: The current time obtained by calling `now()`.
  //      - `action`: The action associated with the transaction, concatenated with the username and caller (`action_ # " by " #username # " " #caller`).
  //      - `amount`: The amount involved in the transaction (`amount_`).
  //      - `txid`: The transaction ID (`txid_`).
  //      - `currency`: The currency involved in the transaction (`currency_`).
  //      - `provider` and `receiver`: Not used in this context (commented out).
  // 5. **Initialize Transaction Array**:
  //    - The function initializes an array `array_` containing the created `transaction`.
  // 6. **Get Miner Status**:
  //    - The function retrieves the miner's status using `minerStatus.get(id_)` and stores it in the variable `status_`.
  // 7. **Update Miner Transactions**:
  //    - The function appends the created `transaction` to the miner's existing transactions using `Array.append`.
  // 8. **Add Transaction to Global List**:
  //    - The function adds the detailed `transactionLog` to the global `transactions` list.
  // 9. **Increment Transaction Index**:
  //    - The function increments the `transactionIndex` by 1 to ensure that the next transaction will have a unique ID.
  // In summary, the `withdrawalLog` function logs a withdrawal transaction for a specific miner by creating a transaction history record, updating the miner's transactions, and adding a detailed transaction log to the global list. It includes debug print statements to trace the logging process and ensures that the transaction index is incremented to maintain unique transaction IDs.
  //
  func withdrawalLog(id_ : Nat, action_ : Text, amount_ : Text, txid_ : Text, currency_ : Text, username : Text, caller : Text) {
    Debug.print("logging transaction " #action_);
    let transaction : T.TransactionHistory = {
      id = transactionIndex;
      //caller = caller_;
      time = now();
      action = action_;
      amount = amount_;
      txid = txid_;
      currency = currency_;
      //provider = provider_;
      //receiver = receiver_;
    };
    let transactionLog : T.TransactionHistory = {
      id = transactionIndex;
      //caller = caller_;
      time = now();
      action = action_ # " by " #username # " " #caller;
      amount = amount_;
      txid = txid_;
      currency = currency_;
      //provider = provider_;
      //receiver = receiver_;
    };

    let array_ : [T.TransactionHistory] = [transaction];
    let status_ = minerStatus.get(id_);
    Debug.print("appending");
    status_.transactions := Array.append<T.TransactionHistory>(status_.transactions, array_);

    transactions.add(transactionLog);
    transactionIndex += 1;
  };

  // The `logDistribution` function is a helper function that logs a distribution transaction. Here's a step-by-step description of how the function works:
  // 1. **Function Signature**:
  //    - The function takes five parameters:
  //      - `id_`: The ID of the distribution (not used in the function body).
  //      - `action_`: The action associated with the distribution.
  //      - `amount_`: The amount involved in the distribution.
  //      - `txid_`: The transaction ID.
  //      - `currency_`: The currency involved in the distribution.
  // 2. **Debug Print**:
  //    - The function prints a debug message indicating the action being logged using `Debug.print("logging distribution " #action_)`.
  // 3. **Create Transaction History**:
  //    - The function creates a `T.TransactionHistory` record with the following details:
  //      - `id`: The current value of `transactionIndex`.
  //      - `time`: The current time obtained by calling `now()`.
  //      - `action`: The action associated with the distribution (`action_`).
  //      - `amount`: The amount involved in the distribution (`amount_`).
  //      - `txid`: The transaction ID (`txid_`).
  //      - `currency`: The currency involved in the distribution (`currency_`).
  //      - `provider` and `receiver`: Not used in this context (commented out).
  // 4. **Debug Print**:
  //    - The function prints a debug message indicating that the transaction is being appended using `Debug.print("appending")`.
  // 5. **Add Transaction to Global List**:
  //    - The function adds the created `transaction` to the global `transactions` list.
  // 6. **Increment Transaction Index**:
  //    - The function increments the `transactionIndex` by 1 to ensure that the next transaction will have a unique ID.
  // In summary, the `logDistribution` function logs a distribution transaction by creating a transaction history record with the distribution details and adding it to the global list of transactions. It also increments the transaction index to maintain unique transaction IDs and includes debug print statements to trace the logging process.
  //
  func logDistribution(id_ : Nat, action_ : Text, amount_ : Text, txid_ : Text, currency_ : Text) {
    Debug.print("logging distribution " #action_);
    let transaction : T.TransactionHistory = {
      id = transactionIndex;
      //caller = caller_;
      time = now();
      action = action_;
      amount = amount_;
      txid = txid_;
      currency = currency_;
      //provider = provider_;
      //receiver = receiver_;
    };

    Debug.print("appending");

    transactions.add(transaction);
    transactionIndex += 1;
  };

  // The `forcelogTransaction` function is a public shared asynchronous function that logs a transaction for a specific miner. Here's a step-by-step description of how the function works:
  // 1. **Function Signature**:
  //    - The function is declared as `public shared (message)`, meaning it can be called by external actors.
  //    - It takes five parameters:
  //      - `id_`: The ID of the miner.
  //      - `action_`: The action associated with the transaction.
  //      - `amount_`: The amount involved in the transaction.
  //      - `txid_`: The transaction ID.
  //      - `currency_`: The currency involved in the transaction.
  //    - The function returns an array of `T.TransactionHistory` asynchronously.
  // 2. **Admin Check**:
  //    - The function ensures that the caller is an admin by calling `assert(_isAdmin(message.caller))`.
  // 3. **Create Transaction History**:
  //    - The function creates a `T.TransactionHistory` record with the following details:
  //      - `id`: The current value of `transactionIndex`.
  //      - `time`: The current time obtained by calling `now()`.
  //      - `action`: The action associated with the transaction (`action_`).
  //      - `amount`: The amount involved in the transaction (`amount_`).
  //      - `txid`: The transaction ID (`txid_`).
  //      - `currency`: The currency involved in the transaction (`currency_`).
  // 4. **Initialize Transaction Array**:
  //    - The function initializes an array `array_` containing the created `transaction`.
  // 5. **Get Miner Status**:
  //    - The function retrieves the miner's status using `minerStatus_.get(id_)` and stores it in the variable `status_`.
  // 6. **Update Miner Transactions**:
  //    - The function appends the created `transaction` to the miner's existing transactions using `Array.append`.
  // 7. **Add Transaction to Global List**:
  //    - The function adds the created `transaction` to the global `transactions` list.
  // 8. **Increment Transaction Index**:
  //    - The function increments the `transactionIndex` by 1 to ensure that the next transaction will have a unique ID.
  // 9. **Return Updated Transactions**:
  //    - The function returns the updated list of transactions for the miner.
  // In summary, the `forcelogTransaction` function logs a transaction for a specific miner by creating a transaction history record, updating the miner's transactions, and adding the transaction to the global list. It ensures that only admins can perform this operation and returns the updated list of transactions for the miner.
  //
  public shared (message) func forcelogTransaction(id_ : Nat, action_ : Text, amount_ : Text, txid_ : Text, currency_ : Text) : async [T.TransactionHistory] {
    assert (_isAdmin(message.caller));
    let transaction : T.TransactionHistory = {
      id = transactionIndex;
      //caller = caller_;
      time = now();
      action = action_;
      amount = amount_;
      txid = txid_;
      currency = currency_;
      //provider = provider_;
      //receiver = receiver_;
    };

    let array_ : [T.TransactionHistory] = [transaction];
    let status_ = minerStatus_.get(id_);

    status_.transactions := Array.append<T.TransactionHistory>(status_.transactions, array_);

    transactions.add(transaction);
    transactionIndex += 1;
    status_.transactions;
  };

  // The `logMiner` function is a helper function that logs the creation of a new miner. Here's a step-by-step description of how the function works:
  // 1. **Function Signature**:
  //    - The function takes four parameters:
  //      - `id_`: The ID of the miner.
  //      - `username_`: The username of the miner.
  //      - `hash_`: The hashrate of the miner.
  //      - `wallet_`: The wallet address of the miner.
  // 2. **Create Transaction History**:
  //    - The function creates a `T.TransactionHistory` record with the following details:
  //      - `id`: The current value of `transactionIndex`.
  //      - `time`: The current time obtained by calling `now()`.
  //      - `action`: A string indicating the action, set to "new miner".
  //      - `receiver`: An empty string (not used in this context).
  //      - `amount`: The hashrate of the miner (`hash_`).
  //      - `txid`: The username of the miner (`username_`).
  //      - `currency`: An empty string (not used in this context).
  //      - `provider`: An empty string (not used in this context).
  // 3. **Add Transaction to List**:
  //    - The function adds the created `transaction` to the `transactions` list.
  // 4. **Increment Transaction Index**:
  //    - The function increments the `transactionIndex` by 1 to ensure that the next transaction will have a unique ID.
  // In summary, the `logMiner` function logs the creation of a new miner by creating a transaction history record with the miner's details and adding it to the list of transactions. It also increments the transaction index to maintain unique transaction IDs.
  //
  func logMiner(id_ : Nat, username_ : Text, hash_ : Text, wallet_ : Text) {
    let transaction : T.TransactionHistory = {
      id = transactionIndex;
      //caller = caller_;
      time = now();
      action = "new miner";
      receiver = "";
      amount = hash_;
      txid = username_;
      currency = "";
      provider = "";
    };

    transactions.add(transaction);
    transactionIndex += 1;
  };

  // The `withdrawUSDT` function is a public shared asynchronous function that handles the withdrawal of USDT (Tether) for a miner. Here's a step-by-step description of how the function works:
  // 1. **Function Signature**:
  //    - The function is declared as `public shared (message)`, meaning it can be called by external actors.
  //    - It takes four parameters:
  //      - `username_`: The username of the miner.
  //      - `amount_`: The amount of USDT to be withdrawn.
  //      - `addr_`: The address to which the USDT will be sent.
  //      - `usd_`: The amount of USDT in USD.
  //    - The function returns a `T.TransferRes` indicating the result of the withdrawal.
  // 2. **Pause Check**:
  //    - The function ensures that the system is not paused by calling `assert(_isNotPaused())`.
  // 3. **Maintenance Check**:
  //    - The function immediately returns an error indicating that USDT withdrawals are temporarily unavailable due to maintenance.
  // 4. **Verify Caller**:
  //    - The function ensures that the caller is verified by calling `assert(_isVerified(message.caller))`.
  // 5. **Get Miner**:
  //    - The function calls `getMiner(message.caller)` to retrieve the miner associated with the caller.
  //    - The result is stored in the variable `res_`.
  // 6. **Check Miner Existence**:
  //    - The function uses a `switch` statement to check if the miner exists:
  //      - If the result is `#none`, it returns an error indicating that the user does not exist.
  //      - If the result is `#ok(m)`, it assigns the miner's ID to `id_`.
  // 7. **Get Miner Status**:
  //    - The function retrieves the miner's status using `minerStatus.get(id_)` and stores it in the variable `minerStatus_`.
  // 8. **Check Sufficient Balance**:
  //    - The function checks if the miner has sufficient balance to cover the withdrawal amount plus a fee of 10 units.
  //    - If the balance is insufficient, it returns an error indicating the insufficient funds.
  // 9. **Log Pre-Transfer Transaction**:
  //    - The function logs the pre-transfer transaction by calling `logTransaction`.
  // 10. **Initialize HTTP Request**:
  //     - The function initializes an actor `ic` of type `T.IC` with the principal `"aaaaa-aa"`.
  //     - It constructs a unique ID `uid_` and a URL for the HTTP request.
  // 11. **Update Balances**:
  //     - The function updates the miner's total withdrawn, total balance, and balance by subtracting the withdrawal amount plus the fee.
  //     - It also updates the miner's total shared revenue if applicable.
  // 12. **Update Miner Status Hash**:
  //     - The function updates the `minerStatusAndRewardHash` with the new miner status.
  // 13. **Send HTTP Request**:
  //     - The function sends the HTTP request by calling `send_http(url)` and awaits the response.
  //     - If an error occurs during the HTTP request, it reverts the balance updates and returns an error indicating the failure.
  // 14. **Check HTTP Response**:
  //     - The function checks if the HTTP response contains the text "transfersuccess".
  //     - If the response is valid, it splits the response text and calls `moveCKBTC(amount_)` to transfer ckBTC.
  //     - If the ckBTC transfer fails, it reverts the balance updates, logs the failed transaction, and returns an error.
  // 15. **Log Successful Transaction**:
  //     - If the ckBTC transfer is successful, the function logs the successful transaction and returns `#success(amount_)`.
  // 16. **Handle Invalid HTTP Response**:
  //     - If the HTTP response is invalid, the function reverts the balance updates and returns an error with the response text.
  // In summary, the `withdrawUSDT` function handles the withdrawal of USDT for a miner, ensuring that the system is not paused, the caller is verified, and the miner has sufficient balance.
  // It logs the transaction, sends an HTTP request to process the withdrawal, and handles various error cases. If the withdrawal is successful, it transfers ckBTC and logs the transaction. If any errors occur, it reverts the balance updates and returns an error.
  //
  public shared (message) func withdrawUSDT(username_ : Text, amount_ : Nat, addr_ : Text, usd_ : Text) : async T.TransferRes {
    assert (_isNotPaused());
    return #error("due to maintenance, withdraw using USDT is temporary unavailable");
    // assert (_isVerified(message.caller));
    let amountNat_ : Nat = amount_;
    //let miner_ = getMiner(message.caller);
    let res_ = getMiner(message.caller);
    var id_ = 0;
    switch (res_) {
      case (#none) {
        // return false;
        return #error("no user");
      };
      case (#ok(m)) {
        id_ := m.id;
      };
    };
    var minerStatus_ : T.MinerStatus = minerStatus.get(id_);
    if ((minerStatus_.balance >= (amount_ + 10)) == false) {
      return #error("insufficient fund : " #Nat.toText(amount_) # " requested, available " # Nat.toText(minerStatus_.balance));
    };

    logTransaction(id_, "{\"action\":\"withdraw USDT\",\"receiver\":\"" #addr_ # "\"}", Nat.toText(amount_), "pre transfer", "{\"currency\":\"IDR\",\"bank\":\"" # "USDT" # "\"}", username_, Principal.toText(message.caller));

    let ic : T.IC = actor ("aaaaa-aa");
    let uid_ = addr_ #usd_ #Int.toText(now());
    let url = "https://api.lokamining.com/transfer?targetAddress=" #addr_ # "&amount=" #usd_ # "&id=" #uid_;
    minerStatus_.totalWithdrawn += amount_ + 10;
    totalBalance -= (amount_ + 10);
    totalWithdrawn += (amount_ + 10);
    minerStatus_.balance -= (amount_ + 10);
    var tsr = minerStatus_.totalSharedRevenue;
    if (minerStatus_.totalSharedRevenue > 0) {
      if (minerStatus_.totalSharedRevenue > minerStatus_.balance) {
        //minerStatus_.totalSharedRevenue := minerStatus_.balance;
      };
    };
    switch (minerStatusAndRewardHash.get(Nat.toText(id_))) {
      case (?mStat) {

        minerStatusAndRewardHash.put(Nat.toText(id_), minerStatus_);

      };
      case (null) {

      };
    };
    var decoded_text = "";
    try {
      decoded_text := await send_http(url);

    } catch (error) {
      minerStatus_.totalWithdrawn -= amount_ + 10;
      minerStatus_.totalSharedRevenue := tsr;
      totalBalance += (amount_ + 10);
      totalWithdrawn -= (amount_ + 10);
      switch (minerStatusAndRewardHash.get(Nat.toText(id_))) {
        case (?mStat) {

          minerStatusAndRewardHash.put(Nat.toText(id_), minerStatus_);

        };
        case (null) {

        };
      };
      return #error("https outcall to send ckBTC failed");
    };
    //let decoded_text = "transfersuccess";
    //return decoded_text;
    Debug.print("result " #decoded_text);
    var isValid = Text.contains(decoded_text, #text "transfersuccess");
    if (isValid) {
      let hashtext_ = textSplit(decoded_text, '/');
      let res = await moveCKBTC(amount_);
      if (res == false) {
        minerStatus_.totalWithdrawn -= amount_ + 10;
        totalBalance += (amount_ + 10);
        totalWithdrawn -= (amount_ + 10);
        logTransaction(id_, "{\"action\":\"failed withdraw USDT\",\"receiver\":\"" #addr_ # "\"}", Nat.toText(amount_), decoded_text, "{\"currency\":\"USDT\",\"chain\":\"Arbitrum\"}", username_, Principal.toText(message.caller));

        return #error("transfer ckBTC failed");
      };
      logTransaction(id_, "{\"action\":\"withdraw USDT\",\"receiver\":\"" #addr_ # "\"}", Nat.toText(amount_), decoded_text, "{\"currency\":\"USDT\",\"chain\":\"Arbitrum\"}", username_, Principal.toText(message.caller));
      //logTransaction(miner_.id, "{action:\"withdrawCKBTC\",receiver:\""#address#"\"}", Nat.toText(amount_), Int.toText(number), "{currency:\"CKBTC\",chain:\"ICP\"}");

      return #success(amount_);

      //return true;
    } else {
      minerStatus_.totalWithdrawn -= amount_ + 10;
      minerStatus_.totalSharedRevenue := tsr;
      totalBalance += (amount_ + 10);
      totalWithdrawn -= (amount_ + 10);
      switch (minerStatusAndRewardHash.get(Nat.toText(id_))) {
        case (?mStat) {

          minerStatusAndRewardHash.put(Nat.toText(id_), minerStatus_);

        };
        case (null) {

        };
      };
    };
    return #error(decoded_text);
    //decoded_text;
  };

  // The `moveCKBTC` function is an asynchronous function that transfers a specified amount of ckBTC from one vault to another. Here's a step-by-step description of how the function works:
  // 1. **Function Signature**:
  //    - The function is declared as `async`, meaning it performs asynchronous operations.
  //    - It takes a single parameter `amount_` of type `Nat`, which represents the amount of ckBTC to be transferred.
  //    - The function returns a `Bool` indicating the success (`true`) or failure (`false`) of the transfer.
  // 2. **Pause Check**:
  //    - The function ensures that the system is not paused by calling `assert(_isNotPaused())`.
  // 3. **Initialize Amount**:
  //    - The function assigns the input parameter `amount_` to a local variable `amountNat_`.
  // 4. **Perform Transfer**:
  //    - The function attempts to perform the transfer using the `CKBTC.icrc1_transfer` method.
  //    - It specifies the transfer details, including:
  //      - `amount`: The amount of ckBTC to be transferred.
  //      - `fee`: An optional fee of 10 units.
  //      - `created_at_time`: Not set (null).
  //      - `from_subaccount`: Not set (null).
  //      - `to`: The destination vault (`lokaCKBTCVault`).
  //      - `memo`: Not set (null).
  // 5. **Handle Transfer Result**:
  //    - The function uses a `switch` statement to handle the result of the transfer:
  //      - If the transfer is successful (`#Ok(number)`), it returns `true`.
  //      - If the transfer fails (`#Err(msg)`), it prints an error message and handles specific error cases:
  //        - `#BadFee(number)`: Prints "Bad Fee".
  //        - `#GenericError(number)`: Prints the error message.
  //        - `#InsufficientFunds(number)`: Prints "insufficient funds" and returns `false`.
  //        - Other errors: Prints "err".
  // 6. **Catch Errors**:
  //    - If an error occurs during the transfer, the function catches the error and returns `false`.
  // 7. **Return Failure**:
  //    - If the transfer is not successful, the function returns `false`.
  // In summary, the `moveCKBTC` function transfers a specified amount of ckBTC from one vault to another, handling various error cases and ensuring that the system is not paused before performing the transfer. It returns `true` if the transfer is successful and `false` otherwise.
  //
  //@dev -- whenever USDT is withdrawn from Loka USDT pool, CKBTC will be sent as payment from Miner Pool to Loka CKBTC Pool
  func moveCKBTC(amount_ : Nat) : async Bool {
    assert (_isNotPaused());

    let amountNat_ : Nat = amount_;

    /*let transferResult = await CKBTC.icrc2_transfer_from({
      from = { owner = minerCKBTCVault; subaccount = null };
      amount = amount_;
      fee = null;
      created_at_time = null;
      from_subaccount = null;
      to = { owner = lokaCKBTCVault; subaccount = null };
      spender_subaccount = null;
      memo = null;
    }); */
    try {
      let transferResult = await CKBTC.icrc1_transfer({
        amount = amount_;
        fee = ?10;
        created_at_time = null;
        from_subaccount = null;
        to = { owner = lokaCKBTCVault; subaccount = null };
        memo = null;
      });
      //var res = 0;
      var res = 0;
      switch (transferResult) {
        case (#Ok(number)) {
          return true;
        };
        case (#Err(msg)) {

          Debug.print("transfer error  ");
          switch (msg) {
            case (#BadFee(number)) {
              Debug.print("Bad Fee");
            };
            case (#GenericError(number)) {
              Debug.print("err " #number.message);
            };
            case (#InsufficientFunds(number)) {
              Debug.print("insufficient funds");
              return false;
            };
            case _ {
              Debug.print("err");
            };
          };
          res := 0;
        };
      };
    } catch (error) {
      return false;
    };

    false;
  };

  // The `send_http` function is an asynchronous function that sends an HTTP GET request to a specified URL and returns the response as a `Text`. Here's a step-by-step description of how the function works:
  // 1. **Function Signature**:
  //    - The function is declared as `async`, meaning it performs asynchronous operations.
  //    - It takes a single parameter `url_` of type `Text`, which represents the URL to which the HTTP request will be sent.
  //    - The function returns a `Text` value representing the response from the HTTP request.
  // 2. **Initialize Actor**:
  //    - The function initializes an actor `ic` of type `T.IC` with the principal `"aaaaa-aa"`, which represents the Internet Computer management canister.
  // 3. **Set URL**:
  //    - The function assigns the input parameter `url_` to a local variable `url`.
  // 4. **Set Request Headers**:
  //    - The function defines a list of HTTP request headers, including:
  //      - `User-Agent`: Identifies the client making the request.
  //      - `Content-Type`: Specifies the media type of the request.
  //      - `x-api-key`: An API key for authentication.
  //      - `F2P-API-SECRET`: A secret key for authentication.
  // 5. **Debug Print**:
  //    - The function prints a debug message indicating the URL being accessed.
  // 6. **Set Transform Context**:
  //    - The function defines a `transform_context` of type `T.TransformContext`, which includes:
  //      - `function`: A reference to the `transform` function.
  //      - `context`: An empty `Blob` context.
  // 7. **Set HTTP Request Arguments**:
  //    - The function defines an `http_request` of type `T.HttpRequestArgs`, which includes:
  //      - `url`: The URL to which the request will be sent.
  //      - `max_response_bytes`: Optional, not set in this case.
  //      - `headers`: The list of request headers.
  //      - `body`: Optional, not set in this case.
  //      - `method`: The HTTP method, set to `#get`.
  //      - `transform`: The transform context.
  // 8. **Add Cycles**:
  //    - The function adds 30 billion cycles to the request using `Cycles.add(30_000_000_000)`.
  // 9. **Send HTTP Request**:
  //    - The function sends the HTTP request using `await ic.http_request(http_request)` and stores the response in `http_response`.
  // 10. **Decode Response**:
  //     - The function converts the response body from `Blob` to `Text` using `Text.decodeUtf8`.
  //     - If the decoding is successful, it assigns the decoded text to `decoded_text`.
  //     - If the decoding fails, it assigns "No value returned" to `decoded_text`.
  // 11. **Return Response**:
  //     - The function returns the `decoded_text` as the result of the HTTP request.
  // In summary, the `send_http` function sends an HTTP GET request to a specified URL with predefined headers, processes the response, and returns the response body as a `Text`. It includes error handling for decoding the response body and adds cycles to ensure the request can be processed.
  //
  func send_http(url_ : Text) : async Text {
    let ic : T.IC = actor ("aaaaa-aa");

    let url = url_;

    let request_headers = [
      { name = "User-Agent"; value = "miner_canister" },
      { name = "Content-Type"; value = "application/json" },
      { name = "x-api-key"; value = "2021LokaInfinity" },
      { name = "F2P-API-SECRET"; value = f2poolKey },
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

  // The `natToFloat` function is a private helper function that converts a `Nat` (natural number) to a `Float` (floating-point number). Here's a step-by-step description of how the function works:
  // 1. **Function Signature**:
  //    - The function is declared as `private`, meaning it can only be called within the same module.
  //    - It takes a single parameter `nat_` of type `Nat`.
  // 2. **Convert Nat to Nat64**:
  //    - The function converts the `Nat` value `nat_` to a `Nat64` value using `Nat64.fromNat(nat_)`.
  //    - The result is stored in the variable `toNat64_`.
  // 3. **Convert Nat64 to Int64**:
  //    - The function converts the `Nat64` value `toNat64_` to an `Int64` value using `Int64.fromNat64(toNat64_)`.
  //    - The result is stored in the variable `toInt64_`.
  // 4. **Convert Int64 to Float**:
  //    - The function converts the `Int64` value `toInt64_` to a `Float` value using `Float.fromInt64(toInt64_)`.
  //    - The result is stored in the variable `amountFloat_`.
  // 5. **Return Float**:
  //    - The function returns the `Float` value `amountFloat_`.
  // In summary, the `natToFloat` function converts a `Nat` value to a `Float` value by first converting it to `Nat64`, then to `Int64`, and finally to `Float`. This conversion process ensures that the `Nat` value is accurately represented as a floating-point number.
  //
  private func natToFloat(nat_ : Nat) : Float {
    let toNat64_ = Nat64.fromNat(nat_);
    let toInt64_ = Int64.fromNat64(toNat64_);
    let amountFloat_ = Float.fromInt64(toInt64_);
    return amountFloat_;
  };

  // The `getMiner` function is a helper function that retrieves the miner associated with a given wallet principal. Here's a step-by-step description of how the function works:
  // 1. **Function Signature**:
  //    - The function takes a single parameter `wallet_` of type `Principal`, which represents the wallet principal of the miner.
  //    - The function returns a variant type with two possible values: `#none` if the miner is not found, or `#ok : T.Miner` if the miner is found.
  // 2. **Initialize Variables**:
  //    - The function initializes a variable `miner_id` of type `Nat` to 0.
  //    - It also defines an `emptyMiner` object with default values, which is used as a placeholder.
  // 3. **Retrieve Miner**:
  //    - The function attempts to retrieve the miner associated with the given wallet principal from the `minerHash` hash map using `Principal.toText(wallet_)`.
  // 4. **Check Miner Existence**:
  //    - The function uses a `switch` statement to check if the miner exists:
  //      - If the result is `?m`, it means the miner exists, and the function returns `#ok(m)`.
  //      - If the result is `null`, it means the miner does not exist, and the function returns `#none`.
  // In summary, the `getMiner` function retrieves the miner associated with a given wallet principal from the `minerHash` hash map. It returns `#ok` with the miner data if the miner is found, or `#none` if the miner is not found.
  //
  func getMiner(wallet_ : Principal) : { #none; #ok : T.Miner } {
    var miner_id : Nat = 0;
    let emptyMiner = {
      id = 0;
      walletAddress = siteAdmin;
      var username = "<empty>";
      hashrate = 0;
    };
    let miner_ = minerHash.get(Principal.toText(wallet_));
    switch (miner_) {
      case (?m) {
        return #ok(m);
      };
      case (null) {
        return #none;
      };
    };
  };

  // The `getUsername` function is a public shared asynchronous function that retrieves all usernames and their corresponding IDs. Here's a step-by-step description of how the function works:
  // 1. **Function Signature**:
  //    - The function is declared as `public shared (message)`, meaning it can be called by external actors.
  //    - It takes no parameters.
  //    - The function returns an array of tuples `[(Text, Nat)]`, where each tuple contains a username and its corresponding ID.
  // 2. **Admin Check**:
  //    - The function ensures that the caller is an admin by calling `assert(_isAdmin(message.caller))`.
  // 3. **Retrieve Usernames**:
  //    - The function retrieves all entries from `usernameHash`, which is a hash map storing usernames and their corresponding IDs.
  // 4. **Convert to Array**:
  //    - The function converts the entries from the hash map into an array using `Iter.toArray(usernameHash.entries())`.
  // 5. **Return Usernames**:
  //    - The function returns the array of usernames and their corresponding IDs.
  // In summary, the `getUsername` function retrieves all usernames and their corresponding IDs, ensuring that only admins can perform this operation. It returns the data in an array of tuples format.
  //
  public shared (message) func getUsername() : async [(Text, Nat)] {
    assert (_isAdmin(message.caller));
    return Iter.toArray(usernameHash.entries());
  };

  // Still building the workspace index, response may be less accurate.
  // The `shareRevenue` function in
  // main.mo
  //  is a public shared asynchronous function that allows a user to share a percentage of their revenue with another user. Here's a detailed description of how the function works:
  // 1. **Function Signature**:
  //    - The function is declared as `public shared (message)`, meaning it can be called by external actors and does not modify the state.
  //    - It takes two parameters: `userName` of type `Text` and `hashPercent_` of type `Nat`.
  //    - The function returns a variant type with two possible values: `#success : Nat` if the operation is successful, or `#failed : Text` if the operation fails.
  // 2. **Input Validation**:
  //    - The function checks if `hashPercent_` is within the valid range (0, or between 100 and 10000). If not, it returns `#failed("Must 0, less than 100 and more than 1%")`.
  // 3. **Caller Verification**:
  //    - The function asserts that the caller's address is verified using the `_isAddressVerified` function.
  // 4. **Miner Existence Check**:
  //    - The function retrieves the miner associated with the caller using the `getMiner` function.
  //    - If the miner does not exist, it returns `#failed("user not exist")`.
  //    - If the miner exists, it assigns the miner's username to `callerName_`.
  // 5. **Self-Share Check**:
  //    - The function checks if the caller is trying to share revenue with themselves. If so, it returns `#failed("share target cannot be yourself")`.
  // 6. **Target User Existence Check**:
  //    - The function checks if the target user exists in the `usernameHash`.
  //    - If the target user does not exist, it returns `#failed("target user not exist")`.
  // 7. **Revenue Sharing Logic**:
  //    - If the target user exists, the function retrieves the miner associated with the target user.
  //    - It creates a `share_` object containing the target user's name, wallet address, and share percentage.
  // 8. **Existing Share Check**:
  //    - The function checks if the caller has already shared revenue with other users.
  //    - If so, it calculates the total shared percentage and ensures it does not exceed 100%.
  //    - It updates the `revenueShareHash` and `receivedRevenueShareHash` accordingly.
  // 9. **New Share Creation**:
  //    - If the caller has not shared revenue before, it creates a new `detailedHash` and updates the `revenueShareHash` and `receivedRevenueShareHash`.
  // 10. **Return Success**:
  //     - If all checks pass and the revenue share is successfully updated, the function returns `#success(hashPercent_)`.
  // The function ensures that revenue sharing is done correctly, with proper validation and checks to prevent errors and misuse.
  //
  public shared (message) func shareRevenue(userName : Text, hashPercent_ : Nat) : async {
    #success : Nat;
    #failed : Text;
    #res : [(Text, T.RevenueShare)];
  } {
    //assert if miner exist
    //check if targetusername exist
    //
    if ((hashPercent_ <= 10000 and hashPercent_ >= 100) or hashPercent_ == 0) {} else {
      return #failed("Must 0, less than 100 and more than 1%");
    };
    assert (_isAddressVerified(message.caller));

    let res_ = getMiner(message.caller);
    var callerName_ = "";
    switch (res_) {
      case (#none) {
        return #failed("user not exist");
      };
      case (#ok(m)) {
        callerName_ := m.username;
      };
    };

    if (callerName_ == userName) {
      return #failed("share target cannot be yourself");
    };

    switch (usernameHash.get(userName)) {
      case (?minerId) {

        let miner_ = miners.get(minerId);
        var share_ = {
          userName = userName;
          wallet = Principal.toText(miner_.walletAddress);
          sharePercent = hashPercent_;
        };

        switch (revenueShareHash.get(callerName_)) {
          case (?list) {
            var currentShared = 0;
            for (shareItem in list.vals()) {
              currentShared += shareItem.1.sharePercent;
            };

            if (currentShared + hashPercent_ < 10000) {} else {
              return #failed("Total shared exceeds 100%");
            };

            var detailedHash = HashMap.fromIter<Text, T.RevenueShare>(list.vals(), 1, Text.equal, Text.hash);
            //return #res(list);
            if (hashPercent_ > 0) detailedHash.put(userName, share_);
            if (hashPercent_ == 0) detailedHash.delete(userName);
            revenueShareHash.put(callerName_, Iter.toArray(detailedHash.entries()));

            var receivedShare_ = {
              userName = callerName_;
              wallet = Principal.toText(message.caller);
              sharePercent = hashPercent_;
            };
            switch (receivedRevenueShareHash.get(userName)) {
              case (?receivedList) {
                var receivedHash = HashMap.fromIter<Text, T.RevenueShare>(receivedList.vals(), 1, Text.equal, Text.hash);
                if (hashPercent_ > 0) receivedHash.put(callerName_, receivedShare_);
                if (hashPercent_ == 0) receivedHash.delete(callerName_);
                receivedRevenueShareHash.put(userName, Iter.toArray(receivedHash.entries()));
              };
              case (null) {
                var receivedHash = HashMap.HashMap<Text, T.RevenueShare>(0, Text.equal, Text.hash);
                if (hashPercent_ > 0) {
                  receivedHash.put(callerName_, receivedShare_);

                  receivedRevenueShareHash.put(userName, Iter.toArray(receivedHash.entries()));
                };
              };
            };

          };
          case (null) {

            var detailedHash = HashMap.HashMap<Text, T.RevenueShare>(0, Text.equal, Text.hash);
            if (hashPercent_ > 0) detailedHash.put(userName, share_);
            if (hashPercent_ == 0) return #failed("cannot be 0 percent");
            detailedHash.put(userName, share_);
            //var detailedHashArray = Iter.toArray(detailedHash.entries());
            revenueShareHash.put(callerName_, Iter.toArray(detailedHash.entries()));
            //return #failed(callerName_);
            var receivedShare_ = {
              userName = callerName_;
              wallet = Principal.toText(message.caller);
              sharePercent = hashPercent_;
            };
            switch (receivedRevenueShareHash.get(userName)) {
              case (?receivedList) {
                var receivedHash = HashMap.fromIter<Text, T.RevenueShare>(receivedList.vals(), 1, Text.equal, Text.hash);
                receivedHash.put(callerName_, receivedShare_);
                receivedRevenueShareHash.put(userName, Iter.toArray(receivedHash.entries()));
              };
              case (null) {
                var receivedHash = HashMap.HashMap<Text, T.RevenueShare>(0, Text.equal, Text.hash);
                receivedHash.put(callerName_, receivedShare_);
                receivedRevenueShareHash.put(userName, Iter.toArray(receivedHash.entries()));
              };
            };
          };
        };
        return #success(hashPercent_);
      };
      case (null) {
        return #failed("target user not exist");
      };
    };
    //let miner_ = miners.get(p);

  };

  // The `getMinerData` function is a public query function that retrieves detailed information about the miner associated with the caller. Here's a step-by-step description of how the function works:
  // 1. **Function Signature**:
  //    - The function is declared as `public query`, meaning it can be called by external actors and does not modify the state.
  //    - It takes no parameters.
  //    - The function returns a variant type with two possible values: `#none : Nat` if the miner is not found or not verified, or `#ok : T.MinerData` if the miner is found.
  // 2. **Verify Address**:
  //    - The function checks if the caller's address is verified by calling `_isAddressVerified(message.caller)`.
  //    - If the address is not verified, the function returns `#none(0)`.
  // 3. **Get Miner**:
  //    - The function calls `getMiner(message.caller)` to retrieve the miner associated with the caller.
  //    - The result is stored in the variable `res_`.
  // 4. **Check Miner Existence**:
  //    - The function uses a `switch` statement to check if the miner exists:
  //      - If the result is `#none`, it means the miner does not exist, and the function returns `#none(1)`.
  //      - If the result is `#ok(m)`, it means the miner exists, and the miner's ID is stored in the variable `id_`.
  // 5. **Get Miner Status**:
  //    - The function retrieves the miner's status using `minerStatus.get(id_)` and stores it in the variable `status_`.
  // 6. **Retrieve Revenue History**:
  //    - The function initializes `revenueHistory_` as an empty array and `yesterdayRevenue_` as 0.
  //    - It checks if there is revenue history for the miner using `revenueHash.get(Principal.toText(m.walletAddress))`.
  //    - If revenue history exists, it updates `revenueHistory_` and sets `yesterdayRevenue_` to the last entry's sats value.
  // 7. **Retrieve Current Shared Revenue**:
  //    - The function initializes `currentShared` as 0 and `shareList_` as an empty list.
  //    - It checks if there are revenue sharing rules for the miner using `revenueShareHash.get(m.username)`.
  //    - If revenue sharing rules exist, it updates `currentShared` and `shareList_` with the relevant data.
  // 8. **Retrieve Received Shared Revenue**:
  //    - The function initializes `receivedShareList_` as an empty list.
  //    - It checks if there are received revenue sharing rules for the miner using `receivedRevenueShareHash.get(m.username)`.
  //    - If received revenue sharing rules exist, it updates `receivedShareList_` with the relevant data.
  // 9. **Adjust Balance**:
  //    - The function adjusts the miner's balance by subtracting 10 if the balance is greater than 10. Otherwise, it sets the balance to 0.
  // 10. **Construct Miner Data**:
  //     - The function constructs a `T.MinerData` object with the retrieved and calculated data, including:
  //       - `id`, `walletAddress`, `walletAddressText`, `username`, `hashrate`, `verified`, `balance`, `totalWithdrawn`, `totalReceivedSharedRevenue`, `receivedShareList`, `savedWalletAddress`, `bankAddress`, `transactions`, `revenueHistory`, `yesterdayRevenue`, `totalSharedPercent`, and `shareList`.
  // 11. **Return Miner Data**:
  //     - The function returns `#ok(minerData)` to indicate that the miner was found and includes the detailed miner data.
  // In summary, the `getMinerData` function retrieves detailed information about the miner associated with the caller, including their status, revenue history, shared revenue, and wallet addresses. It ensures that the caller's address is verified and returns the miner's data in a structured format. If the miner is not found or not verified, it returns `#none`.
  //
  public query (message) func getMinerData() : async {
    #none : Nat;
    #ok : T.MinerData;
  } {

    if (_isAddressVerified(message.caller) == false) return #none(0);
    //let miner_ = getMiner(message.caller);
    let res_ = getMiner(message.caller);
    var id_ = 0;
    var revenueHistory_ : [T.DistributionHistory] = [];
    var yesterdayRevenue_ = 0;
    switch (res_) {
      case (#none) {
        return #none(1);
      };
      case (#ok(m)) {
        id_ := m.id;
        let status_ = minerStatus.get(id_);
        switch (revenueHash.get(Principal.toText(m.walletAddress))) {
          case (?r) {
            revenueHistory_ := r;
            if (Array.size(r) > 0) yesterdayRevenue_ := r[Array.size(r) -1].sats;
          };
          case (null) {

          };
        };
        var currentShared = 0;
        var currentReceivedShare = 0;
        var shareList_ : [(Text, T.RevenueShare)] = [];

        switch (revenueShareHash.get(m.username)) {
          case (?list) {

            for (shareItem in list.vals()) {
              currentShared += shareItem.1.sharePercent;
            };
            shareList_ := list;
          };
          case (null) {
            currentShared := 0;
          };
        };
        var receivedShareList_ : [(Text, T.RevenueShare)] = [];
        switch (receivedRevenueShareHash.get(m.username)) {
          case (?list) {

            receivedShareList_ := list;
          };
          case (null) {

          };
        };
        var cB = status_.balance;
        if (cB > 10) {
          cB := cB - 10;
        } else {
          cB := 0;
        };

        let minerData : T.MinerData = {
          id = id_;
          walletAddress = m.walletAddress;
          walletAddressText = Principal.toText(m.walletAddress);
          username = m.username;
          hashrate = m.hashrate;
          verified = status_.verified;
          balance = cB;
          //balance = 100000000;
          totalWithdrawn = status_.totalWithdrawn;
          totalReceivedSharedRevenue = status_.totalSharedRevenue;
          receivedShareList = receivedShareList_;
          savedWalletAddress = status_.walletAddress;
          bankAddress = status_.bankAddress;
          transactions = status_.transactions;
          revenueHistory = revenueHistory_;
          yesterdayRevenue = yesterdayRevenue_;
          totalSharedPercent = currentShared;
          shareList = shareList_;
        };
        //Debug.print("fetched 3");
        return #ok(minerData);
      };
    };
  };

  // The `fetchMinerByPrincipal` function is a public query function that retrieves detailed information about a miner based on their principal. Here's a step-by-step description of how the function works:
  // 1. **Function Signature**:
  //    - The function is declared as `public query`, meaning it can be called by external actors and does not modify the state.
  //    - It takes a single parameter `p` of type `Principal`, which represents the principal of the miner.
  //    - The function returns a variant type with two possible values: `#none : Nat` if the miner is not found, or `#ok : T.MinerData` if the miner is found.
  // 2. **Admin Check**:
  //    - The function ensures that the caller is an admin by calling `assert(_isAdmin(message.caller))`.
  // 3. **Get Miner**:
  //    - The function calls `getMiner(p)` to retrieve the miner associated with the given principal.
  //    - The result is stored in the variable `res_`.
  // 4. **Check Miner Existence**:
  //    - The function uses a `switch` statement to check if the miner exists:
  //      - If the result is `#none`, it means the miner does not exist, and the function returns `#none(1)`.
  //      - If the result is `#ok(m)`, it means the miner exists, and the miner's ID is stored in the variable `id_`.
  // 5. **Get Miner Status**:
  //    - The function retrieves the miner's status using `minerStatus.get(id_)` and stores it in the variable `status_`.
  // 6. **Retrieve Revenue History**:
  //    - The function initializes `revenueHistory_` as an empty array and `yesterdayRevenue_` as 0.
  //    - It checks if there is revenue history for the miner using `revenueHash.get(Principal.toText(m.walletAddress))`.
  //    - If revenue history exists, it updates `revenueHistory_` and sets `yesterdayRevenue_` to the last entry's sats value.
  // 7. **Retrieve Current Shared Revenue**:
  //    - The function initializes `currentShared` as 0 and `shareList_` as an empty list.
  //    - It checks if there are revenue sharing rules for the miner using `revenueShareHash.get(m.username)`.
  //    - If revenue sharing rules exist, it updates `currentShared` and `shareList_` with the relevant data.
  // 8. **Retrieve Received Shared Revenue**:
  //    - The function initializes `receivedShareList_` as an empty list.
  //    - It checks if there are received revenue sharing rules for the miner using `receivedRevenueShareHash.get(m.username)`.
  //    - If received revenue sharing rules exist, it updates `receivedShareList_` with the relevant data.
  // 9. **Construct Miner Data**:
  //    - The function constructs a `T.MinerData` object with the retrieved and calculated data, including:
  //      - `id`, `walletAddress`, `walletAddressText`, `username`, `hashrate`, `verified`, `balance`, `totalWithdrawn`, `totalReceivedSharedRevenue`, `receivedShareList`, `savedWalletAddress`, `bankAddress`, `transactions`, `revenueHistory`, `yesterdayRevenue`, `totalSharedPercent`, and `shareList`.
  // 10. **Return Miner Data**:
  //     - The function returns `#ok(minerData)` to indicate that the miner was found and includes the detailed miner data.
  // In summary, the `fetchMinerByPrincipal` function retrieves detailed information about a miner, including their status, revenue history, shared revenue, and wallet addresses, based on the provided principal. It ensures that the caller is an admin and returns the miner's data in a structured format. If the miner is not found, it returns `#none`.
  //
  public query (message) func fetchMinerByPrincipal(p : Principal) : async {
    #none : Nat;
    #ok : T.MinerData;
  } {

    assert (_isAdmin(message.caller));
    let res_ = getMiner(p);
    var id_ = 0;
    var revenueHistory_ : [T.DistributionHistory] = [];
    var yesterdayRevenue_ = 0;
    switch (res_) {
      case (#none) {
        return #none(1);
      };
      case (#ok(m)) {
        id_ := m.id;
        let status_ = minerStatus.get(id_);
        switch (revenueHash.get(Principal.toText(m.walletAddress))) {
          case (?r) {
            revenueHistory_ := r;
            if (Array.size(r) > 0) yesterdayRevenue_ := r[Array.size(r) -1].sats;

          };
          case (null) {

          };
        };

        var currentShared = 0;
        var shareList_ : [(Text, T.RevenueShare)] = [];
        switch (revenueShareHash.get((m.username))) {
          case (?list) {

            for (shareItem in list.vals()) {
              currentShared += shareItem.1.sharePercent;
            };
            shareList_ := list;
          };
          case (null) {
            currentShared := 0;
          };
        };
        var receivedShareList_ : [(Text, T.RevenueShare)] = [];
        switch (receivedRevenueShareHash.get(m.username)) {
          case (?list) {

            receivedShareList_ := list;
          };
          case (null) {

          };
        };
        let minerData : T.MinerData = {
          id = id_;
          walletAddress = m.walletAddress;
          walletAddressText = Principal.toText(m.walletAddress);
          username = m.username;
          hashrate = m.hashrate;
          verified = status_.verified;
          balance = status_.balance;
          //balance = 100000000;
          totalWithdrawn = status_.totalWithdrawn;
          totalReceivedSharedRevenue = status_.totalSharedRevenue;
          receivedShareList = receivedShareList_;
          savedWalletAddress = status_.walletAddress;
          bankAddress = status_.bankAddress;
          transactions = status_.transactions;
          revenueHistory = revenueHistory_;
          yesterdayRevenue = yesterdayRevenue_;
          totalSharedPercent = currentShared;
          shareList = shareList_;
        };
        //Debug.print("fetched 3");
        return #ok(minerData);
      };
    };

  };

  // The `adjustB` function is a public shared asynchronous function that adjusts the balance of a miner based on their username. Here's a step-by-step description of how the function works:
  // 1. **Function Signature**:
  //    - The function is declared as `public shared`, meaning it can be called by external actors.
  //    - It takes two parameters:
  //      - `uname`: The username of the miner.
  //      - `bal`: The new balance to be set for the miner.
  //    - The function returns a `Nat` indicating the new balance.
  // 2. **Admin Check**:
  //    - The function ensures that the caller is an admin by calling `assert(_isAdmin(message.caller))`.
  // 3. **Get Miner ID**:
  //    - The function initializes `p` to 0.
  //    - It retrieves the miner's ID using `usernameHash.get(uname)` and stores it in `p`.
  // 4. **Get Miner and Status**:
  //    - The function retrieves the miner's data using `miners.get(p)` and stores it in the variable `miner_`.
  //    - It retrieves the miner's status using `minerStatus.get(miner_.id)` and stores it in the variable `status_`.
  // 5. **Update Miner Balance**:
  //    - The function updates the miner's balance to the new value `bal` by setting `status_.balance := bal`.
  // 6. **Return New Balance**:
  //    - The function returns the new balance `bal` to indicate that the adjustment was successful.
  // In summary, the `adjustB` function updates the balance of a miner based on their username, ensuring that the caller is an admin and that the miner exists. It retrieves the miner's data and status, updates the balance, and returns the new balance.
  //
  public shared (message) func adjustB(uname : Text, bal : Nat) : async Nat {
    assert (_isAdmin(message.caller));
    var p = 0;
    switch (usernameHash.get(uname)) {
      case (?mid) {
        p := mid;
      };
      case (null) {

      };
    };

    let miner_ = miners.get(p);
    let status_ = minerStatus.get(miner_.id);
    status_.balance := bal;

    bal;
  };

  // The `adjustMiner` function is a public shared asynchronous function that adjusts the username and balance of a miner. Here's a step-by-step description of how the function works:
  // 1. **Function Signature**:
  //    - The function is declared as `public shared`, meaning it can be called by external actors.
  //    - It takes three parameters:
  //      - `uname`: The current username of the miner.
  //      - `newUname`: The new username to be assigned to the miner.
  //      - `balance`: The new balance to be set for the miner.
  //    - The function returns a `Nat` indicating the result of the adjustment (1 for success, 0 for failure).
  // 2. **Admin Check**:
  //    - The function ensures that the caller is an admin by calling `assert(_isAdmin(message.caller))`.
  // 3. **Get Miner ID**:
  //    - The function initializes `p` to 0.
  //    - It retrieves the miner's ID using `usernameHash.get(uname)` and stores it in `p`.
  //    - If the username is found, it deletes the old username from `usernameHash` and adds the new username with the same ID.
  //    - If the username is not found, it returns 0 to indicate failure.
  // 4. **Get Miner and Update Username**:
  //    - The function retrieves the miner's data using `miners.get(p)` and stores it in the variable `miner_`.
  //    - It updates the miner's username to `newUname`.
  // 5. **Update Miner Balance**:
  //    - The function retrieves the miner's status using `minerStatus.get(miner_.id)` and stores it in the variable `status_`.
  //    - It updates the miner's balance to the new value `balance`.
  // 6. **Return Success**:
  //    - The function returns 1 to indicate that the adjustment was successful.
  // In summary, the `adjustMiner` function updates the username and balance of a miner, ensuring that the caller is an admin and that the miner exists. If the miner is found and updated successfully, it returns 1; otherwise, it returns 0.
  //
  public shared (message) func adjustMiner(uname : Text, newUname : Text, balance : Nat) : async Nat {
    assert (_isAdmin(message.caller));
    var p = 0;
    switch (usernameHash.get(uname)) {
      case (?mid) {
        p := mid;
        usernameHash.delete(uname);
        usernameHash.put(newUname, p);
      };
      case (null) {
        return 0;
      };
    };

    let miner_ = miners.get(p);
    miner_.username := newUname;
    let status_ = minerStatus.get(miner_.id);
    status_.balance := balance;

    1;
  };

  // The `backupUserData` function is a public shared asynchronous function that creates a backup of all user data. Here's a step-by-step description of how the function works:
  // 1. **Function Signature**:
  //    - The function is declared as `public shared`, meaning it can be called by external actors.
  //    - It takes no parameters.
  //    - The function returns an array of `T.MinerData` asynchronously.
  // 2. **Admin Check**:
  //    - The function ensures that the caller is an admin by calling `assert(_isAdmin(message.caller))`.
  // 3. **Initialize Result Array**:
  //    - The function initializes an empty array `res` of type `[T.MinerData]` to store the backup data.
  // 4. **Retrieve User List**:
  //    - The function retrieves all entries from `usernameHash` and converts them to an array `listUser`.
  // 5. **Loop Through Users**:
  //    - The function iterates over each user in `listUser`.
  // 6. **Get Miner and Status**:
  //    - For each user, the function retrieves the miner's data using `miners.get(usr.1)` and stores it in the variable `miner_`.
  //    - It retrieves the miner's status using `minerStatus.get(miner_.id)` and stores it in the variable `status_`.
  // 7. **Retrieve Revenue History**:
  //    - The function initializes `revenueHistory_` as an empty array and `yesterdayRevenue_` as 0.
  //    - It checks if there is revenue history for the miner using `revenueHash.get(Principal.toText(miner_.walletAddress))`.
  //    - If revenue history exists, it updates `revenueHistory_` and sets `yesterdayRevenue_` to the last entry's sats value.
  // 8. **Retrieve Current Shared Revenue**:
  //    - The function initializes `currentShared` as 0 and `shareList_` as an empty list.
  //    - It checks if there are revenue sharing rules for the miner using `revenueShareHash.get(miner_.username)`.
  //    - If revenue sharing rules exist, it updates `currentShared` and `shareList_` with the relevant data.
  // 9. **Retrieve Received Shared Revenue**:
  //    - The function initializes `receivedShareList_` as an empty list.
  //    - It checks if there are received revenue sharing rules for the miner using `receivedRevenueShareHash.get(miner_.username)`.
  //    - If received revenue sharing rules exist, it updates `receivedShareList_` with the relevant data.
  // 10. **Construct Miner Data**:
  //     - The function constructs a `T.MinerData` object with the retrieved and calculated data, including:
  //       - `id`, `walletAddress`, `walletAddressText`, `username`, `hashrate`, `verified`, `balance`, `totalWithdrawn`, `totalReceivedSharedRevenue`, `receivedShareList`, `savedWalletAddress`, `bankAddress`, `transactions`, `revenueHistory`, `yesterdayRevenue`, `totalSharedPercent`, and `shareList`.
  // 11. **Append Miner Data to Result Array**:
  //     - The function appends the constructed `T.MinerData` object to the `res` array.
  // 12. **Return Result**:
  //     - The function returns the `res` array containing the backup data for all users.
  // In summary, the `backupUserData` function creates a backup of all user data by retrieving and compiling detailed information about each miner, including their status, revenue history, shared revenue, and wallet addresses. It ensures that only admins can perform the backup and returns the compiled data in a structured format.
  //
  public shared (message) func backupUserData() : async [T.MinerData] {
    assert (_isAdmin(message.caller));
    var res : [T.MinerData] = [];
    var listUser = Iter.toArray(usernameHash.entries());
    for (usr in listUser.vals()) {
      let miner_ = miners.get(usr.1);
      let status_ = minerStatus.get(miner_.id);
      var revenueHistory_ : [T.DistributionHistory] = [];
      var yesterdayRevenue_ = 0;
      switch (revenueHash.get(Principal.toText(miner_.walletAddress))) {
        case (?r) {
          revenueHistory_ := r;
          //let hist = Array.size(r);
          if (Array.size(r) > 0) yesterdayRevenue_ := r[Array.size(r) -1].sats;
        };
        case (null) {

        };
      };

      var currentShared = 0;
      var shareList_ : [(Text, T.RevenueShare)] = [];
      switch (revenueShareHash.get(miner_.username)) {
        case (?list) {

          for (shareItem in list.vals()) {
            currentShared += shareItem.1.sharePercent;
          };
          shareList_ := list;
        };
        case (null) {
          currentShared := 0;
        };
      };
      var receivedShareList_ : [(Text, T.RevenueShare)] = [];
      switch (receivedRevenueShareHash.get(miner_.username)) {
        case (?list) {

          receivedShareList_ := list;
        };
        case (null) {

        };
      };
      let minerData : T.MinerData = {
        id = miner_.id;
        walletAddress = miner_.walletAddress;
        walletAddressText = Principal.toText(miner_.walletAddress);
        username = miner_.username;
        hashrate = miner_.hashrate;
        verified = status_.verified;
        balance = status_.balance;
        //balance = 100000000;
        totalWithdrawn = status_.totalWithdrawn;
        totalReceivedSharedRevenue = status_.totalSharedRevenue;
        receivedShareList = receivedShareList_;
        savedWalletAddress = status_.walletAddress;
        bankAddress = status_.bankAddress;
        transactions = status_.transactions;
        revenueHistory = revenueHistory_;
        yesterdayRevenue = yesterdayRevenue_;
        totalSharedPercent = currentShared;
        shareList = shareList_;
      };
      res := Array.append<T.MinerData>(res, [minerData]);
    };
    //Debug.print("fetched 3");
    res;
  };

  // The `adjustMinerBalance` function is a public shared asynchronous function that adjusts the balance of miners based on a set of queries. Here's a step-by-step description of how the function works:
  // 1. **Function Signature**:
  //    - The function is declared as `public shared`, meaning it can be called by external actors.
  //    - It takes a single parameter `queries` of type `Text`, which contains the adjustment queries.
  //    - The function returns a `Text` indicating the result of the adjustments.
  // 2. **Admin Check**:
  //    - The function ensures that the caller is an admin by calling `assert(_isAdmin(message.caller))`.
  // 3. **Split Queries**:
  //    - The function splits the `queries` string into individual queries using the `textSplit` function with the delimiter `|`.
  //    - It initializes `totalString` and `unameString` as empty strings to accumulate results.
  // 4. **Loop Through Queries**:
  //    - The function iterates over each query in `datas_`.
  // 5. **Process Each Query**:
  //    - For each query, it splits the query into `uname` (username) and `reward` (adjustment amount) using the `textSplit` function with the delimiter `/`.
  //    - It converts the `reward` string to a `Nat` using the `textToNat` function.
  //    - It retrieves the miner's ID using `usernameHash.get(uname)` and stores it in `p`.
  // 6. **Get Miner and Status**:
  //    - The function retrieves the miner's data using `miners.get(p)` and stores it in `miner_`.
  //    - It initializes `totalShared` to 0.
  // 7. **Handle Revenue Sharing**:
  //    - The function checks if there are revenue sharing rules for the miner using `revenueShareHash.get(uname)`.
  //    - If revenue sharing rules exist, it iterates over the shared targets and adjusts their balances and total shared revenue.
  //    - It updates the `revenueHash` with the shared rewards and logs the adjustments.
  // 8. **Update Miner Revenue**:
  //    - The function creates a `T.DistributionHistory` record for the miner with the adjusted reward.
  //    - It updates the `revenueHash` with the new revenue record.
  // 9. **Update Miner Status**:
  //    - The function updates the miner's balance by subtracting the adjusted reward.
  //    - It updates the `minerStatusAndRewardHash` with the new balance and transactions.
  // 10. **Update Total Balance**:
  //     - The function updates the `totalBalance` by subtracting the reward.
  // 11. **Return Result**:
  //     - The function accumulates the results in `unameString` and `totalString`.
  //     - It returns `unameString` as the result of the adjustments.
  // In summary, the `adjustMinerBalance` function processes a set of queries to adjust the balances of miners, handles revenue sharing, updates the relevant records, and returns the result of the adjustments. It ensures that only admins can perform the adjustments and logs the changes appropriately.
  //
  public shared (message) func adjustMinerBalance(queries : Text) : async Text {
    assert (_isAdmin(message.caller));
    var datas_ = textSplit(queries, '|');
    var totalString = "";
    var unameString = "";
    //LOOP THROUGH
    for (data in datas_.vals()) {

      var ls = textSplit(data, '/');
      var uname = ls[0];
      var reward = textToNat(ls[1]); // THE DIFFERENCE
      var p = 0;

      switch (usernameHash.get(uname)) {
        case (?mid) {
          p := mid;
        };
        case (null) {

        };
      };
      let miner_ = miners.get(p);
      var totalShared = 0;

      //handles list of user being shared from this user
      switch (revenueShareHash.get(uname)) {
        case (?list) {
          unameString := unameString # uname # "-" #Nat.toText(reward) # " share to [-";
          totalString := totalString # "[-";
          for (shareItem in list.vals()) {
            switch (usernameHash.get(shareItem.1.userName)) {
              case (?theId) {
                let sharedTarget = minerStatus.get(theId);
                var sharedReward = (reward * shareItem.1.sharePercent) / 10000;

                sharedTarget.balance -= sharedReward;
                sharedTarget.totalSharedRevenue -= sharedReward;
                totalShared += sharedReward;
                unameString := unameString #shareItem.1.userName # "<>" #Nat.toText(sharedReward) # "|";
                totalString := totalString # " shared - " #Nat.toText(sharedReward) # "|";
                switch (minerStatusAndRewardHash.get(Nat.toText(sharedTarget.id))) {
                  case (?mStat) {
                    mStat.balance := sharedTarget.balance;
                    mStat.transactions := sharedTarget.transactions;
                    mStat.totalSharedRevenue := sharedTarget.totalSharedRevenue;
                  };
                  case (null) {

                  };
                };

                let rev : [T.DistributionHistory] = [{
                  time = now();
                  hashrate = 0;
                  sats = sharedReward;
                  from = "adjustment ";
                  fromUsername = uname;
                }];
                //transfer sharedMTPS
                //var ckBTCBalance : Nat = (await CKBTC.icrc1_balance_of({ owner = Principal.fromActor(this); subaccount = null }));

                switch (revenueHash.get(shareItem.1.wallet)) {
                  case (?r) {
                    revenueHash.put(shareItem.1.wallet, Array.append<T.DistributionHistory>(r, rev));

                  };
                  case (null) {
                    revenueHash.put(shareItem.1.wallet, rev);
                  };
                };
              };
              case (null) {

              };
            };

          };
          unameString := unameString # "-]|";
          totalString := totalString # "-]|";

        };
        case (null) {

        };
      };
      let rev : [T.DistributionHistory] = [{
        time = now();
        hashrate = 0;
        sats = reward - totalShared;
        from = "adjustment";
        fromUsername = "adjustment";
      }];

      switch (revenueHash.get(Principal.toText(miner_.walletAddress))) {
        case (?r) {
          revenueHash.put(Principal.toText(miner_.walletAddress), Array.append<T.DistributionHistory>(r, rev));

        };
        case (null) {
          revenueHash.put(Principal.toText(miner_.walletAddress), rev);
        };
      };
      unameString := unameString #uname # " nett >>" #Nat.toText(reward - totalShared) # "|";
      totalString := totalString #Nat.toText(totalShared) # "|";

      let status_ = minerStatus.get(miner_.id);
      status_.balance -= (reward - totalShared);
      /*
       id : Nat;
        var verified : Bool;
        var balance : Nat;
        var totalWithdrawn : Nat;
        var walletAddress : [WalletAddress];
        var bankAddress : [BankAddress];
        var transactions : [TransactionHistory];
        var totalSharedRevenue : Nat;
      */
      switch (minerStatusAndRewardHash.get(Nat.toText(miner_.id))) {
        case (?mStat) {
          mStat.balance := status_.balance;
          mStat.transactions := status_.transactions;
          mStat.totalSharedRevenue := status_.totalSharedRevenue;
        };
        case (null) {

        };
      };
      totalBalance -= reward;

    };
    unameString;
  };

  func toLower(t : Text) : Text {
    let r = Text.map(t, Prim.charToLower);
    return r;
  };

  // The `fetchMinerByUsername` function is a public query function that retrieves detailed information about a miner based on their username. Here's a step-by-step description of how the function works:
  // 1. **Function Signature**:
  //    - The function is declared as `public query`, meaning it can be called by external actors and does not modify the state.
  //    - It takes a single parameter `uname` of type `Text`, which represents the username of the miner.
  //    - The function returns a variant type with two possible values: `#none : Nat` if the miner is not found, or `#ok : T.MinerData` if the miner is found.
  // 2. **Admin Check**:
  //    - The function ensures that the caller is an admin by calling `assert(_isAdmin(message.caller))`.
  // 3. **Initialize Variables**:
  //    - The function initializes `yesterdayRevenue_` to 0 and `p` to 0.
  // 4. **Get Miner ID**:
  //    - The function retrieves the miner's ID using `usernameHash.get(uname)` and stores it in the variable `p`.
  //    - If the username is not found, `p` remains 0.
  // 5. **Get Miner and Status**:
  //    - The function retrieves the miner's data using `miners.get(p)` and stores it in the variable `miner_`.
  //    - It retrieves the miner's status using `minerStatus.get(miner_.id)` and stores it in the variable `status_`.
  // 6. **Retrieve Revenue History**:
  //    - The function initializes `revenueHistory_` as an empty array.
  //    - It checks if there is revenue history for the miner using `revenueHash.get(Principal.toText(miner_.walletAddress))`.
  //    - If revenue history exists, it updates `revenueHistory_` and sets `yesterdayRevenue_` to the last entry's sats value.
  // 7. **Retrieve Current Shared Revenue**:
  //    - The function initializes `currentShared` as 0 and `shareList_` as an empty list.
  //    - It checks if there are revenue sharing rules for the miner using `revenueShareHash.get(miner_.username)`.
  //    - If revenue sharing rules exist, it updates `currentShared` and `shareList_` with the relevant data.
  // 8. **Retrieve Received Shared Revenue**:
  //    - The function initializes `receivedShareList_` as an empty list.
  //    - It checks if there are received revenue sharing rules for the miner using `receivedRevenueShareHash.get(miner_.username)`.
  //    - If received revenue sharing rules exist, it updates `receivedShareList_` with the relevant data.
  // 9. **Construct Miner Data**:
  //    - The function constructs a `T.MinerData` object with the retrieved and calculated data, including:
  //      - `id`, `walletAddress`, `walletAddressText`, `username`, `hashrate`, `verified`, `balance`, `totalWithdrawn`, `totalReceivedSharedRevenue`, `receivedShareList`, `savedWalletAddress`, `bankAddress`, `transactions`, `revenueHistory`, `yesterdayRevenue`, `totalSharedPercent`, and `shareList`.
  // 10. **Return Miner Data**:
  //     - The function returns `#ok(minerData)` to indicate that the miner was found and includes the detailed miner data.
  // In summary, the `fetchMinerByUsername` function retrieves detailed information about a miner, including their status, revenue history, shared revenue, and wallet addresses, based on the provided username. It ensures that the caller is an admin and returns the miner's data in a structured format. If the miner is not found, it returns `#none`.
  //
  public query (message) func fetchMinerByUsername(uname : Text) : async {
    #none : Nat;
    #ok : T.MinerData;
  } {

    assert (_isAdmin(message.caller));

    var yesterdayRevenue_ = 0;
    var p = 0;
    switch (usernameHash.get(uname)) {
      case (?mid) {
        p := mid;
      };
      case (null) {

      };
    };

    let miner_ = miners.get(p);
    let status_ = minerStatus.get(miner_.id);
    var revenueHistory_ : [T.DistributionHistory] = [];
    switch (revenueHash.get(Principal.toText(miner_.walletAddress))) {
      case (?r) {
        revenueHistory_ := r;
        //let hist = Array.size(r);
        if (Array.size(r) > 0) yesterdayRevenue_ := r[Array.size(r) -1].sats;
      };
      case (null) {

      };
    };

    var currentShared = 0;
    var shareList_ : [(Text, T.RevenueShare)] = [];
    switch (revenueShareHash.get(miner_.username)) {
      case (?list) {

        for (shareItem in list.vals()) {
          currentShared += shareItem.1.sharePercent;
        };
        shareList_ := list;
      };
      case (null) {
        currentShared := 0;
      };
    };
    var receivedShareList_ : [(Text, T.RevenueShare)] = [];
    switch (receivedRevenueShareHash.get(miner_.username)) {
      case (?list) {

        receivedShareList_ := list;
      };
      case (null) {

      };
    };
    let minerData : T.MinerData = {
      id = miner_.id;
      walletAddress = miner_.walletAddress;
      walletAddressText = Principal.toText(miner_.walletAddress);
      username = miner_.username;
      hashrate = miner_.hashrate;
      verified = status_.verified;
      balance = status_.balance;
      //balance = 100000000;
      totalWithdrawn = status_.totalWithdrawn;
      totalReceivedSharedRevenue = status_.totalSharedRevenue;
      receivedShareList = receivedShareList_;
      savedWalletAddress = status_.walletAddress;
      bankAddress = status_.bankAddress;
      transactions = status_.transactions;
      revenueHistory = revenueHistory_;
      yesterdayRevenue = yesterdayRevenue_;
      totalSharedPercent = currentShared;
      shareList = shareList_;
    };
    //Debug.print("fetched 3");
    #ok(minerData);
  };

  // The `fetchMinerById` function is a public query function that retrieves detailed information about a miner based on their ID. Here's a step-by-step description of how the function works:
  // 1. **Function Signature**:
  //    - The function is declared as `public query`, meaning it can be called by external actors and does not modify the state.
  //    - It takes a single parameter `p` of type `Nat` (natural number), which represents the ID of the miner.
  //    - The function returns a `T.MinerData` object asynchronously.
  // 2. **Admin Check**:
  //    - The function ensures that the caller is an admin by calling `assert(_isAdmin(message.caller))`.
  // 3. **Get Miner and Status**:
  //    - The function retrieves the miner's data using `miners.get(p)` and stores it in the variable `miner_`.
  //    - It retrieves the miner's status using `minerStatus.get(miner_.id)` and stores it in the variable `status_`.
  // 4. **Retrieve Revenue History**:
  //    - The function initializes `revenueHistory_` as an empty array and `yesterdayRevenue_` as 0.
  //    - It checks if there is revenue history for the miner using `revenueHash.get(Principal.toText(miner_.walletAddress))`.
  //    - If revenue history exists, it updates `revenueHistory_` and sets `yesterdayRevenue_` to the last entry's sats value.
  // 5. **Retrieve Current Shared Revenue**:
  //    - The function initializes `currentShared` as 0 and `shareList_` as an empty list.
  //    - It checks if there are revenue sharing rules for the miner using `revenueShareHash.get(miner_.username)`.
  //    - If revenue sharing rules exist, it updates `currentShared` and `shareList_` with the relevant data.
  // 6. **Retrieve Received Shared Revenue**:
  //    - The function initializes `receivedShareList_` as an empty list.
  //    - It checks if there are received revenue sharing rules for the miner using `receivedRevenueShareHash.get(miner_.username)`.
  //    - If received revenue sharing rules exist, it updates `receivedShareList_` with the relevant data.
  // 7. **Construct Miner Data**:
  //    - The function constructs a `T.MinerData` object with the retrieved and calculated data, including:
  //      - `id`, `walletAddress`, `walletAddressText`, `username`, `hashrate`, `verified`, `balance`, `totalWithdrawn`, `totalReceivedSharedRevenue`, `receivedShareList`, `savedWalletAddress`, `bankAddress`, `transactions`, `revenueHistory`, `yesterdayRevenue`, `totalSharedPercent`, and `shareList`.
  // 8. **Return Miner Data**:
  //    - The function returns the constructed `T.MinerData` object.
  // In summary, the `fetchMinerById` function retrieves detailed information about a miner, including their status, revenue history, shared revenue, and wallet addresses, based on the provided miner ID. It ensures that the caller is an admin and returns the miner's data in a structured format.
  //
  public query (message) func fetchMinerById(p : Nat) : async T.MinerData {

    assert (_isAdmin(message.caller));
    let miner_ = miners.get(p);
    let status_ = minerStatus.get(miner_.id);
    var revenueHistory_ : [T.DistributionHistory] = [];
    var yesterdayRevenue_ = 0;
    switch (revenueHash.get(Principal.toText(miner_.walletAddress))) {
      case (?r) {
        revenueHistory_ := r;
        //let hist = Array.size(r);
        if (Array.size(r) > 0) yesterdayRevenue_ := r[Array.size(r) -1].sats;
      };
      case (null) {

      };
    };

    var currentShared = 0;
    var shareList_ : [(Text, T.RevenueShare)] = [];
    switch (revenueShareHash.get(miner_.username)) {
      case (?list) {

        for (shareItem in list.vals()) {
          currentShared += shareItem.1.sharePercent;
        };
        shareList_ := list;
      };
      case (null) {
        currentShared := 0;
      };
    };
    var receivedShareList_ : [(Text, T.RevenueShare)] = [];
    switch (receivedRevenueShareHash.get(miner_.username)) {
      case (?list) {

        receivedShareList_ := list;
      };
      case (null) {

      };
    };
    let minerData : T.MinerData = {
      id = miner_.id;
      walletAddress = miner_.walletAddress;
      walletAddressText = Principal.toText(miner_.walletAddress);
      username = miner_.username;
      hashrate = miner_.hashrate;
      verified = status_.verified;
      balance = status_.balance;
      //balance = 100000000;
      totalWithdrawn = status_.totalWithdrawn;
      totalReceivedSharedRevenue = status_.totalSharedRevenue;
      receivedShareList = receivedShareList_;
      savedWalletAddress = status_.walletAddress;
      bankAddress = status_.bankAddress;
      transactions = status_.transactions;
      revenueHistory = revenueHistory_;
      yesterdayRevenue = yesterdayRevenue_;
      totalSharedPercent = currentShared;
      shareList = shareList_;
    };
    //Debug.print("fetched 3");
    minerData;
  };

  // The `getWallets` function is a public query function that retrieves the wallet addresses associated with a specific miner. Here's a step-by-step description of how the function works:
  // 1. **Function Signature**:
  //    - The function is declared as `public query`, meaning it can be called by external actors and does not modify the state.
  //    - It takes a single parameter `id_` of type `Nat` (natural number), which represents the ID of the miner.
  //    - The function returns an array of `T.WalletAddress` asynchronously.
  // 2. **Get Miner Status**:
  //    - The function retrieves the miner's status using `minerStatus.get(id_)` and stores it in the variable `miner_`.
  // 3. **Return Wallet Addresses**:
  //    - The function returns the `walletAddress` field from the miner's status, which is an array of `T.WalletAddress`.
  // In summary, the `getWallets` function retrieves and returns the wallet addresses associated with a specific miner based on the provided miner ID. It ensures that the function is a query, meaning it does not modify the state and can be called by external actors.
  //
  public query (message) func getWallets(id_ : Nat) : async [T.WalletAddress] {

    let miner_ = minerStatus.get(id_);
    miner_.walletAddress;
  };

  // The `saveWalletAddress` function is a public shared asynchronous function that saves a wallet address for the miner associated with the caller. Here's a step-by-step description of how the function works:
  // 1. **Function Signature**:
  //    - The function is declared as `public shared`, meaning it can be called by external actors.
  //    - It takes three parameters:
  //      - `name_`: The name associated with the wallet address.
  //      - `address_`: The wallet address.
  //      - `currency_`: The currency associated with the wallet address.
  //    - The function returns a `Bool` indicating success (`true`) or failure (`false`).
  // 2. **Verify Address**:
  //    - The function ensures that the caller's address is verified by calling `assert(_isAddressVerified(message.caller))`.
  // 3. **Get Miner**:
  //    - The function calls `getMiner(message.caller)` to retrieve the miner associated with the caller.
  //    - The result is stored in the variable `res_`.
  // 4. **Check Miner Existence**:
  //    - The function uses a `switch` statement to check if the miner exists:
  //      - If the result is `#none`, it means the miner does not exist, and the function returns `false`.
  //      - If the result is `#ok(m)`, it means the miner exists, and the miner's ID is stored in the variable `id_`.
  // 5. **Get Miner Status**:
  //    - The function retrieves the miner's status using `minerStatus.get(id_)` and stores it in the variable `status_`.
  // 6. **Check for Existing Wallet Address**:
  //    - The function checks if the wallet address already exists in the miner's wallet addresses using `Array.find`.
  //    - If the wallet address is found, the function asserts `isthere == null` to ensure it does not already exist.
  // 7. **Create Wallet Address**:
  //    - The function creates a new wallet address record with the provided details and stores it in the variable `wallet_`.
  // 8. **Append Wallet Address**:
  //    - The function appends the new wallet address to the miner's existing wallet addresses using `Array.append`.
  // 9. **Return Success**:
  //    - The function returns `true` to indicate that the wallet address was successfully saved.
  // In summary, the `saveWalletAddress` function saves a new wallet address for the miner associated with the caller, ensuring that the caller's address is verified and that the wallet address does not already exist. If the miner does not exist, it returns `false`; otherwise, it saves the wallet address and returns `true`.
  //
  public shared (message) func saveWalletAddress(name_ : Text, address_ : Text, currency_ : Text) : async Bool {
    assert (_isAddressVerified(message.caller));
    //let miner_ = getMiner(message.caller);
    let res_ = getMiner(message.caller);
    var id_ = 0;
    switch (res_) {
      case (#none) {
        return false;
      };
      case (#ok(m)) {
        id_ := m.id;
      };
    };
    let status_ = minerStatus.get(id_);
    let isthere = Array.find<T.WalletAddress>(status_.walletAddress, func wallet = wallet.address == address_);
    assert (isthere == null);
    let wallet_ : [T.WalletAddress] = [{
      name = name_;
      address = address_;
      currency = currency_;
    }];
    status_.walletAddress := Array.append<T.WalletAddress>(status_.walletAddress, wallet_);
    true;
  };

  // The `saveBankAddress` function is a public shared asynchronous function that saves a bank address for the miner associated with the caller. Here's a step-by-step description of how the function works:
  // 1. **Function Signature**:
  //    - The function is declared as `public shared`, meaning it can be called by external actors.
  //    - It takes four parameters:
  //      - `name_`: The name associated with the bank account.
  //      - `account_`: The bank account number.
  //      - `bankName_`: The name of the bank.
  //      - `jwalletId_`: The jwallet ID associated with the bank account.
  //    - The function returns a `Bool` indicating success (`true`) or failure (`false`).
  // 2. **Verify Address**:
  //    - The function ensures that the caller's address is verified by calling `assert(_isAddressVerified(message.caller))`.
  // 3. **Get Miner**:
  //    - The function calls `getMiner(message.caller)` to retrieve the miner associated with the caller.
  //    - The result is stored in the variable `res_`.
  // 4. **Check Miner Existence**:
  //    - The function uses a `switch` statement to check if the miner exists:
  //      - If the result is `#none`, it means the miner does not exist, and the function returns `false`.
  //      - If the result is `#ok(m)`, it means the miner exists, and the miner's ID is stored in the variable `id_`.
  // 5. **Get Miner Status**:
  //    - The function retrieves the miner's status using `minerStatus.get(id_)` and stores it in the variable `status_`.
  // 6. **Check for Existing Bank Account**:
  //    - The function checks if the bank account already exists in the miner's bank addresses using `Array.find`.
  //    - If the bank account is found, the function asserts `isthere == null` to ensure it does not already exist.
  // 7. **Create Bank Address**:
  //    - The function creates a new bank address record with the provided details and stores it in the variable `bank_`.
  // 8. **Append Bank Address**:
  //    - The function appends the new bank address to the miner's existing bank addresses using `Array.append`.
  // 9. **Return Success**:
  //    - The function returns `true` to indicate that the bank address was successfully saved.
  // In summary, the `saveBankAddress` function saves a new bank address for the miner associated with the caller, ensuring that the caller's address is verified and that the bank account does not already exist. If the miner does not exist, it returns `false`; otherwise, it saves the bank address and returns `true`.
  //
  public shared (message) func saveBankAddress(name_ : Text, account_ : Text, bankName_ : Text, jwalletId_ : Text) : async Bool {
    assert (_isAddressVerified(message.caller));
    let res_ = getMiner(message.caller);
    var id_ = 0;
    switch (res_) {
      case (#none) {
        return false;
      };
      case (#ok(m)) {
        id_ := m.id;
      };
    };
    let status_ = minerStatus.get(id_);
    let isthere = Array.find<T.BankAddress>(status_.bankAddress, func bank = bank.accountNumber == account_);
    assert (isthere == null);
    let bank_ : [T.BankAddress] = [{
      name = name_;
      accountNumber = account_;
      bankName = bankName_;
      jwalletId = jwalletId_;
    }];
    status_.bankAddress := Array.append<T.BankAddress>(status_.bankAddress, bank_);
    true;
  };

  // The `textToFloat` function converts a given text representation of a number into a floating-point number. Here's a step-by-step description of how the function works:
  // 1. **Function Signature**:
  //    - The function takes a single parameter `t` of type `Text` and returns a `Float`.
  // 2. **Initialize Variables**:
  //    - `i`: A `Float` initialized to 1, used to keep track of the position of digits after the decimal point.
  //    - `f`: A `Float` initialized to 0, used to accumulate the resulting floating-point number.
  //    - `isDecimal`: A `Bool` initialized to `false`, used to indicate whether the function has encountered a decimal point.
  // 3. **Iterate Over Characters**:
  //    - The function iterates over each character `c` in the text `t` using a `for` loop.
  // 4. **Check if Character is a Digit**:
  //    - If the character `c` is a digit:
  //      - Convert the character to a `Nat64` value (`charToNat`).
  //      - Convert the `Nat64` value to a `Float` value (`natToFloat`).
  //      - If `isDecimal` is `true`:
  //        - Divide `natToFloat` by `10` raised to the power of `i` and add the result to `f`.
  //      - If `isDecimal` is `false`:
  //        - Multiply `f` by 10 and add `natToFloat` to `f`.
  //      - Increment `i` by 1.
  // 5. **Check if Character is a Decimal Point**:
  //    - If the character `c` is a decimal point (`.` or `,`):
  //      - Force `f` to be a decimal by dividing and then multiplying it by `10` raised to the power of `i`.
  //      - Set `isDecimal` to `true`.
  //      - Reset `i` to 1.
  // 6. **Handle Non-Digit and Non-Decimal Characters**:
  //    - If the character `c` is neither a digit nor a decimal point:
  //      - Return `0.0` to indicate an invalid input.
  // 7. **Return Result**:
  //    - After processing all characters, return the accumulated floating-point number `f`.
  // In summary, the `textToFloat` function processes each character in the input text, converting digits to their corresponding floating-point values and handling decimal points appropriately. If an invalid character is encountered, it returns `0.0`.
  //
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

  // The `setBalance` function is a public shared asynchronous function that sets the balance for the miner associated with the caller. Here's a step-by-step description of how the function works:
  // 1. **Function Signature**:
  //    - The function is declared as `public shared`, meaning it can be called by external actors.
  //    - It takes a single parameter `b` of type `Nat` (natural number) which represents the new balance to be set.
  //    - The function returns a `Bool` indicating success (`true`) or failure (`false`).
  // 2. **Get Miner**:
  //    - The function calls `getMiner(message.caller)` to retrieve the miner associated with the caller.
  //    - The result is stored in the variable `res_`.
  // 3. **Check Miner Existence**:
  //    - The function uses a `switch` statement to check if the miner exists:
  //      - If the result is `#none`, it means the miner does not exist, and the function returns `false`.
  //      - If the result is `#ok(m)`, it means the miner exists, and the miner's ID is stored in the variable `id_`.
  // 4. **Get Miner Status**:
  //    - The function retrieves the miner's status using `minerStatus.get(id_)` and stores it in the variable `minerStatus_`.
  // 5. **Set Balance**:
  //    - The function sets the miner's balance to the new value `b` by updating `minerStatus_.balance`.
  // 6. **Return Success**:
  //    - The function returns `true` to indicate that the balance was successfully set.
  // In summary, the `setBalance` function updates the balance of the miner associated with the caller, ensuring that the miner exists before performing the update. If the miner does not exist, it returns `false`; otherwise, it sets the balance and returns `true`.
  public shared (message) func setBalance(b : Nat) : async Bool {
    //let miner_ = getMiner(message.caller);
    let res_ = getMiner(message.caller);
    var id_ = 0;
    switch (res_) {
      case (#none) {
        return false;
      };
      case (#ok(m)) {
        id_ := m.id;
      };
    };
    let status_ = minerStatus.get(id_);
    let minerStatus_ = minerStatus.get(id_);
    minerStatus_.balance := b;
    true;
  };

  // The `routine24` function is an asynchronous private function responsible for performing a routine task that includes updating the CKBTC balance, fetching calculated rewards, distributing mining rewards, and rebasing LOKBTC. Here's a step-by-step description of how the function works:
  // 1. **Get Current Time**:
  //    - The function retrieves the current time using `now()` and stores it in the variable `now_`.
  // 2. **Update CKBTC Balance**:
  //    - The function calls `updateCKBTCBalance()` to update the CKBTC balance and awaits its result, storing it in the variable `ckbtcb`.
  // 3. **Construct URL**:
  //    - The function constructs a URL for fetching calculated rewards from an external API, using the current time as a parameter.
  // 4. **Define LokaMiner Actor**:
  //    - The function defines an actor `LokaMiner` with a method `getCalculatedReward` that takes a `Text` parameter and returns a `Text` result asynchronously.
  // 5. **Initialize Variables**:
  //    - The function initializes `hashrateRewards` as an empty string and `count_` as 0.
  // 6. **Fetch Calculated Rewards**:
  //    - The function attempts to fetch calculated rewards by calling `LokaMiner.getCalculatedReward(url)` and awaits its result, storing it in `hashrateRewards`.
  //    - If successful, it sets `distributionStatus` to "done".
  //    - If an error occurs, it sets `distributionStatus` to "error", calls `reattempt()`, and returns "error".
  // 7. **Log Distribution**:
  //    - The function logs the distribution process by calling `logDistribution` with appropriate parameters.
  // 8. **Distribute Mining Rewards**:
  //    - The function calls `distributeMiningRewards(hashrateRewards)` and awaits its result, storing it in `a`.
  //    - If the result is not "done", it returns "already distributed".
  // 9. **Rebase LOKBTC**:
  //    - The function calls `DEFI.rebaseLOKBTC()` and awaits its result, storing it in `rebase`.
  // 10. **Debug Print**:
  //     - The function prints `hashrateRewards` for debugging purposes.
  // 11. **Return Result**:
  //     - The function returns "done" to indicate the routine task is complete.
  //
  // The function performs a series of tasks to update balances, fetch and distribute rewards, and rebase tokens, ensuring that the process is logged and any errors are handled appropriately.
  //@DEV- CORE FUNCTIONS TO CALCULATE 24 HOUR HASHRATE REWARD AND DISTRIBUTE IT PROPORTIONALLLY TO ALL MINERS
  // public shared(message) func routine24() : async Text {
  //"https://btc.lokamining.com:8443/v1/transaction/earnings"
  private func routine24() : async Text {
    //distributionStatus := "processing";
    //assert(_isAdmin(message.caller));
    let now_ = now();
    var ckbtcb = await updateCKBTCBalance();

    let url = "https://api.lokamining.com/calculatef2poolRewardV2?id=poolR" #Int.toText(now_);
    let LokaMiner = actor ("rfrec-ciaaa-aaaam-ab4zq-cai") : actor {
      getCalculatedReward : (a : Text) -> async Text;
    };
    var hashrateRewards = "";
    var count_ = 0;

    try {
      let result = await LokaMiner.getCalculatedReward(url); //"(record {subaccount=null;})"
      hashrateRewards := result;
      distributionStatus := "done";

      //return result;
    } catch e {
      distributionStatus := "error";
      let r_ = await reattempt();
      //return "reject";
      return "error";
    };

    logDistribution(0, "Distribute", hashrateRewards, "", "");

    //let hashrateRewards = "rantai1-lokabtc/1361772;rantai2-lokabtc/1356752;";
    var a = await distributeMiningRewards(hashrateRewards);
    if (a != "done") {
      return "already distributed";
    };
    var rebase = await DEFI.rebaseLOKBTC();
    Debug.print(hashrateRewards);
    // return hashrateRewards;

    return "done";
  };

  public shared (message) func routine24Force() : async Text {
    assert (_isAdmin(message.caller));
    distributionStatus := "processing";
    let now_ = now();
    var ckbtcb = await updateCKBTCBalance();

    let url = "https://api.lokamining.com/calculatef2poolRewardV2?id=poolR" #Int.toText(now_);
    let LokaMiner = actor ("rfrec-ciaaa-aaaam-ab4zq-cai") : actor {
      getCalculatedReward : (a : Text) -> async Text;
    };
    var hashrateRewards = "";
    var count_ = 0;

    try {
      let result = await LokaMiner.getCalculatedReward(url); //"(record {subaccount=null;})"
      hashrateRewards := result;
      distributionStatus := "done";

      //return result;
    } catch e {
      distributionStatus := "error";
      let r_ = await reattempt();
      //return "reject";
      return "error";
    };

    logDistribution(0, "Distribute", hashrateRewards, "", "");

    //let hashrateRewards = "rantai1-lokabtc/1361772;rantai2-lokabtc/1356752;";
    var a = await distributeMiningRewards(hashrateRewards);
    var rebase = await DEFI.rebaseLOKBTC();
    Debug.print(hashrateRewards);
    // return hashrateRewards;

    //return "done";
    nextTimeStamp := now_ / 1000000 + (24 * 60 * 60 * 1000);

    return hashrateRewards # " " #a;
  };

  // The `specialReward` function is responsible for distributing special rewards based on provided hashrate data. Here's a step-by-step description of how the function works:
  // 1. **Function Signature**:
  //    - The function is declared as `public shared`, meaning it can be called by external actors.
  //    - It takes a single parameter `hashrateData` of type `Text`.
  // 2. **Admin Check**:
  //    - The function ensures that the caller is an admin by calling `assert(_isAdmin(message.caller))`.
  // 3. **Set Distribution Status**:
  //    - The function sets the `distributionStatus` to "processing" to indicate that the distribution process is ongoing.
  // 4. **Get Current Time**:
  //    - The function retrieves the current time using `now()` and stores it in the variable `now_`.
  // 5. **Initialize Variables**:
  //    - The function initializes `hashrateRewards` with the provided `hashrateData`.
  //    - It also initializes a counter variable `count_` to 0.
  // 6. **Log Distribution**:
  //    - The function logs the distribution process by calling `logDistribution` with appropriate parameters.
  // 7. **Distribute Special Reward**:
  //    - The function calls `distributeSpecialReward` with `hashrateRewards` and awaits its result, storing the result in the variable `a`.
  // 8. **Return Result**:
  //    - The function returns a concatenated string of `hashrateRewards` and the result `a`.
  // The function ensures that only admins can initiate the special reward distribution, logs the distribution process, and calls another function to handle the actual distribution of rewards based on the provided hashrate data.
  public shared (message) func specialReward(hashrateData : Text) : async Text {
    assert (_isAdmin(message.caller));
    distributionStatus := "processing";
    let now_ = now();

    var hashrateRewards = hashrateData;
    var count_ = 0;

    logDistribution(0, "Distribute", hashrateRewards, "", "");

    //let hashrateRewards = "rantai1-lokabtc/1361772;rantai2-lokabtc/1356752;";
    var a = await distributeSpecialReward(hashrateRewards);

    return hashrateRewards # " " #a;
  };

  // The `textSplit` function is a utility function that splits a given text into an array of substrings based on a specified delimiter. Here's a step-by-step description of how the function works:
  // 1. **Function Signature**:
  //    - The function takes two parameters:
  //      - `word_`: The text to be split.
  //      - `delimiter_`: The character used as the delimiter for splitting the text.
  // 2. **Splitting the Text**:
  //    - The function uses `Text.split` to split the input text (`word_`) by the specified delimiter (`delimiter_`).
  //    - This results in an iterable collection of substrings.
  // 3. **Converting to Array**:
  //    - The function converts the iterable collection of substrings into an array using `Iter.toArray`.
  // 4. **Returning the Result**:
  //    - The function returns the array of substrings.
  // The function effectively splits a text into an array of substrings based on a given delimiter and returns the resulting array.
  func textSplit(word_ : Text, delimiter_ : Char) : [Text] {
    let hasil = Text.split(word_, #char delimiter_);
    let wordsArray = Iter.toArray(hasil);
    return wordsArray;
    //Debug.print(wordsArray[0]);
  };

  //   The `distributeMiningRewards` function is responsible for distributing mining rewards to miners based on their hashrate and predefined revenue sharing rules. Here's a step-by-step description of how the function works:
  // 1. **Input Parsing**:
  //    - The function takes a `rewards_` string as input, which contains reward distribution data.
  //    - It splits the `rewards_` string into components using the `textSplit` function.
  // 2. **Double Distribution Prevention**:
  //    - It checks if rewards for the given timestamp have already been distributed using `distributionHistoryByTimeStamp`.
  //    - If rewards have already been distributed for the timestamp, it returns "already distributed".
  // 3. **Distribution Data Extraction**:
  //    - Extracts the total hashrate and total reward from the distribution data.
  //    - Splits the hashrate rewards data into individual miner rewards.
  // 4. **Update Total Balance**:
  //    - Adds the total reward to the `totalBalance`.
  // 5. **Create Distribution Record**:
  //    - Creates a `T.Distribution` record with the distribution details.
  //    - Updates the distribution history with the new distribution record.
  // 6. **Initialize Transfer Hashes**:
  //    - Initializes a hash map to keep track of MPTS (Mining Pool Token Shares) transfers.
  //    - Initializes variables to keep track of net MPTS and net hashrate rewards.
  // 7. **Iterate Over Miners**:
  //    - Iterates over all miners to distribute rewards.
  //    - For each miner, it checks if the miner's username is present in the rewards data.
  //    - If the miner is eligible for rewards, it processes the rewards.
  // 8. **Revenue Sharing**:
  //    - For each eligible miner, it checks if there are any revenue sharing rules.
  //    - If revenue sharing rules exist, it calculates the shared rewards and updates the balances of the shared targets.
  //    - Updates the revenue hash with the shared rewards.
  // 9. **Update Miner Status**:
  //    - Updates the miner's balance and total shared revenue.
  //    - Updates the miner status and reward hash with the new balances.
  // 10. **MPTS Transfer**:
  //     - Calculates the net MPTS for the miner and updates the MPTS transfer hash.
  // 11. **Log Distribution History**:
  //     - Logs the distribution history with the rewards data.
  // 12. **Perform MPTS Transfers**:
  //     - Iterates over the MPTS transfer hash and performs the MPTS transfers using the `DEFI.distributeMPTS` function.
  // 13. **Perform LPTS Transfer**:
  //     - Performs the LPTS (Liquidity Pool Token Shares) transfer using the `DEFI.distributeLPTS` function.
  // 14. **Update Distribution History List**:
  //     - Updates the `distributionHistoryList` with the new distribution record.
  //     - Updates the `lastF2poolCheck` timestamp.
  // 15. **Return Result**:
  //     - Returns "done" to indicate the distribution process is complete.
  public shared (message) func distributeMiningRewards(rewards_ : Text) : async Text {

    let distributionData = textSplit(rewards_, ':');
    let timestamp_ = distributionData[0];
    switch (distributionHistoryByTimeStamp.get(timestamp_)) {
      case (?distributed) {
        //preventing double distribution, marking 1 timestamp per day
        return "already distributed";
      };
      case (null) {

      };
    };
    let totalHash_ = distributionData[2];
    let totalReward_ = distributionData[1];
    let hashrateRewards = textSplit(distributionData[3], '|');
    totalBalance += textToNat(totalReward_);
    let dist_ : T.Distribution = {
      id = distributionIndex;
      hashrate = totalHash_;
      sats = totalReward_;
      time = timestamp_;
      data = rewards_;

    };

    distributionHistoryByTimeStamp.put(timestamp_, dist_);
    distributionTimestampById.put(Nat.toText(distributionIndex), timestamp_);
    distributionIndex += 1;

    var mptsTransferHash = HashMap.HashMap<Text, Nat>(0, Text.equal, Text.hash);
    var netMPTS = 0;
    var netHR = 0;
    var mpts = 0;
    Buffer.iterate<T.Miner>(
      miners,
      func(miner) {
        let status_ = minerStatus.get(miner.id);

        let user_ = miner.username;

        let isValid = Text.contains(rewards_, #text user_);
        if (isValid) {
          for (hashrateRewards_ in hashrateRewards.vals()) {
            if (hashrateRewards_ != "") {
              Debug.print("split " #hashrateRewards_);
              let hr_ = textSplit(hashrateRewards_, '/');
              var username = hr_[0];
              var reward = textToNat(hr_[2]);
              //MPTS = 1% from received reward
              mpts := reward / 100;
              var hashrate_ = textToNat(hr_[1]);
              var totalShared = 0;
              var totalSharedHash = 0;
              var totalSharedMPTS = 0;
              Debug.print("miner username : " #username # " " #miner.username);
              if (username == miner.username # "") {
                Debug.print("distributing " #Nat.toText(reward));
                switch (revenueShareHash.get(miner.username)) {
                  case (?list) {

                    for (shareItem in list.vals()) {
                      switch (usernameHash.get(shareItem.1.userName)) {
                        case (?theId) {
                          let sharedTarget = minerStatus.get(theId);
                          var sharedReward = (reward * shareItem.1.sharePercent) / 10000;
                          var sharedHash = (hashrate_ * shareItem.1.sharePercent) / 10000;
                          var sharedMPTS = (((mpts * shareItem.1.sharePercent) / 10000) * (80)) / 100;
                          sharedTarget.balance += sharedReward;
                          sharedTarget.totalSharedRevenue += sharedReward;
                          switch (minerStatusAndRewardHash.get(Nat.toText(sharedTarget.id))) {
                            case (?mStat) {
                              mStat.balance := sharedTarget.balance;
                              mStat.transactions := sharedTarget.transactions;
                              mStat.totalSharedRevenue := sharedTarget.totalSharedRevenue;
                            };
                            case (null) {

                            };
                          };
                          totalShared += sharedReward;
                          totalSharedHash += sharedHash;
                          totalSharedMPTS += sharedMPTS;
                          let rev : [T.DistributionHistory] = [{
                            time = textToNat(timestamp_);
                            hashrate = sharedHash;
                            sats = sharedReward;
                            from = Principal.toText(miner.walletAddress);
                            fromUsername = miner.username;
                          }];
                          //transfer sharedMTPS
                          //var ckBTCBalance : Nat = (await CKBTC.icrc1_balance_of({ owner = Principal.fromActor(this); subaccount = null }));

                          mptsTransferHash.put(shareItem.1.wallet, (sharedMPTS));
                          switch (revenueHash.get(shareItem.1.wallet)) {
                            case (?r) {
                              revenueHash.put(shareItem.1.wallet, Array.append<T.DistributionHistory>(r, rev));

                            };
                            case (null) {
                              revenueHash.put(shareItem.1.wallet, rev);
                            };
                          };
                        };
                        case (null) {

                        };
                      };

                    };

                  };
                  case (null) {

                  };
                };
                status_.balance += reward - totalShared;
                switch (minerStatusAndRewardHash.get(Nat.toText(status_.id))) {
                  case (?mStat) {
                    mStat.balance := status_.balance;
                    mStat.transactions := status_.transactions;
                    mStat.totalSharedRevenue := status_.totalSharedRevenue;
                  };
                  case (null) {

                  };
                };
                netMPTS := mpts - totalSharedMPTS;
                mptsTransferHash.put(Principal.toText(miner.walletAddress), netMPTS);
                //totalBalance += reward;
                let rev : [T.DistributionHistory] = [{
                  time = textToNat(timestamp_);
                  hashrate = hashrate_ - totalSharedHash;
                  sats = reward - totalShared;
                  from = "";
                  fromUsername = "";
                }];

                switch (revenueHash.get(Principal.toText(miner.walletAddress))) {
                  case (?r) {
                    revenueHash.put(Principal.toText(miner.walletAddress), Array.append<T.DistributionHistory>(r, rev));

                  };
                  case (null) {
                    revenueHash.put(Principal.toText(miner.walletAddress), rev);
                  };
                };
              };

            };
          };
        } else {
          //status_.verified := false;
        };
      },
    );

    var transferList = Iter.toArray(mptsTransferHash.entries());
    for (transfer in transferList.vals()) {
      var q = await DEFI.distributeMPTS(transfer.1, transfer.0);
    };

    var o = await DEFI.distributeLPTS(mpts);
    let tm = now() / 1000000;
    let d = [{ time = tm; data = rewards_ }];
    distributionHistoryList := Array.append<{ time : Int; data : Text }>(distributionHistoryList, d);
    lastF2poolCheck := tm;
    return "done";
  };

  public shared (message) func distributeSpecialReward(rewards_ : Text) : async Text {

    let distributionData = textSplit(rewards_, ':');
    let timestamp_ = distributionData[0];
    switch (distributionHistoryByTimeStamp.get(timestamp_)) {
      case (?distributed) {
        //preventing double distribution, marking 1 timestamp per day
        return "already distributed";
      };
      case (null) {

      };
    };
    let totalHash_ = distributionData[2];
    let totalReward_ = distributionData[1];
    let hashrateRewards = textSplit(distributionData[3], '|');
    totalBalance += textToNat(totalReward_);
    let dist_ : T.Distribution = {
      id = distributionIndex;
      hashrate = totalHash_;
      sats = totalReward_;
      time = timestamp_;
      data = rewards_;

    };

    distributionHistoryByTimeStamp.put(timestamp_, dist_);
    distributionTimestampById.put(Nat.toText(distributionIndex), timestamp_);
    distributionIndex += 1;

    var mptsTransferHash = HashMap.HashMap<Text, Nat>(0, Text.equal, Text.hash);
    var netMPTS = 0;
    var netHR = 0;
    var mpts = 0;
    Buffer.iterate<T.Miner>(
      miners,
      func(miner) {
        let status_ = minerStatus.get(miner.id);

        let user_ = miner.username;

        let isValid = Text.contains(rewards_, #text user_);
        if (isValid) {
          for (hashrateRewards_ in hashrateRewards.vals()) {
            if (hashrateRewards_ != "") {
              Debug.print("split " #hashrateRewards_);
              let hr_ = textSplit(hashrateRewards_, '/');
              var username = hr_[0];
              var reward = textToNat(hr_[2]);
              //MPTS = 1% from received reward
              mpts := reward / 100;
              var hashrate_ = textToNat(hr_[1]);
              var totalShared = 0;
              var totalSharedHash = 0;
              var totalSharedMPTS = 0;
              Debug.print("miner username : " #username # " " #miner.username);
              if (username == miner.username # "") {
                Debug.print("distributing " #Nat.toText(reward));

                status_.balance += reward - totalShared;
                switch (minerStatusAndRewardHash.get(Nat.toText(status_.id))) {
                  case (?mStat) {
                    mStat.balance := status_.balance;
                    mStat.transactions := status_.transactions;
                    mStat.totalSharedRevenue := status_.totalSharedRevenue;
                  };
                  case (null) {

                  };
                };
                netMPTS := mpts - totalSharedMPTS;

                //totalBalance += reward;
                let rev : [T.DistributionHistory] = [{
                  time = textToNat(timestamp_);
                  hashrate = hashrate_ - totalSharedHash;
                  sats = reward - totalShared;
                  from = "";
                  fromUsername = "";
                }];

                switch (revenueHash.get(Principal.toText(miner.walletAddress))) {
                  case (?r) {
                    revenueHash.put(Principal.toText(miner.walletAddress), Array.append<T.DistributionHistory>(r, rev));

                  };
                  case (null) {
                    revenueHash.put(Principal.toText(miner.walletAddress), rev);
                  };
                };
              };

            };
          };
        } else {
          //status_.verified := false;
        };
      },
    );

    let tm = now() / 1000000;
    let d = [{ time = tm; data = rewards_ }];
    distributionHistoryList := Array.append<{ time : Int; data : Text }>(distributionHistoryList, d);
    lastF2poolCheck := tm;
    return "done";
  };

  public shared (message) func setT(a : Nat) : async Nat {
    assert (_isAdmin(message.caller));
    totalBalance := a;
    totalBalance;
  };

  //@DEV- CORE MINER VERIFICATION
  public shared (message) func verifyMiner(uname__ : Text, hash_ : Nat) : async Bool {
    //assert (_isNotRegistered(message.caller, uname));
    var uname = toLower(uname__);
    if (_isNotRegistered(message.caller, uname) == false) return false;
    //var isValid = Text.contains(decoded_text, #text hashText);
    var isValid = true;
    if (isValid) {
      let miner_ = addMiner(uname, hash_, message.caller);
    };
    isValid;

  };

  public shared (message) func addTestUser() : async Bool {
    assert (_isAdmin(message.caller));
    let miner_ = addMiner("test", 8000000000000000, Principal.fromText("o4k35-i6lb3-mfi6a-6mwzo-iuxj6-qci6k-l7whg-3ntvl-2vcum-dq7ac-2qe"));
    true;
  };

  func removeMiner(p_ : Principal) : async Bool {
    assert (_isAddressVerified(p_));
    // let miner_ = getMiner(p_);
    let res_ = getMiner(p_);
    var id_ = 0;
    switch (res_) {
      case (#none) {
        return false;
      };
      case (#ok(m)) {
        id_ := m.id;
        let status_ = minerStatus.get(id_);
        var minerStatus_ : T.MinerStatus = minerStatus.get(id_);
        minerStatus_.verified := false;
        m.username := "";

        return true;
      };
    };

  };

  //@DEV- CORE MINER VERIFICATION

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

  func generateUUID() : Text {
    "UUID-123456789";
  };

};
