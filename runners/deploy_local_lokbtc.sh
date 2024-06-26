# This script is used to deploy and configure an ICRC token canister on the Internet Computer network.
# Ensure you have dfx (the DFINITY Canister SDK) installed and configured before running this script.

# Exit immediately if a command exits with a non-zero status, and print each command.
set -ex

# --- Configuration Section ---

# Identity configuration. Replace '{production_identity}' with your production identity name. This identity needs to be a controller for your canister
PRODUCTION_IDENTITY="lokaDeployer"
dfx identity use $PRODUCTION_IDENTITY

# Canister identitfication - You need to create this canister either via dfx or throught the nns console
PRODUCTION_CANISTER="lokbtc"

#check your cycles. The system needs at least 2x the archiveCycles below to create the archive canister.  We suggest funding the initial canister with 4x the cycles configured in archiveCycles and then using a tool like cycle ops to monitor your cycles. You will need to add the created archive canisters(created after the first maxActiveRecords are created) to cycleops manually for it to be monitored.



# Token configuration
TOKEN_NAME="LOKBTC"
TOKEN_SYMBOL="LOKBTC"
TOKEN_LOGO="data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMSIgaGVpZ2h0PSIxIiB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciPjxyZWN0IHdpZHRoPSIxMDAlIiBoZWlnaHQ9IjEwMCUiIGZpbGw9InJlZCIvPjwvc3ZnPg=="
TOKEN_DECIMALS=8
TOKEN_FEE=100
MAX_SUPPLY=null
MIN_BURN_AMOUNT=0
MAX_MEMO=64
MAX_ACCOUNTS=100000000000
SETTLE_TO_ACCOUNTS=99999000000

# Automatically fetches the principal ID of the currently used identity.
ADMIN_PRINCIPAL=$(dfx identity get-principal)

# --- Deployment Section ---

dfx deploy lokbtc --argument "(opt record {icrc1 = opt record {
  name = opt \"LOKBTC\";
  symbol = opt \"LOKBTC\";
  logo = opt \"data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMSIgaGVpZ2h0PSIxIiB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciPjxyZWN0IHdpZHRoPSIxMDAlIiBoZWlnaHQ9IjEwMCUiIGZpbGw9InJlZCIvPjwvc3ZnPg==\";
  decimals = 8;
  fee = opt variant { Fixed = 100};
  minting_account = opt record{
    owner = principal \"7wewg-uyaaa-aaaak-qihwa-cai\";
    subaccount = null;
  };
  max_supply = null;
  min_burn_amount = opt 0;
  max_memo = opt 64;
  advanced_settings = null;
  metadata = null;
  fee_collector = null;
  transaction_window = null;
  permitted_drift = null;
}; 
icrc2 = opt record{
  max_approvals_per_account = opt 10000000000000000000000000;
  max_allowance = opt variant { TotalSupply = null};
  fee = opt variant { ICRC1 = null};
  advanced_settings = null;
  max_approvals = opt 10000000;
  settle_to_approvals = opt 9990000;
}; 
icrc3 = opt record {
  maxActiveRecords = 3000;
  settleToRecords = 2000;
  maxRecordsInArchiveInstance = 100000000;
  maxArchivePages = 62500;
  archiveIndexType = variant {Stable = null};
  maxRecordsToArchive = 8000;
  archiveCycles = 20_000_000_000_000;
  supportedBlocks = vec {};
  archiveControllers = null;
};
icrc4 = opt record {
  max_balances = opt 200;
  max_transfers = opt 200;
  fee = opt variant { ICRC1 = null};
};})"

# Fetch the canister ID after deployment
ICRC_CANISTER=$(dfx canister id lokbtc)

# Output the canister ID
echo $ICRC_CANISTER

# --- Initialization and Query Section ---

# Initialize the admin configuration of the token canister
dfx canister call lokbtc admin_init



