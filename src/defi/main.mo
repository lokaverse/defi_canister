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

module {
  public shared ({ caller = owner }) actor class Miner({
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

    /// The `clearDefiData` function is a public shared asynchronous function that clears all DeFi-related data and optionally burns test ckBTC. Here's a step-by-step description of how the function works:
    /// 1. **Function Signature**:
    ///    - The function is declared as `public shared (message)`, meaning it can be called by external actors.
    ///    - It takes a single parameter `burn` of type `Bool`, which indicates whether to burn test ckBTC.
    ///    - The function returns `async ()`, indicating it performs asynchronous operations and returns no value.
    /// 2. **Admin Check**:
    ///    - The function ensures that the caller is an admin by calling `assert(_isAdmin(message.caller))`.
    /// 3. **Clear Hash Maps**:
    ///    - The function clears various hash maps related to DeFi data by reinitializing them with empty hash maps:
    ///      - `addLiquidityHash`
    ///      - `sharesHash`
    ///      - `transactionHash`
    ///      - `withdrawalHash`
    ///      - `userLiquidityHash`
    ///      - `userWithdrawalHash`
    ///      - `userAddressHash`
    ///      - `userIdHash`
    ///      - `userClaimableCKBTCHash`
    ///      - `userClaimableMPTSHash`
    ///      - `userClaimableLPTSHash`
    ///      - `userMaturedClaimableCKBTCHash`
    /// 4. **Burn Test ckBTC (Optional)**:
    ///    - If the `burn` parameter is `true`, the function calls `burnTestCKBTC()` and awaits its result.
    /// 5. **Force Rebase**:
    ///    - The function calls `LOKBTC.forceRebase()` and awaits its result.
    /// 6. **Reset Variables**:
    ///    - The function resets various variables related to DeFi data:
    ///      - `totalShares` to 0
    ///      - `usersIndex` to 0
    ///      - `transactionIndex` to 0
    ///      - `pause` to `false`
    ///      - `rebaseIndex` to 0
    ///      - `liquidityIndex` to 0
    ///      - `schedulerId` to 0
    ///      - `nextTimeStamp` to 0
    ///      - `counter` to 0
    ///
    /// In summary, the `clearDefiData` function clears all DeFi-related data by reinitializing various hash maps and resetting related variables. It ensures that only admins can perform this operation. Optionally, it burns test ckBTC if the `burn` parameter is `true`, and it forces a rebase of LOKBTC.
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

    /// The `getUserData` function is a public shared asynchronous function that retrieves various balances and claimable amounts for the caller. Here's a step-by-step description of how the function works:
    /// 1. **Function Signature**:
    ///    - The function is declared as `public shared (message)`, meaning it can be called by external actors.
    ///    - It takes no parameters.
    ///    - The function returns an object with multiple fields representing the user's data.
    /// 2. **Retrieve Balances**:
    ///    - The function retrieves the current balances of ckBTC, lokBTC, MPTS, and LPTS for the caller using the `icrc1_balance_of` method for each token.
    ///    - The balances are stored in the variables `ckBTCBalance`, `lokBTCBalance`, `mptsBalance`, and `lptsBalance`.
    /// 3. **Initialize Variables**:
    ///    - The function initializes several variables to store the user's data:
    ///      - `stakedShare` to 0.
    ///      - `claimList` to an empty list.
    ///      - `claimableLPTS_` to 0.
    ///      - `claimableMPTS_` to 0.
    ///      - `now_` to the current time in milliseconds.
    ///      - `totalWithdrawableCKBTC` to 0.
    ///      - `totalPendingCKBTC` to 0.
    ///      - `callertxt` to the text representation of the caller's principal.
    /// 4. **Retrieve Withdrawable ckBTC**:
    ///    - The function checks if there are any matured claimable ckBTC for the caller in `userMaturedClaimableCKBTCHash`.
    ///    - If found, it adds the amount to `totalWithdrawableCKBTC`.
    /// 5. **Retrieve Claimable ckBTC**:
    ///    - The function checks if there are any claimable ckBTC for the caller in `userClaimableCKBTCHash`.
    ///    - If found, it iterates over the claimable entries:
    ///      - If the claim is matured (time <= now_), it adds the amount to `totalWithdrawableCKBTC` and removes the entry from the hash map.
    ///      - If the claim is not matured, it adds the amount to `totalPendingCKBTC`.
    ///    - It updates the `userClaimableCKBTCHash` and `userMaturedClaimableCKBTCHash` with the new values.
    /// 6. **Retrieve Claimable LPTS and MPTS**:
    ///    - The function checks if there are any claimable LPTS and MPTS for the caller in `userClaimableLPTSHash` and `userClaimableMPTSHash`.
    ///    - If found, it updates `claimableLPTS_` and `claimableMPTS_` with the respective amounts.
    /// 7. **Retrieve Staked Shares**:
    ///    - The function checks if there are any staked shares for the caller in `sharesHash`.
    ///    - If found, it updates `stakedShare` with the share amount.
    /// 8. **Return User Data**:
    ///    - The function constructs an object `datas` with the retrieved and calculated data, including:
    ///      - `ckbtc`: The ckBTC balance.
    ///      - `lokbtc`: The lokBTC balance.
    ///      - `staked`: The staked share amount.
    ///      - `lpts`: The LPTS balance.
    ///      - `mpts`: The MPTS balance.
    ///      - `ckBTCClaimList`: The list of claimable ckBTC.
    ///      - `claimableLPTS`: The claimable LPTS amount.
    ///      - `claimableMPTS`: The claimable MPTS amount.
    ///      - `totalPendingCKBTC`: The total pending ckBTC amount.
    ///      - `totalWithdrawableCKBTC`: The total withdrawable ckBTC amount.
    ///    - The function returns the `datas` object.
    ///
    /// In summary, the `getUserData` function retrieves various balances and claimable amounts for the caller, including ckBTC, lokBTC, MPTS, LPTS, staked shares, and claimable ckBTC, LPTS, and MPTS. It processes the claimable ckBTC to determine the total withdrawable and pending amounts and returns the data in a structured format.
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

          for (claim in claimList.vals()) {
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

    /// The `distributeLPTS` function is a public shared asynchronous function that distributes a specified amount of LPTS (Liquidity Pool Token Shares) among users based on their shares. Here's a step-by-step description of how the function works:
    /// 1. **Function Signature**:
    ///    - The function is declared as `public shared (message)`, meaning it can be called by external actors.
    ///    - It takes a single parameter `amountSat_` of type `Nat`, which represents the amount of LPTS to be distributed in satoshis.
    ///    - The function returns `async ()`, indicating it performs asynchronous operations and returns no value.
    /// 2. **Admin Check**:
    ///    - The function ensures that the caller is an admin by calling `assert(_isAdmin(message.caller))`.
    /// 3. **Retrieve Shares**:
    ///    - The function converts the entries of `sharesHash` to an array `sharesHash_`.
    /// 4. **Calculate Total LPTS**:
    ///    - The function calculates the total LPTS to be distributed by multiplying `amountSat_` by 10000 and stores it in the variable `totalLPTS`.
    /// 5. **Loop Through Shares**:
    ///    - The function iterates over each entry in `sharesHash`.
    /// 6. **Calculate Shared LPTS**:
    ///    - For each share, the function calculates the shared LPTS by multiplying the user's share by `totalLPTS` and dividing by `totalShares`.
    ///    - The result is stored in the variable `sharedLPTS`.
    /// 7. **Distribute Shared LPTS**:
    ///    - The function checks if the user's wallet address already has claimable LPTS in `userClaimableLPTSHash`.
    ///    - If the wallet address exists, it adds the `sharedLPTS` to the existing claimable LPTS.
    ///    - If the wallet address does not exist, it sets the claimable LPTS to `sharedLPTS`.
    ///
    /// In summary, the `distributeLPTS` function distributes a specified amount of LPTS among users based on their shares. It ensures that only admins can perform this operation, calculates the shared LPTS for each user, and updates the `userClaimableLPTSHash` with the new claimable LPTS for each user's wallet address.
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

    /// The `distributeMPTS` function is a public shared asynchronous function that distributes a specified amount of MPTS (Mining Pool Token Shares) to a specific user. Here's a step-by-step description of how the function works:
    /// 1. **Function Signature**:
    ///    - The function is declared as `public shared (message)`, meaning it can be called by external actors.
    ///    - It takes two parameters:
    ///      - `amountSat_`: The amount of MPTS to be distributed in satoshis (as `Nat`).
    ///      - `to`: The text representation of the user's wallet address (as `Text`).
    ///    - The function returns `async ()`, indicating it performs asynchronous operations and returns no value.
    /// 2. **Admin Check**:
    ///    - The function ensures that the caller is an admin by calling `assert(_isAdmin(message.caller))`.
    /// 3. **Calculate Total MPTS**:
    ///    - The function calculates the total MPTS to be distributed by multiplying `amountSat_` by 10000 and stores it in the variable `amount_`.
    /// 4. **Distribute MPTS**:
    ///    - The function checks if the user's wallet address already has claimable MPTS in `userClaimableMPTSHash`.
    ///    - If the wallet address exists (`?claimable`), it adds the `amount_` to the existing claimable MPTS and updates the hash map.
    ///    - If the wallet address does not exist (`null`), it sets the claimable MPTS to `amount_` and updates the hash map.
    ///
    /// In summary, the `distributeMPTS` function distributes a specified amount of MPTS to a specific user. It ensures that only admins can perform this operation, calculates the total MPTS to be distributed, and updates the `userClaimableMPTSHash` with the new claimable MPTS for the specified user's wallet address.
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

    /// The `getMPTS` function is a public shared asynchronous function that retrieves all entries of claimable MPTS (Mining Pool Token Shares) for users. Here's a step-by-step description of how the function works:
    /// 1. **Function Signature**:
    ///    - The function is declared as `public shared (message)`, meaning it can be called by external actors.
    ///    - It takes no parameters.
    ///    - The function returns an array of tuples `[(Text, Nat)]`, where each tuple contains a user's wallet address (as `Text`) and the corresponding claimable MPTS amount (as `Nat`).
    /// 2. **Admin Check**:
    ///    - The function ensures that the caller is an admin by calling `assert(_isAdmin(message.caller))`.
    /// 3. **Retrieve Claimable MPTS**:
    ///    - The function retrieves all entries from `userClaimableMPTSHash`, which is a hash map storing users' wallet addresses and their corresponding claimable MPTS amounts.
    /// 4. **Convert to Array**:
    ///    - The function converts the entries from the hash map into an array using `Iter.toArray(userClaimableMPTSHash.entries())`.
    /// 5. **Return Claimable MPTS**:
    ///    - The function returns the array of claimable MPTS entries.
    ///
    /// In summary, the `getMPTS` function retrieves all entries of claimable MPTS for users, ensuring that only admins can perform this operation. It returns the data in an array of tuples format, where each tuple contains a user's wallet address and the corresponding claimable MPTS amount.
    public shared (message) func getMPTS() : async [(Text, Nat)] {
      assert (_isAdmin(message.caller));
      return Iter.toArray(userClaimableMPTSHash.entries());
    };

    /// The `getLPTS` function is a public shared asynchronous function that retrieves all entries of claimable LPTS (Liquidity Pool Token Shares) for users. Here's a step-by-step description of how the function works:
    /// 1. **Function Signature**:
    ///    - The function is declared as `public shared (message)`, meaning it can be called by external actors.
    ///    - It takes no parameters.
    ///    - The function returns an array of tuples `[(Text, Nat)]`, where each tuple contains a user's wallet address (as `Text`) and the corresponding claimable LPTS amount (as `Nat`).
    /// 2. **Admin Check**:
    ///    - The function ensures that the caller is an admin by calling `assert(_isAdmin(message.caller))`.
    /// 3. **Retrieve Claimable LPTS**:
    ///    - The function retrieves all entries from `userClaimableLPTSHash`, which is a hash map storing users' wallet addresses and their corresponding claimable LPTS amounts.
    /// 4. **Convert to Array**:
    ///    - The function converts the entries from the hash map into an array using `Iter.toArray(userClaimableLPTSHash.entries())`.
    /// 5. **Return Claimable LPTS**:
    ///    - The function returns the array of claimable LPTS entries.
    ///
    /// In summary, the `getLPTS` function retrieves all entries of claimable LPTS for users, ensuring that only admins can perform this operation. It returns the data in an array of tuples format, where each tuple contains a user's wallet address and the corresponding claimable LPTS amount.
    public shared (message) func getLPTS() : async [(Text, Nat)] {
      assert (_isAdmin(message.caller));
      return Iter.toArray(userClaimableLPTSHash.entries());
    };

    /// The `swapToMPTS` function is a public shared asynchronous function that swaps a specified amount of LPTS (Liquidity Pool Token Shares) to MPTS (Mining Pool Token Shares) for the caller. Here's a step-by-step description of how the function works:
    /// 1. **Function Signature**:
    ///    - The function is declared as `public shared (message)`, meaning it can be called by external actors.
    ///    - It takes a single parameter `amount` of type `Nat`, which represents the amount of LPTS to be swapped to MPTS.
    ///    - The function returns a `T.TransferRes` indicating the result of the swap.
    /// 2. **Burn LPTS**:
    ///    - The function calls `burnLPTS(message.caller, amount)` to burn the specified amount of LPTS for the caller and awaits its result.
    ///    - The result is stored in the variable `burnLPTS_`.
    /// 3. **Handle Burn Result**:
    ///    - The function uses a `switch` statement to handle the result of the burn operation:
    ///      - If the burn is successful (`#success(number)`), it proceeds to mint MPTS.
    ///      - If the burn fails (`#error(msg)`), it returns an error indicating the failure to burn LPTS.
    /// 4. **Mint MPTS**:
    ///    - If the burn is successful, the function calls `MPTS.icrc1_transfer` to mint the specified amount of MPTS for the caller.
    ///    - It specifies the transfer details, including:
    ///      - `amount`: The amount of MPTS to be minted.
    ///      - `fee`: An optional fee of 0 units.
    ///      - `created_at_time`: Not set (null).
    ///      - `from_subaccount`: Not set (null).
    ///      - `to`: The destination wallet (the caller's wallet).
    ///      - `memo`: Not set (null).
    /// 5. **Handle Transfer Result**:
    ///    - The function uses a `switch` statement to handle the result of the transfer:
    ///      - If the transfer is successful (`#Ok(number)`), it returns `#success(number)`.
    ///      - If the transfer fails (`#Err(msg)`), it returns an error indicating the failure to mint MPTS.
    /// 6. **Return Default Error**:
    ///    - If any other errors occur, the function returns a default error "other".
    ///
    /// In summary, the `swapToMPTS` function swaps a specified amount of LPTS to MPTS for the caller by first burning the LPTS and then minting the MPTS. It handles various error cases and returns the result of the swap operation. If the burn or mint operation fails, it returns an error indicating the failure. If the swap is successful, it returns the success result.
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

    /// The `swapToLPTS` function is a public shared asynchronous function that swaps a specified amount of MPTS (Mining Pool Token Shares) to LPTS (Liquidity Pool Token Shares) for the caller. Here's a step-by-step description of how the function works:
    /// 1. **Function Signature**:
    ///   - The function is declared as `public shared (message)`, meaning it can be called by external actors.
    ///   - It takes a single parameter `amount` of type `Nat`, which represents the amount of MPTS to be swapped to LPTS.
    ///   - The function returns a `T.TransferRes` indicating the result of the swap.
    /// 2. **Burn MPTS**:
    ///   - The function calls `burnMPTS(message.caller, amount)` to burn the specified amount of MPTS for the caller and awaits its result.
    ///   - The result is stored in the variable `burnLPTS_`.
    /// 3. **Handle Burn Result**:
    ///   - The function uses a `switch` statement to handle the result of the burn operation:
    ///     - If the burn is successful (`#success(number)`), it proceeds to mint LPTS.
    ///     - If the burn fails (`#error(msg)`), it returns an error indicating the failure to burn MPTS.
    /// 4. **Mint LPTS**:
    ///   - If the burn is successful, the function calls `LPTS.icrc1_transfer` to mint the specified amount of LPTS for the caller.
    ///   - It specifies the transfer details, including:
    ///     - `amount`: The amount of LPTS to be minted.
    ///     - `fee`: An optional fee of 0 units.
    ///     - `created_at_time`: Not set (null).
    ///     - `from_subaccount`: Not set (null).
    ///     - `to`: The destination wallet (the caller's wallet).
    ///     - `memo`: Not set (null).
    /// 5. **Handle Transfer Result**:
    ///   - The function uses a `switch` statement to handle the result of the transfer:
    ///     - If the transfer is successful (`#Ok(number)`), it returns `#success(number)`.
    ///     - If the transfer fails (`#Err(msg)`), it returns an error indicating the failure to mint LPTS.
    /// 6. **Return Default Error**:
    ///   - If any other errors occur, the function returns a default error "other".
    ///
    /// In summary, the `swapToLPTS` function swaps a specified amount of MPTS to LPTS for the caller by first burning the MPTS and then minting the LPTS. It handles various error cases and returns the result of the swap operation. If the burn or mint operation fails, it returns an error indicating the failure. If the swap is successful, it returns the success result.
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

    /// The `burnMPTS` function is an asynchronous function that burns a specified amount of MPTS (Mining Pool Token Shares) from a user's account. Here's a step-by-step description of how the function works:
    /// 1. **Function Signature**:
    ///    - The function is declared as `async`, meaning it performs asynchronous operations.
    ///    - It takes two parameters:
    ///      - `owner_`: The principal of the user from whose account the MPTS will be burned.
    ///      - `amount_`: The amount of MPTS to be burned (as `Nat`).
    ///    - The function returns a `T.TransferRes` indicating the result of the burn operation.
    /// 2. **Perform Burn Operation**:
    ///    - The function calls `MPTS.icrc2_transfer_from` to burn the specified amount of MPTS from the user's account.
    ///    - It specifies the transfer details, including:
    ///      - `from`: The user's account from which the MPTS will be burned.
    ///      - `amount`: The amount of MPTS to be burned.
    ///      - `fee`: Not set (null).
    ///      - `created_at_time`: Not set (null).
    ///      - `from_subaccount`: Not set (null).
    ///      - `to`: The destination account (the canister's account).
    ///      - `spender_subaccount`: Not set (null).
    ///      - `memo`: Not set (null).
    /// 3. **Handle Transfer Result**:
    ///    - The function uses a `switch` statement to handle the result of the transfer:
    ///      - If the transfer is successful (`#Ok(number)`), it returns `#success(number)`.
    ///      - If the transfer fails (`#Err(msg)`), it handles specific error cases:
    ///        - `#BadFee(number)`: Returns `#error("Bad Fee")`.
    ///        - `#GenericError(number)`: Returns `#error("Generic")`.
    ///        - `#BadBurn(number)`: Returns `#error("BadBurn")`.
    ///        - `#InsufficientFunds(number)`: Returns `#error("Insufficient Funds")`.
    ///        - `#InsufficientAllowance(number)`: Returns `#error("Insufficient Allowance")`.
    ///        - Other errors: Prints "ICP err" and returns `#error("ICP transfer other error")`.
    ///
    /// In summary, the `burnMPTS` function burns a specified amount of MPTS from a user's account by calling the `MPTS.icrc2_transfer_from` method. It handles various error cases and returns the result of the burn operation. If the burn is successful, it returns the success result; otherwise, it returns an error indicating the failure.
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

    /// The `burnLPTS` function is an asynchronous function that burns a specified amount of LPTS (Liquidity Pool Token Shares) from a user's account. Here's a step-by-step description of how the function works:
    /// 1. **Function Signature**:
    ///   - The function is declared as `async`, meaning it performs asynchronous operations.
    ///   - It takes two parameters:
    ///     - `owner_`: The principal of the user from whose account the LPTS will be burned.
    ///     - `amount_`: The amount of LPTS to be burned (as `Nat`).
    ///   - The function returns a `T.TransferRes` indicating the result of the burn operation.
    /// 2. **Perform Burn Operation**:
    ///   - The function calls `LPTS.icrc2_transfer_from` to burn the specified amount of LPTS from the user's account.
    ///   - It specifies the transfer details, including:
    ///     - `from`: The user's account from which the LPTS will be burned.
    ///     - `amount`: The amount of LPTS to be burned.
    ///     - `fee`: Not set (null).
    ///     - `created_at_time`: Not set (null).
    ///     - `from_subaccount`: Not set (null).
    ///     - `to`: The destination account (the canister's account).
    ///     - `spender_subaccount`: Not set (null).
    ///     - `memo`: Not set (null).
    /// 3. **Handle Transfer Result**:
    ///   - The function uses a `switch` statement to handle the result of the transfer:
    ///     - If the transfer is successful (`#Ok(number)`), it returns `#success(number)`.
    ///     - If the transfer fails (`#Err(msg)`), it handles specific error cases:
    ///       - `#BadFee(number)`: Returns `#error("Bad Fee")`.
    ///       - `#GenericError(number)`: Returns `#error("Generic")`.
    ///       - `#BadBurn(number)`: Returns `#error("BadBurn")`.
    ///       - `#InsufficientFunds(number)`: Returns `#error("Insufficient Funds")`.
    ///       - `#InsufficientAllowance(number)`: Returns `#error("Insufficient Allowance")`.
    ///       - Other errors: Prints "ICP err" and returns `#error("ICP transfer other error")`.
    ///
    /// In summary, the `burnLPTS` function burns a specified amount of LPTS from a user's account by calling the `LPTS.icrc2_transfer_from` method. It handles various error cases and returns the result of the burn operation. If the burn is successful, it returns the success result; otherwise, it returns an error indicating the failure.
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

    /// The `claimMPTS` function is a public shared asynchronous function that allows a user to claim their claimable MPTS (Mining Pool Token Shares). Here's a step-by-step description of how the function works:
    /// 1. **Function Signature**:
    ///    - The function is declared as `public shared (message)`, meaning it can be called by external actors.
    ///    - It takes no parameters.
    ///    - The function returns a `T.TransferRes` indicating the result of the claim operation.
    /// 2. **Check Claimable MPTS**:
    ///    - The function checks if there are any claimable MPTS for the caller in `userClaimableMPTSHash` using `Principal.toText(message.caller)` as the key.
    ///    - It uses a `switch` statement to handle the result:
    ///      - If the result is `?claimable`, it means there are claimable MPTS for the caller, and the amount is stored in the variable `claimable`.
    ///      - If the result is `null`, it means there are no claimable MPTS for the caller, and the function returns `#error("no claimable")`.
    /// 3. **Perform Transfer**:
    ///    - If there are claimable MPTS, the function calls `MPTS.icrc1_transfer` to transfer the claimable MPTS to the caller's account.
    ///    - It specifies the transfer details, including:
    ///      - `amount`: The amount of MPTS to be transferred.
    ///      - `fee`: An optional fee of 0 units.
    ///      - `created_at_time`: Not set (null).
    ///      - `from_subaccount`: Not set (null).
    ///      - `to`: The destination wallet (the caller's wallet).
    ///      - `memo`: Not set (null).
    /// 4. **Handle Transfer Result**:
    ///    - The function uses a `switch` statement to handle the result of the transfer:
    ///      - If the transfer is successful (`#Ok(number)`), it updates `userClaimableMPTSHash` to set the claimable amount to 0 for the caller and returns `#success(number)`.
    ///      - If the transfer fails (`#Err(msg)`), it returns `#error("error")`.
    ///
    /// In summary, the `claimMPTS` function allows a user to claim their claimable MPTS by transferring the claimable amount to the caller's account. It handles various error cases and returns the result of the claim operation. If the transfer is successful, it updates the claimable amount to 0 and returns the success result. If there are no claimable MPTS or the transfer fails, it returns an error indicating the failure.
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

    /// The `claimLPTS` function is a public shared asynchronous function that allows a user to claim their claimable LPTS (Liquidity Pool Token Shares). Here's a step-by-step description of how the function works:
    /// 1. **Function Signature**:
    ///    - The function is declared as `public shared (message)`, meaning it can be called by external actors.
    ///    - It takes no parameters.
    ///    - The function returns a `T.TransferRes` indicating the result of the claim operation.
    /// 2. **Check Claimable LPTS**:
    ///    - The function checks if there are any claimable LPTS for the caller in `userClaimableLPTSHash` using `Principal.toText(message.caller)` as the key.
    ///    - It uses a `switch` statement to handle the result:
    ///      - If the result is `?claimable`, it means there are claimable LPTS for the caller, and the amount is stored in the variable `claimable`.
    ///      - If the result is `null`, it means there are no claimable LPTS for the caller, and the function returns `#error("no claimable")`.
    /// 3. **Perform Transfer**:
    ///    - If there are claimable LPTS, the function calls `LPTS.icrc1_transfer` to transfer the claimable LPTS to the caller's account.
    ///    - It specifies the transfer details, including:
    ///      - `amount`: The amount of LPTS to be transferred.
    ///      - `fee`: An optional fee of 0 units.
    ///      - `created_at_time`: Not set (null).
    ///      - `from_subaccount`: Not set (null).
    ///      - `to`: The destination wallet (the caller's wallet).
    ///      - `memo`: Not set (null).
    /// 4. **Handle Transfer Result**:
    ///    - The function uses a `switch` statement to handle the result of the transfer:
    ///      - If the transfer is successful (`#Ok(number)`), it updates `userClaimableLPTSHash` to set the claimable amount to 0 for the caller and returns `#success(number)`.
    ///      - If the transfer fails (`#Err(msg)`), it returns `#error("error")`.
    ///
    /// In summary, the `claimLPTS` function allows a user to claim their claimable LPTS by transferring the claimable amount to the caller's account. It handles various error cases and returns the result of the claim operation. If the transfer is successful, it updates the claimable amount to 0 and returns the success result. If there are no claimable LPTS or the transfer fails, it returns an error indicating the failure.
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

    /// The `setLOKBTC` function is a public shared asynchronous function that sets the address of the lokBTC token. Here's a step-by-step description of how the function works:
    /// 1. **Function Signature**:
    ///   - The function is declared as `public shared (message)`, meaning it can be called by external actors.
    ///   - It takes a single parameter `address` of type `Text`, which represents the new address of the lokBTC token.
    ///   - The function returns `async ()`, indicating it performs asynchronous operations and returns no value.
    /// 2. **Admin Check**:
    ///   - The function ensures that the caller is an admin by calling `assert(_isAdmin(message.caller))`.
    /// 3. **Set lokBTC Address**:
    ///   - The function sets the global variable `lokBTC` to the provided `address`.
    ///
    /// In summary, the `setLOKBTC` function sets the address of the lokBTC token, ensuring that only admins can perform this operation. It updates the global `lokBTC` variable with the new address provided as a parameter.
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

    /// The `updateckBTCBalance` function is a public shared asynchronous function that updates the ckBTC balance by calling an external actor. Here's a step-by-step description of how the function works:
    /// 1. **Function Signature**:
    ///   - The function is declared as `public shared (message)`, meaning it can be called by external actors.
    ///   - It takes no parameters.
    ///   - The function returns `async ()`, indicating it performs asynchronous operations and returns no value.
    /// 2. **Define Minter Actor**:
    ///   - The function defines an actor `Minter` with the principal `"mqygn-kiaaa-aaaar-qaadq-cai"`.
    ///   - The actor has a method `update_balance` that takes a record with an optional `subaccount` field of type `?Nat` and returns an asynchronous result of type `variant { #Ok : [UtxoStatus]; #Err : UpdateBalanceError }`.
    /// 3. **Call Update Balance**:
    ///   - The function calls `Minter.update_balance` with a record where `subaccount` is set to `null`.
    ///   - The result of the call is stored in the variable `result`.
    ///
    /// In summary, the `updateckBTCBalance` function updates the ckBTC balance by calling the `update_balance` method of an external actor. It defines the actor with the specified principal, calls the `update_balance` method with a `null` subaccount, and stores the result. The function performs this operation asynchronously and does not return any value.
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

    /// The `addLiquidity` function is a public shared asynchronous function that allows a user to add liquidity to the system by transferring ckBTC. Here's a step-by-step description of how the function works:
    /// 1. **Function Signature**:
    ///    - The function is declared as `public shared (message)`, meaning it can be called by external actors.
    ///    - It takes a single parameter `amount_` of type `Nat`, which represents the amount of ckBTC to be added as liquidity.
    ///    - The function returns a `T.AddLiquidityResult` indicating the result of the liquidity addition.
    /// 2. **Pause Check**:
    ///    - The function ensures that the system is not paused by calling `assert(_isNotPaused())`.
    /// 3. **Transfer ckBTC**:
    ///    - The function calls `transferCKBTCFrom(message.caller, amount_)` to transfer the specified amount of ckBTC from the caller's account.
    ///    - The result of the transfer is stored in the variable `transferRes_`.
    /// 4. **Handle Transfer Result**:
    ///    - The function uses a `switch` statement to handle the result of the transfer:
    ///      - If the transfer is successful (`#success(x)`), it proceeds to update the shares and liquidity.
    ///      - If the transfer fails (`#error(txt)`), it prints an error message and returns `#transferFailed(txt)`.
    /// 5. **Update Shares**:
    ///    - If the transfer is successful, the function increments `totalShares` by `amount_`.
    ///    - It initializes `updatedShare` to `amount_`.
    ///    - The function checks if the caller already has shares in `sharesHash`:
    ///      - If the caller has shares (`?currentShare`), it updates the caller's share by adding `amount_` to the existing share and updates `sharesHash`.
    ///      - If the caller does not have shares (`null`), it creates a new share entry for the caller with `amount_` and updates `sharesHash`.
    /// 6. **Update LOKBTC Shares**:
    ///    - The function calls `LOKBTC.updateShare` to update the total shares and the caller's share in the LOKBTC canister.
    /// 7. **Create Liquidity Record**:
    ///    - The function creates a liquidity record with the following details:
    ///      - `id`: The current value of `liquidityIndex`.
    ///      - `wallet`: The caller's principal.
    ///      - `time`: The current time.
    ///      - `amount`: The amount of ckBTC added as liquidity.
    ///      - `token`: The token type, set to "CKBTC".
    ///    - The function adds the liquidity record to `addLiquidityHash`.
    /// 8. **Update User Liquidity**:
    ///    - The function checks if the caller already has liquidity entries in `userLiquidityHash`:
    ///      - If the caller has liquidity entries (`?list`), it appends the new liquidity index to the existing list and updates `userLiquidityHash`.
    ///      - If the caller does not have liquidity entries (`null`), it creates a new entry for the caller with the new liquidity index.
    /// 9. **Increment Liquidity Index**:
    ///    - The function increments `liquidityIndex` by 1.
    /// 10. **Return Success**:
    ///     - The function returns `#success(x)` to indicate that the liquidity addition was successful.
    ///
    /// In summary, the `addLiquidity` function allows a user to add liquidity to the system by transferring ckBTC. It updates the user's shares and liquidity records, ensures that the system is not paused, and handles various error cases. If the liquidity addition is successful, it returns the success result; otherwise, it returns an error indicating the failure.
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

    /// The `transferCKBTCFrom` function is an asynchronous function that transfers a specified amount of ckBTC from a user's account to the lokaCKBTCPool. Here's a step-by-step description of how the function works:
    /// 1. **Function Signature**:
    ///   - The function is declared as `async`, meaning it performs asynchronous operations.
    ///   - It takes two parameters:
    ///     - `owner_`: The principal of the user from whose account the ckBTC will be transferred.
    ///     - `amount_`: The amount of ckBTC to be transferred (as `Nat`).
    ///   - The function returns a `T.TransferResult` indicating the result of the transfer operation.
    /// 2. **Perform Transfer Operation**:
    ///   - The function calls `CKBTC.icrc2_transfer_from` to transfer the specified amount of ckBTC from the user's account to the lokaCKBTCPool.
    ///   - It specifies the transfer details, including:
    ///     - `from`: The user's account from which the ckBTC will be transferred.
    ///     - `amount`: The amount of ckBTC to be transferred.
    ///     - `fee`: An optional fee of 0 units.
    ///     - `created_at_time`: Not set (null).
    ///     - `from_subaccount`: Not set (null).
    ///     - `to`: The destination account (lokaCKBTCPool).
    ///     - `spender_subaccount`: Not set (null).
    ///     - `memo`: Not set (null).
    /// 3. **Handle Transfer Result**:
    ///   - The function uses a `switch` statement to handle the result of the transfer:
    ///     - If the transfer is successful (`#Ok(number)`), it returns `#success(number)`.
    ///     - If the transfer fails (`#Err(msg)`), it handles specific error cases:
    ///       - `#BadFee(number)`: Returns `#error("Bad Fee")`.
    ///       - `#GenericError(number)`: Returns `#error("Generic")`.
    ///       - `#BadBurn(number)`: Returns `#error("BadBurn")`.
    ///       - `#InsufficientFunds(number)`: Returns `#error("Insufficient Funds")`.
    ///       - `#InsufficientAllowance(number)`: Returns `#error("Insufficient Allowance")`.
    ///       - Other errors: Prints "ICP err" and returns `#error("ICP transfer other error")`.
    ///
    /// In summary, the `transferCKBTCFrom` function transfers a specified amount of ckBTC from a user's account to the lokaCKBTCPool by calling the `CKBTC.icrc2_transfer_from` method. It handles various error cases and returns the result of the transfer operation. If the transfer is successful, it returns the success result; otherwise, it returns an error indicating the failure.
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

    /// The `claimCKBTC` function is a public shared asynchronous function that allows a user to claim their matured claimable ckBTC. Here's a step-by-step description of how the function works:
    /// 1. **Function Signature**:
    ///    - The function is declared as `public shared (message)`, meaning it can be called by external actors.
    ///    - It takes no parameters.
    ///    - The function returns a `T.TransferRes` indicating the result of the claim operation.
    /// 2. **Check Matured Claimable ckBTC**:
    ///    - The function checks if there are any matured claimable ckBTC for the caller in `userMaturedClaimableCKBTCHash` using `Principal.toText(message.caller)` as the key.
    ///    - It uses a `switch` statement to handle the result:
    ///      - If the result is `?claimable`, it means there are matured claimable ckBTC for the caller, and the amount is stored in the variable `claimable`.
    ///      - If the result is `null`, it means there are no matured claimable ckBTC for the caller, and the function returns `#error("claim not found")`.
    /// 3. **Perform Transfer**:
    ///    - If there are matured claimable ckBTC, the function calls `CKBTC.icrc1_transfer` to transfer the claimable ckBTC to the caller's account.
    ///    - It specifies the transfer details, including:
    ///      - `amount`: The amount of ckBTC to be transferred.
    ///      - `fee`: An optional fee of 0 units.
    ///      - `created_at_time`: Not set (null).
    ///      - `from_subaccount`: Not set (null).
    ///      - `to`: The destination wallet (the caller's wallet).
    ///      - `memo`: Not set (null).
    /// 4. **Handle Transfer Result**:
    ///    - The function uses a `switch` statement to handle the result of the transfer:
    ///      - If the transfer is successful (`#Ok(number)`), it updates `userMaturedClaimableCKBTCHash` to set the claimable amount to 0 for the caller and returns `#success(number)`.
    ///      - If the transfer fails (`#Err(msg)`), it returns `#error("transfer error")`.
    ///
    /// In summary, the `claimCKBTC` function allows a user to claim their matured claimable ckBTC by transferring the claimable amount to the caller's account. It handles various error cases and returns the result of the claim operation. If the transfer is successful, it updates the claimable amount to 0 and returns the success result. If there are no matured claimable ckBTC or the transfer fails, it returns an error indicating the failure.
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

    /// The `requestRedeem` function is a public shared asynchronous function that allows a user to request the redemption of a specified amount of ckBTC. Here's a step-by-step description of how the function works:
    /// 1. **Function Signature**:
    ///   - The function is declared as `public shared (message)`, meaning it can be called by external actors.
    ///   - It takes a single parameter `amount_` of type `Nat`, which represents the amount of ckBTC to be redeemed.
    ///   - The function returns a variant type with two possible values: `#success : T.Claimable` if the operation is successful, or `#error : Text` if the operation fails.
    /// 2. **Pause Check**:
    ///   - The function ensures that the system is not paused by calling `assert(_isNotPaused())`.
    /// 3. **Set Redemption Time**:
    ///   - The function calculates the redemption time as the current time plus 24 hours and stores it in the variable `timeRedeem`.
    /// 4. **Check User Shares**:
    ///   - The function checks if the caller has enough shares in `sharesHash` using `Principal.toText(message.caller)` as the key.
    ///   - It uses a `switch` statement to handle the result:
    ///     - If the result is `?share` and the user has enough shares (at least `amount_ + 10`), it proceeds with the redemption process.
    ///     - If the result is `null` or the user does not have enough shares, it returns `#error("error")`.
    /// 5. **Update Shares**:
    ///   - If the user has enough shares, the function updates the total shares and the user's shares:
    ///     - It decrements `totalShares` by `amount_ + 10`.
    ///     - It updates the user's shares in `sharesHash` by subtracting `amount_ + 10` from the existing shares.
    ///     - It calls `LOKBTC.updateShare` to update the total shares and the user's shares in the LOKBTC canister.
    /// 6. **Create Claim Object**:
    ///   - The function creates a `T.Claimable` object with the following details:
    ///     - `id`: The current value of `claimCKBTCId`.
    ///     - `amount`: The amount to be redeemed.
    ///     - `time`: The redemption time (`timeRedeem`).
    /// 7. **Update Claimable ckBTC Hash**:
    ///   - The function checks if the caller already has claimable ckBTC entries in `userClaimableCKBTCHash`:
    ///     - If the caller has claimable entries (`?claimable_`), it updates the existing entries with the new claim object.
    ///     - If the caller does not have claimable entries (`null`), it creates a new entry for the caller with the new claim object.
    /// 8. **Increment Claim ID**:
    ///   - The function increments `claimCKBTCId` by 1.
    /// 9. **Return Success**:
    ///   - The function returns `#success(claimObject)` to indicate that the redemption request was successful.
    ///
    /// In summary, the `requestRedeem` function allows a user to request the redemption of a specified amount of ckBTC by updating the user's shares and creating a claimable ckBTC entry. It ensures that the system is not paused, handles various error cases, and returns the result of the redemption request. If the request is successful, it returns the success result with the claim object; otherwise, it returns an error indicating the failure.
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
            //update totalshare and share to lokbtc canister
            totalShares -= (amount_ + 10);
            var shr = {
              walletAddress = Principal.toText(message.caller);
              share = share.share - amount_;
            };
            sharesHash.put(Principal.toText(message.caller), shr);
            //update totalshare and share to lokbtc canister
            await LOKBTC.updateShare(Principal.toText(message.caller), (share.share -(amount_ + 10)), totalShares);
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

    /// The `send_http` function is an asynchronous function that sends an HTTP GET request to a specified URL and returns the response as a `Text`. Here's a step-by-step description of how the function works:
    /// 1. **Function Signature**:
    ///   - The function is declared as `async`, meaning it performs asynchronous operations.
    ///   - It takes a single parameter `url_` of type `Text`, which represents the URL to which the HTTP request will be sent.
    ///   - The function returns a `Text` value representing the response from the HTTP request.
    /// 2. **Initialize Actor**:
    ///   - The function initializes an actor `ic` of type `T.IC` with the principal `"aaaaa-aa"`, which represents the Internet Computer management canister.
    /// 3. **Set URL**:
    ///   - The function assigns the input parameter `url_` to a local variable `url`.
    /// 4. **Set Request Headers**:
    ///   - The function defines a list of HTTP request headers, including:
    ///     - `User-Agent`: Identifies the client making the request.
    ///     - `Content-Type`: Specifies the media type of the request.
    ///     - `x-api-key`: An API key for authentication.
    /// 5. **Debug Print**:
    ///   - The function prints a debug message indicating the URL being accessed.
    /// 6. **Set Transform Context**:
    ///   - The function defines a `transform_context` of type `T.TransformContext`, which includes:
    ///     - `function`: A reference to the `transform` function.
    ///     - `context`: An empty `Blob` context.
    /// 7. **Set HTTP Request Arguments**:
    ///   - The function defines an `http_request` of type `T.HttpRequestArgs`, which includes:
    ///     - `url`: The URL to which the request will be sent.
    ///     - `max_response_bytes`: Optional, not set in this case.
    ///     - `headers`: The list of request headers.
    ///     - `body`: Optional, not set in this case.
    ///     - `method`: The HTTP method, set to `#get`.
    ///     - `transform`: The transform context.
    /// 8. **Add Cycles**:
    ///   - The function adds 30 billion cycles to the request using `Cycles.add(30_000_000_000)`.
    /// 9. **Send HTTP Request**:
    ///   - The function sends the HTTP request using `await ic.http_request(http_request)` and stores the response in `http_response`.
    /// 10. **Decode Response**:
    ///     - The function converts the response body from `Blob` to `Text` using `Text.decodeUtf8`.
    ///     - If the decoding is successful, it assigns the decoded text to `decoded_text`.
    ///     - If the decoding fails, it assigns "No value returned" to `decoded_text`.
    /// 11. **Return Response**:
    ///     - The function returns the `decoded_text` as the result of the HTTP request.
    ///
    /// In summary, the `send_http` function sends an HTTP GET request to a specified URL with predefined headers, processes the response, and returns the response body as a `Text`. It includes error handling for decoding the response body and adds cycles to ensure the request can be processed.
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

    /// The `rebaseLOKBTC` function is a public shared asynchronous function that triggers a rebase operation for the lokBTC token. Here's a step-by-step description of how the function works:
    /// 1. **Function Signature**:
    ///   - The function is declared as `public shared (message)`, meaning it can be called by external actors.
    ///   - It takes no parameters.
    ///   - The function returns a `Text` value representing the result of the rebase operation.
    /// 2. **Admin Check**:
    ///   - The function ensures that the caller is an admin by calling `assert(_isAdmin(message.caller))`.
    /// 3. **Trigger Rebase**:
    ///   - The function calls `LOKBTC.forceRebase()` to trigger the rebase operation for the lokBTC token.
    ///   - The result of the rebase operation is stored in the variable `a`.
    /// 4. **Return Result**:
    ///   - The function converts the result of the rebase operation from `Nat` to `Text` using `Nat.toText(a)` and returns it.
    ///
    /// In summary, the `rebaseLOKBTC` function triggers a rebase operation for the lokBTC token, ensuring that only admins can perform this operation. It calls the `forceRebase` method on the `LOKBTC` actor and returns the result of the rebase operation as a `Text` value.
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
};
