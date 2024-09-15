import Time "mo:base/Time";
//import Principal "motoko/util/Principal";

module {

    public type Token = Principal;

    public type OrderId = Nat32;

    public type TransactionHistory = {
        id : Nat;
        //caller: Text;
        time : Int;
        action : Text;
        //receiver : Text;
        amount : Text;
        txid : Text;
        currency : Text;
        //provider : Text;
    };

    public type WithdrawalHistory = {
        id : Nat;
        //caller: Text;
        time : Int;
        action : Text;
        jwalletId : Text;
        bankId : Text;
        //receiver : Text;
        amount : Text;
        txid : Text;
        currency : Text;
        username : Text;
        wallet : Text;
        memo : ?Blob;
        //provider : Text;
    };

    public type TransferError = {
        #GenericError : { message : Text; error_code : Nat };
        #TemporarilyUnavailable;
        #BadBurn : { min_burn_amount : Nat };
        #Duplicate : { duplicate_of : Nat };
        #BadFee : { expected_fee : Nat };
        #CreatedInFuture : { ledger_time : Nat64 };
        #TooOld;
        #InsufficientFunds : { balance : Nat };
    };

    public type Result = { #Ok : Nat; #Err : TransferError };

    public type Account = { owner : Principal; subaccount : ?Blob };

    public type TransferArg = {
        to : Account;
        fee : ?Nat;
        memo : ?Blob;
        from_subaccount : ?Blob;
        created_at_time : ?Nat64;
        amount : Nat;
    };

    public type WalletAddress = {
        name : Text;
        address : Text;
        currency : Text;
    };

    public type BankAddress = {
        name : Text;
        accountNumber : Text;
        bankName : Text;
        jwalletId : Text;
    };

    public type Duration = { #seconds : Nat; #nanoseconds : Nat };

    public type MinerStatus = {
        id : Nat;
        var verified : Bool;
        var balance : Nat;
        var totalWithdrawn : Nat;
        var walletAddress : [WalletAddress];
        var bankAddress : [BankAddress];
        var transactions : [TransactionHistory];
        var totalSharedRevenue : Nat;
    };

    public type SharableMinerStatus = {
        id : Nat;
        verified : Bool;
        balance : Nat;
        totalWithdrawn : Nat;
        walletAddress : [WalletAddress];
        bankAddress : [BankAddress];
        transactions : [TransactionHistory];
        totalSharedRevenue : Nat;
    };

    public type ErrorLog = {
        id : Nat;
        time : Int;
        username : Text;
        error : Text;
        wallet : Text;
        time_text : Text;
    };

    public type RevenueShare = {
        userName : Text;
        wallet : Text;
        sharePercent : Nat;
    };

    public type Miner = {
        id : Nat;
        walletAddress : Principal;
        var username : Text;
        hashrate : Nat;
    };

    /*public type MinerReward = {
        id : Nat;
        var available : Float;
        var claimed : Float;
     };*/

    public type DistributionHistory = {
        time : Int;
        hashrate : Nat;
        sats : Nat;
        from : Text;
        fromUsername : Text;
    };

    public type Distribution = {
        id : Nat;
        time : Text;
        hashrate : Text;
        sats : Text;
        data : Text;
    };

    public type WDIDRResult = {
        #success : Nat;
        #failed : Text;
    };

    public type MinerData = {
        id : Nat;
        walletAddress : Principal;
        walletAddressText : Text;
        username : Text;
        hashrate : Nat;
        verified : Bool;
        balance : Nat;
        totalWithdrawn : Nat;
        totalReceivedSharedRevenue : Nat;
        receivedShareList : [(Text, RevenueShare)];
        savedWalletAddress : [WalletAddress];
        bankAddress : [BankAddress];
        transactions : [TransactionHistory];
        revenueHistory : [DistributionHistory];
        yesterdayRevenue : Nat;
        totalSharedPercent : Nat;
        shareList : [(Text, RevenueShare)];
    };

    public type Timestamp = Nat64;

    // First, define the Type that describes the Request arguments for an HTTPS outcall.

    public type HttpRequestArgs = {
        url : Text;
        max_response_bytes : ?Nat64;
        headers : [HttpHeader];
        body : ?[Nat8];
        method : HttpMethod;
        transform : ?TransformRawResponseFunction;
    };

    public type TransferRes = {
        #success : Nat;
        #error : Text;
    };

    public type HttpHeader = {
        name : Text;
        value : Text;
    };

    public type HttpMethod = {
        #get;
        #post;
        #head;
    };

    public type HttpResponsePayload = {
        status : Nat;
        headers : [HttpHeader];
        body : [Nat8];
    };

    // HTTPS outcalls have an optional "transform" key. These two types help describe it.
    // The transform function can transform the body in any way, add or remove headers, or modify headers.
    // This Type defines a function called 'TransformRawResponse', which is used above.

    public type TransformRawResponseFunction = {
        function : shared query TransformArgs -> async HttpResponsePayload;
        context : Blob;
    };

    // This Type defines the arguments the transform function needs.
    public type TransformArgs = {
        response : HttpResponsePayload;
        context : Blob;
    };

    public type CanisterHttpResponsePayload = {
        status : Nat;
        headers : [HttpHeader];
        body : [Nat8];
    };

    public type TransformContext = {
        function : shared query TransformArgs -> async HttpResponsePayload;
        context : Blob;
    };

    // Lastly, declare the IC management canister which you use to make the HTTPS outcall.
    public type IC = actor {
        http_request : HttpRequestArgs -> async HttpResponsePayload;
    };

};
