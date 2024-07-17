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
    assert (_isVerified(message.caller, username));
    let err_ : T.ErrorLog = {
      id = errorIndex;
      time = now() / 1000000;
      error = errorMessage;
      wallet = Principal.toText(message.caller);
      time_text = Int.toText(now() / 1000000);
      username = username;

    };
    switch (userErrorHash.get(Principal.toText(message.caller))) {
      case (?errData) {
        let newData = Array.append<Text>(errData, [Nat.toText(errorIndex)]);
        userErrorHash.put(Principal.toText(message.caller), newData);
      };
      case (null) {
        userErrorHash.put(Principal.toText(message.caller), [Nat.toText(errorIndex)]);
      };
    };
    errorHash.put(Nat.toText(errorIndex), err_);
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
  private func addMiner(f2poolUsername_ : Text, hashrate_ : Nat, wallet : Principal) : async Bool {
    //assert(_isAdmin(message.caller));
    assert (_isNotRegistered(wallet, f2poolUsername_));
    assert (_isNotPaused());
    let miner_ = getMiner(wallet);
    let hash_ = hashrate_ * 1000000000000;
    if (_isNotRegistered(wallet, f2poolUsername_)) {
      let miner_ : T.Miner = {

        id = minersIndex;
        walletAddress = wallet;
        var username = f2poolUsername_;
        hashrate = hash_;
      };
      minerHash.put(Principal.toText(wallet), miner_);
      usernameHash.put(f2poolUsername_, minersIndex);
      miners.add(miner_);
      Debug.print("miner added");
      logMiner(minersIndex, f2poolUsername_, Nat.toText(hashrate_), Principal.toText(wallet));
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
      minerStatusAndRewardHash.put(Nat.toText(minersIndex), minerStatus_);
      minerStatus.add(minerStatus_);
      minersIndex += 1;
      totalHashrate += hash_;
      true;
    } else {
      //update mining Pool
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

  public shared (message) func sendCKBTC(wallet_ : Text, subAccount : Text, amount_ : Nat) : async Bool {
    let wallet : Principal = Principal.fromText(wallet_);
    assert (_isAdmin(message.caller));
    var ckBTCBalance : Nat = (await CKBTC.icrc1_balance_of({ owner = Principal.fromActor(this); subaccount = null }));
    //assert(ckBTCBalance>12);
    ckBTCBalance -= 12;

    let transferResult = await CKBTC.icrc1_transfer({
      amount = amount_;
      fee = ?10;
      created_at_time = null;
      from_subaccount = null;
      to = { owner = wallet; subaccount = null };
      memo = null;
    });
    var res = 0;
    switch (transferResult) {
      case (#Ok(number)) {
        return true;
      };
      case (#Err(msg)) { res := 0 };
    };
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

  public shared (message) func withdrawIDR(quoteId_ : Text, amount_ : Nat, bankID_ : Text, memoParam_ : [Nat8]) : async T.TransferRes {
    //return false;
    assert (_isNotPaused());
    assert (_isAddressVerified(message.caller));
    assert (amount_ > 10);
    //assert (_isAdmin(message.caller));
    // let addr = Principal.fromText(address);
    withdrawalIndex += 1;
    let amountNat_ : Nat = amount_;
    let res_ = getMiner(message.caller);
    var id_ = 0;
    var usernm = "";
    switch (res_) {
      case (#none) {
        return #error("miner not found");
        // return false;
      };
      case (#ok(m)) {
        id_ := m.id;
        usernm := m.username;
      };
    };
    //let miner_ = miners_[0];
    var memo_ : Blob = Text.encodeUtf8(bankID_ # "." #quoteId_);
    var minerStatus_ : T.MinerStatus = minerStatus.get(id_);
    if ((minerStatus_.balance < (amount_ + 10)) == true) {
      return #error("insufficient balance");
    };

    let blob_ = Blob.fromArray(memoParam_);

    let CKBTC_ = actor ("mxzaz-hqaaa-aaaar-qaada-cai") : actor {
      icrc1_transfer : (T.TransferArg) -> async T.Result;
    };
    var tme = now();

    logTransaction(id_, "{\"action\":\"withdraw IDR\",\"receiver\":\"" #quoteId_ # "\"}", Nat.toText(amount_), "pre transfer", "{\"currency\":\"IDR\",\"bank\":\"" #bankID_ # "\"}", usernm, Principal.toText(message.caller));
    totalBalance -= (amount_ + 10);
    minerStatus_.balance -= (amount_ + 10);
    minerStatus_.totalWithdrawn += (amount_ + 10);
    var tsr = minerStatus_.totalSharedRevenue;
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
      case (null) {

      };
    };

    var wdh : T.WithdrawalHistory = {
      id = withdrawalIndex;
      //caller: Text;
      time = tme;
      action = "Withdraw IDR";
      //receiver : Text;
      amount = "pretransfer";
      txid = "pretransfer";
      currency = "IDR";
      username = usernm;
      wallet = Principal.toText(message.caller);
      jwalletId = quoteId_;
      bankId = bankID_;
      memo = ?blob_;
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
      transferResult := await CKBTC_.icrc1_transfer({
        amount = amount_;
        fee = ?10;
        created_at_time = null;
        from_subaccount = null;
        to = { owner = Principal.fromText(jwalletVault); subaccount = null };
        memo = ?blob_;
      });
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
      logTransaction(id_, "{\"action\":\"crashed withdraw IDR\",\"receiver\":\"" #quoteId_ # "\"}", Nat.toText(amount_), "pre transfer", "{\"currency\":\"IDR\",\"bank\":\"" #bankID_ # "\"}", usernm, Principal.toText(message.caller));

      return #error("ckBTC transfer process unexpectly failed");
    };

    var res = 0;
    switch (transferResult) {
      case (#Ok(number)) {

        var wdh : T.WithdrawalHistory = {
          id = withdrawalIndex;
          //caller: Text;
          time = tme;
          action = "Withdraw IDR";
          //receiver : Text;
          amount = Nat.toText(amount_);
          txid = Int.toText(number);
          currency = "IDR";
          username = usernm;
          wallet = Principal.toText(message.caller);
          jwalletId = quoteId_;
          bankId = bankID_;
          memo = ?blob_;
          //provider : Text;
        };

        switch (withdrawalHash.get(Nat.toText(id_))) {
          case (?withdrawals) {
            var wd = HashMap.fromIter<Text, T.WithdrawalHistory>(withdrawals.vals(), 1, Text.equal, Text.hash);
            //return #res(list);
            wd.put(Int.toText(tme), wdh);
            allWithdrawalHash.put(Int.toText(tme), wdh);
            allSuccessfulWithdrawalHash.put(Int.toText(tme), wdh);
            withdrawalHash.put(Nat.toText(id_), Iter.toArray(wd.entries()));

          };
          case (null) {

            var wd = HashMap.HashMap<Text, T.WithdrawalHistory>(0, Text.equal, Text.hash);
            //return #res(list);
            wd.put(Int.toText(tme), wdh);
            allWithdrawalHash.put(Int.toText(tme), wdh);
            allSuccessfulWithdrawalHash.put(Int.toText(tme), wdh);
            withdrawalHash.put(Nat.toText(id_), Iter.toArray(wd.entries()));
          };
        };
        // logTransaction(miner_.id, "withdraw IDR", Nat.toText(amount_), Int.toText(number) # " " #quoteId_, "IDR ");
        logTransaction(id_, "{\"action\":\"withdraw IDR\",\"receiver\":\"" #quoteId_ # "\"}", Nat.toText(amount_), Nat.toText(number), "{\"currency\":\"IDR\",\"bank\":\"" #bankID_ # "\"}", usernm, Principal.toText(message.caller));

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
        var wdh : T.WithdrawalHistory = {
          id = withdrawalIndex;
          //caller: Text;
          time = tme;
          action = "FAILED : Withdraw IDR";
          //receiver : Text;
          amount = Nat.toText(amount_);
          txid = errmsg;
          currency = "IDR";
          username = usernm;
          wallet = Principal.toText(message.caller);
          jwalletId = quoteId_;
          bankId = bankID_;
          memo = ?blob_;
          //provider : Text;
        };
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
        allWithdrawalHash.put(Int.toText(tme), wdh);
        failedWithdrawalHash.put(Int.toText(tme), wdh);
        return #error("ckbtc offramp transferfailed : " #errmsg);
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

  private func natToFloat(nat_ : Nat) : Float {
    let toNat64_ = Nat64.fromNat(nat_);
    let toInt64_ = Int64.fromNat64(toNat64_);
    let amountFloat_ = Float.fromInt64(toInt64_);
    return amountFloat_;
  };

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

  public shared (message) func getUsername() : async [(Text, Nat)] {
    assert (_isAdmin(message.caller));
    return Iter.toArray(usernameHash.entries());
  };

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

  public query (message) func getWallets(id_ : Nat) : async [T.WalletAddress] {

    let miner_ = minerStatus.get(id_);
    miner_.walletAddress;
  };

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

  func textSplit(word_ : Text, delimiter_ : Char) : [Text] {
    let hasil = Text.split(word_, #char delimiter_);
    let wordsArray = Iter.toArray(hasil);
    return wordsArray;
    //Debug.print(wordsArray[0]);
  };

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
