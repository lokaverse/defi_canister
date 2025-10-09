# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Loka is a decentralized, collateralized, tokenized Bitcoin mining ecosystem built on the Internet Computer using Motoko. It handles three actors: miners, liquidity providers (LPs), and retail investors. The project leverages ckBTC (a non-custodial Bitcoin wrapper on ICP) for fast, safe Bitcoin transactions.

**Key website:** https://lokamining.com

## Core Architecture

### Main Canisters

1. **pool** (`src/pool/main.mo`)
   - Manages miners and mining operations
   - Handles hashrate tracking from external stratum servers
   - Distributes mining rewards to miners
   - Manages miner withdrawals (ckBTC and fiat via jWallet)
   - Revenue sharing between miners
   - Integrates with f2pool API for hashrate verification
   - Uses `ckbtc_prod` (mainnet ckBTC) as dependency

2. **defi** (`src/defi/main.mo`)
   - Liquidity provider (LP) staking and rewards management
   - Handles ckBTC staking from LPs
   - Issues lokBTC tokens to stakers (rebase-able tokens)
   - Manages MPTS (miner reward token) and LPTS (LP reward token) distribution
   - Redemption mechanism with 24-hour cooldown period
   - Scheduled rebase operations
   - Uses `ckbtc_test`, `lokbtc`, `mpts`, `lpts` as dependencies

3. **lokbtc** (`src/lokbtc/main.mo`)
   - Rebase-able ICRC-1 token implementation
   - Total supply rebases every 24 hours based on pool wallet ckBTC balance
   - User balances are proportional to staked ckBTC share
   - Custom transfer restrictions (burn requires admin)
   - Implements ICRC-1, ICRC-2, ICRC-3, and ICRC-4 standards
   - Share-based accounting system (not direct balance storage)

4. **devpool** (`src/devpool/main.mo`)
   - Development/test version of pool canister
   - Uses `ckbtc_test` for testing

### Token Canisters

- **ckbtc_test** - Local test ICRC-1 ledger for development
- **ckbtc_prod** - Remote reference to mainnet ckBTC (mxzaz-hqaaa-aaaar-qaada-cai)
- **mpts** - Miner reward token (ICRC-1 ledger)
- **lpts** - LP reward token (ICRC-1 ledger)

### Key Concepts

