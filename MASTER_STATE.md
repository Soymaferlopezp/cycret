# Cycret — Master State

## Project
- Name: Cycret
- Network: Starknet Sepolia Testnet
- Scope: Privacy pool on Starknet (fixed denomination, shielded-by-default)

## Toolchain (Verified)
- OS: Ubuntu 24.04.3 LTS (noble)
- Rust: 1.93.1 (rustup)
- Scarb: 2.15.2
  - Cairo: 2.15.0
  - Sierra: 1.7.0
- Starknet Foundry: snforge/sncast 0.56.0
- Starkli: 0.4.2

## RPC
- Provider: Alchemy
- Spec: JSON-RPC v0_10
- Env var: STARKNET_RPC_URL (not committed)
- Connectivity check: `starkli block-number --rpc "$STARKNET_RPC_URL"` Verified ✅

## Accounts
- Deployer name: starkshield_deployer
- Address: 0xf32c3c7accaf38cce8b22048f6de9eac7ecda1ac72b3ba103d628655f2dc3f
- Deployed: true
- Deploy tx: 0x06b9e304a4ca4de138f58ca52e0aeb04d45c2d8bc01bd874ef1c80bb019b7b98

## Merkle Tree Spec (Approved & Implemented)
- Depth: 10
- Capacity: 1024 leaves
- Hash: Pedersen
- Zeros: precomputed in code (NOT stored in storage)
- Leaf: commitment felt252 used as-is (no re-hash)
- No root history (MVP stage)

## Contract Architecture (Compiled)
### Storage Model

Config:
- token: ContractAddress
- denomination: u256
- tree_depth: u8 (hardcoded to 10)

Merkle State
- root: felt252
- next_index: u32
- filled_subtrees: Map<u8, felt252> (levels 0–9)
- commitments_by_index: Map<u32, felt252>

Nullifier Tracking
- nullifier_spent: Map<felt252, bool>

## Implemented Functionality
### Deposit

1. Requires prior approve(pool, denomination) on STRK.
2. Executes:
`transfer_from(caller, pool, denomination)`
3. Reverts if transfer fails.
4. Inserts commitment into incremental Merkle tree.
5. Updates:
- filled_subtrees
- root
- next_index
6. Stores commitment by index.
7. Emits Deposit(index, commitment, new_root, memo) event.

Tree full protection:
- Reverts if next_index >= 1024.

## Withdraw (MVP, no ZK yet)
1. Checks:
`nullifier_spent[nullifier] == false`
2. Executes:
`transfer(recipient, denomination)`
3. Reverts if transfer fails.
4. Marks:
`nullifier_spent[nullifier] = true`
5. Emits Withdraw(nullifier, recipient) event.
ZK proof verification is not yet integrated.

## Merkle Implementation Details
- Implemented in merkle.cairo.
- Deterministic zeros derived in-code.
- Incremental insertion algorithm:
  * Uses bit decomposition of index.
  * Updates cached filled_subtrees.
  * Hashes upward using Pedersen.
- Root stored on-chain.

## Security Model (Current Stage)
✔ Double-spend prevention via nullifiers
✔ Fixed denomination prevents amount leakage
✔ Incremental tree prevents storage explosion
✔ Reverts on failed token transfers
✔ Reverts if tree is full

Not yet implemented:
- ZK proof verification
- Root history tracking
- Reentrancy analysis (will evaluate when integrating verifier)

## Repo Structure (Current)

- /contracts
  * shielded_pool.cairo
  * merkle.cairo
  * interfaces.cairo
  * errors.cairo
- /contracts/tests
- Scarb.toml
- snfoundry.toml
- /.env.example
- /.gitignore

## Last Verified Build
```bash
cd contracts
scarb build
```

Result:
```bash
Finished dev profile target(s)
```
✅ Compilation successful with Cairo 2.15.0
✅ No breaking errors
⚠ Minor unused import warnings only

## Current Status Summary
- Infrastructure: Stable
- Contract MVP: Functional
- Merkle: Implemented and connected
- Token Transfers: Integrated
- Nullifier Protection: Active
- ZK Verifier: Pending