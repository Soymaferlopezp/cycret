# Cycret — Starknet Setup (Ubuntu + Sepolia)

This repo targets **Starknet Sepolia Testnet**.
Tooling is pinned by explicit versions; avoid ad-hoc upgrades.

## 1) Environment (verified)

- OS: Ubuntu 24.04.3 LTS (noble)
- Rust: 1.93.1 (rustup)
- Scarb: 2.15.2
  - Cairo: 2.15.0
  - Sierra: 1.7.0
- Starknet Foundry:
  - snforge: 0.56.0
  - sncast: 0.56.0
- Starkli: 0.4.2

## 2) Install (Ubuntu)

### 2.1 Prereqs
```bash
sudo apt update
sudo apt install -y git curl build-essential pkg-config libssl-dev
```
### 2.2 Rust (rustup)

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source "$HOME/.cargo/env"
rustc --version
cargo --version
```
### 2.3 Scarb (pins Cairo toolchain)

Install Scarb 2.15.2:
```bash
curl --proto '=https' --tlsv1.2 -sSf https://docs.swmansion.com/scarb/install.sh | bash -s -- -v 2.15.2
export PATH="$HOME/.local/bin:$PATH"
scarb --version
```

### 2.4 Starknet Foundry (snforge/sncast)

```bash
snforge --version
sncast --version
```
### 2.5 Starkli
```bash
starkli --version
which starkli
```

## 3) RPC Provider (Alchemy v0_10)

Create an RPC endpoint using Alchemy Starknet Sepolia with JSON-RPC spec v0_10.

Export RPC URL (do not commit secrets):

```bash
export STARKNET_RPC_URL="https://starknet-sepolia.g.alchemy.com/starknet/version/rpc/v0_10/<YOUR_KEY>"
```
Check connectivity:
```bash
starkli block-number --rpc "$STARKNET_RPC_URL"
```
## 4) Account (OpenZeppelin) — Sepolia
### 4.1 Create counterfactual account
```bash
sncast account create --name starkshield_deployer --url "$STARKNET_RPC_URL"
sncast account list
```
### 4.2 Prefund
Send test STRK to the account address shown in sncast account create.
(Deployment requires fees.)

### 4.3 Deploy account on-chain

```bash
sncast account deploy --name starkshield_deployer --url "$STARKNET_RPC_URL"
sncast account list
```
## 5) Contracts (Scarb)
### 5.1 Create contracts package
Repo includes contracts/ created via:
```bash
scarb new contracts
```
### Build
```bash
cd contracts
scarb build
```
## 6) Notes / Safety
* Never commit RPC keys.
* Never share account private keys.
* Prefer explicit versions; do not upgrade tooling without approval.
EOF