**Rebase Mechanism:**
- lokBTC total supply = pool's ckBTC balance
- User balance = (user's share / total shares) * rebased supply
- Rebase triggered by defi canister based on scheduled intervals

**Dual Reward System:**
- Miners receive: ckBTC (from actual mining) + MPTS tokens
- LPs receive: Mining yield (proportional to stake) + LPTS tokens

**Withdrawal Flow:**
- Pool canister manages two withdrawal types: crypto (direct ckBTC transfer) and fiat (via jWallet integration)
- Defi canister: requestRedeem() creates claimable ckBTC with 24-hour cooldown

## Common Commands

### Development Setup

```bash
# Install dependencies (uses mops package manager)
mops install

# Start local replica
dfx start --clean --background

# Deploy all canisters locally
dfx deploy
```

### Deployment

**Deploy test environment tokens:**
```bash
sh ./runners/deploy_test_ckbtc.sh
sh ./runners/deploy_test_alltokens.sh
```

**Deploy main canisters:**
```bash
# Deploy pool (uses ckbtc_prod on mainnet)
dfx deploy pool --argument '(record{admin = principal "[controller-principal]"})' --network ic
dfx canister call pool init '(false)' --network ic

# Deploy defi
sudo dfx deploy defi --argument '(record{admin = principal "[controller-principal]"})' --network ic
sudo dfx canister call defi init --network ic

# Deploy lokBTC
sudo sh ./runners/deploy_local_lokbtc.sh  # or deploy_lokbtc.sh for mainnet

# Deploy reward tokens (MPTS/LPTS)
# Note: Set defi canister as minting account before deploying
# See README.md lines 85-130 for detailed instructions
```

**Development pool:**
```bash
sh ./runners/deploy_dev_pool.sh
```

### Key Deployment Notes

1. **Token Deployment Order:**
   - Deploy ckbtc_test first (for dev)
   - Deploy defi canister and save principal ID
   - Deploy MPTS and LPTS with defi principal as minting account
   - Deploy lokBTC with defi principal as minting account
   - Deploy pool canister last

2. **Initialization Sequence:**
   - Each canister requires `init()` call after deployment
   - Set cross-canister references (setCKBTCPool, setPoolCanister, setMinter)
   - Configure admin accounts using `addAdmin()`

### Testing & Building

```bash
# Build all canisters
dfx build

# Deploy and test specific canister
dfx deploy [canister-name]
dfx canister call [canister-name] [method-name] '[args]'
```

### Package Management

Uses **mops** (Motoko package manager) defined in `mops.toml`:
- base: 0.11.0
- icrc1-mo, icrc2-mo, icrc3-mo, icrc4-mo
- cert (ic-certification)

Build command in dfx.json: `"packtool": "mops sources"`

## Architecture Patterns

### State Management

All canisters use the stable/transient pattern:
- Stable variables (prefixed with `stable var`) persist across upgrades
- HashMap data structures for runtime efficiency
- `preupgrade` system function converts HashMaps to stable arrays (`_` suffix)
- `postupgrade` system function rebuilds HashMaps from stable arrays

Example from lokbtc/main.mo:186-188:
```motoko
private var sharesHash = HashMap.HashMap<Text, Nat>(0, Text.equal, Text.hash);
private stable var shareHash_ : [(Text, Nat)] = []; // for upgrade
```

### Inter-Canister Communication

Canisters reference each other via:
```motoko
import DEFI "canister:defi";
import CKBTC "canister:ckbtc_prod";
import LOKBTC "canister:lokbtc";
```

Critical dependencies:
- **pool** → CKBTC, DEFI
- **defi** → CKBTC, LOKBTC, MPTS, LPTS
- **lokbtc** → CKBTC

### Admin & Authorization

Common pattern across all canisters:
```motoko
private var siteAdmin : Principal = admin;
private var adminHash = HashMap.HashMap<Text, Nat>(0, Text.equal, Text.hash);

func _isAdmin(p : Principal) : Bool {
    // Check against siteAdmin or adminHash
}

public shared (message) func someAdminFunction() : async () {
    assert(_isAdmin(message.caller));
    // ... admin logic
}
```

### HTTP Outcalls

Pool and defi canisters use HTTP outcalls for external data:
- Pool: f2pool API integration for hashrate verification
- Defi: Scheduled timestamp synchronization
- Pattern: `send_http()` function with transform context

## File Structure

```
src/
├── Token.mo              # Generic ICRC token template
├── pool/
│   ├── main.mo          # Mining pool operations
│   └── types.mo         # Pool type definitions
├── defi/
│   ├── main.mo          # LP staking & rewards
│   └── types.mo         # Defi type definitions
├── lokbtc/
│   └── main.mo          # Rebase-able ICRC-1 token
├── devpool/
│   ├── main.mo          # Development pool
│   └── types.mo         # Devpool types
└── ckbtctest/
    └── main.mo          # Test ckBTC canister

runners/                  # Deployment scripts
mops.toml                # Package dependencies
dfx.json                 # Canister configuration
```

## Development Workflow

1. **Making Changes:**
   - Modify Motoko source files
   - Run `dfx build` to check compilation
   - Test locally with `dfx deploy --network local`

2. **Testing:**
   - Use `dfx canister call` for direct method invocation
   - Check canister state with query methods
   - Monitor cycles usage for production canisters

3. **Upgrading Canisters:**
   - Ensure `preupgrade` and `postupgrade` handle all state correctly
   - Test upgrade path on local replica first
   - Use `dfx canister install --mode upgrade` for production

4. **State Management:**
   - Always add new stable variables with underscore suffix for arrays
   - Update both `preupgrade` and `postupgrade` system functions
   - Test that state persists correctly across upgrades

## Important Configuration

**Production Principals:**
- ckBTC mainnet: `mxzaz-hqaaa-aaaar-qaada-cai`
- ckBTC minter: `mqygn-kiaaa-aaaar-qaadq-cai`
- jWallet vault: `43hyn-pv646-27kl3-hhrll-wbdtc-k4idi-7mbyz-uvwxj-hgktq-topls-rae`

**Network Modes:**
- Development: Use `ckbtc_test` and local deployments
- Production: Switch imports to `ckbtc_prod` (see pool/main.mo:29)

**API Keys:**
- f2pool API key stored in pool canister (stable var f2poolKey)
- External API integration requires cycles for HTTP outcalls

## Critical Functions

**Pool Canister:**
- `distributeRevenue()` - Main mining reward distribution
- `withdrawCKBTC()` / `withdrawIDR()` - Handle withdrawals
- `syncHashrate()` - Fetch current hashrate from f2pool

**Defi Canister:**
- `addLiquidity()` - LP stakes ckBTC
- `requestRedeem()` - LP requests ckBTC withdrawal (24hr cooldown)
- `claimCKBTC()` - LP claims matured withdrawals
- `rebaseLOKBTC()` - Admin triggers lokBTC supply rebase

**LokBTC Canister:**
- `updateShare()` - Called by defi to update user's share
- `forceRebase()` - Recalculates total supply from pool balance
- Custom `icrc1_balance_of()` - Calculates balance from share ratio

## References

- Frontend repos: https://github.com/lokaverse/defi, https://github.com/lokaverse/pool
- IC SDK docs: https://internetcomputer.org/docs/current/developer-docs/
- ICRC standards: https://github.com/dfinity/ICRC-1
