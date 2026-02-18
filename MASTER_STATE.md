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
- Connectivity check: `starkli block-number --rpc "$STARKNET_RPC_URL"` ✅

## Accounts
- Deployer name: starkshield_deployer
- Address: 0xf32c3c7accaf38cce8b22048f6de9eac7ecda1ac72b3ba103d628655f2dc3f
- Deployed: true
- Deploy tx: 0x06b9e304a4ca4de138f58ca52e0aeb04d45c2d8bc01bd874ef1c80bb019b7b98

## Repo Structure (Current)
- /contracts (Scarb package, Foundry tests enabled)
- /.env.example (template only)
- /.gitignore

## Last Verified Build
- `cd contracts && scarb build` ✅
EOF