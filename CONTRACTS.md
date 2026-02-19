# Cycret Contracts — Shielded Pool (MVP)

This package contains the Cairo smart contracts for **Cycret** (StarkShield scope): a fixed-denomination shielded pool on Starknet Sepolia.

## Network & Fixed Parameters

- Network: **Starknet Sepolia**
- Token: **STRK (Sepolia L2)**
  - Address: `0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d`
  - Decimals: `18`
- Fixed denomination: **0.1 STRK**
  - `denomination_u256 = 100000000000000000`
- Merkle tree:
  - Depth: `10`
  - Capacity: `2^10 = 1024` leaves
  - Hash: **Pedersen**
  - Incremental tree stored on-chain via `root`, `next_index`, `filled_subtrees`
- Nullifiers: on-chain mapping to prevent double-spend
- ZK proof verification: **NOT implemented yet** (placeholder only)

---

## Contract Overview

### Main contract
- `src/shielded_pool.cairo`
  - Holds pool state, performs deposits/withdrawals, emits events.

### Merkle library
- `src/merkle.cairo`
  - Pure functions to compute the incremental Merkle tree:
    - `initial_filled_subtrees() -> Array<felt252>`
    - `insert_leaf(index, leaf, filled) -> (new_root, new_filled)`
  - **zeros are precomputed in code** (derived deterministically), NOT stored in contract storage.

### ERC20 interface
- `src/interfaces.cairo`
  - Minimal ERC20 interface used via dispatcher:
    - `transfer_from(sender, recipient, amount) -> bool`
    - `transfer(recipient, amount) -> bool`
    - `balance_of(account) -> u256`

---

## Storage Model (on-chain)

`ShieldedPool` storage (high-level):

### Config
- `token: ContractAddress` — STRK token address
- `denomination: u256` — fixed amount required for deposit / paid out on withdraw
- `tree_depth: u8` — fixed to 10

### Merkle incremental state
- `root: felt252` — current Merkle root
- `next_index: u32` — next leaf index to insert (0..1023)
- `filled_subtrees: Map<u8, felt252>`
  - per-level cached left nodes used by incremental insertion
  - keys: `0..9`
- `commitments_by_index: Map<u32, felt252>`
  - leaf storage (index → commitment)

### Nullifier mapping
- `nullifier_spent: Map<felt252, bool>`
  - `true` if a nullifier has been used (prevents double spend)

---

## Merkle Structure (Incremental, Depth 10)

### zeros (in-code only)
- `zeros[0] = 0`
- `zeros[i+1] = pedersen(zeros[i], zeros[i])`

These zeros provide the default sibling nodes for empty subtrees. They are derived deterministically in `merkle.cairo`.

### insert_leaf(index, leaf)
Given:
- `index` = current `next_index`
- `leaf` = `commitment` (used **as-is**, no re-hash)
- `filled_subtrees` = cached subtree values

The algorithm iterates levels `0..9`:
- If `index` bit at level is `0` (left child):
  - pair `(leaf_or_parent, zeros[level])`
  - store current node into `filled_subtrees[level]`
- If bit is `1` (right child):
  - pair `(filled_subtrees[level], leaf_or_parent)`
- Hash upward with Pedersen until the root.

**Safety:**
- Reverts if `index >= 1024` (tree full)

---

## Nullifier Logic

- A withdraw includes a `nullifier` identifier.
- The contract checks `nullifier_spent[nullifier]`:
  - if `true` → revert (`NULLIFIER_SPENT`)
  - else → continue
- After a successful withdraw transfer, it sets:
  - `nullifier_spent[nullifier] = true`

This prevents reusing the same note/withdrawal twice.

---

## State Transitions

### Deposit(commitment, memo)
1. **Token transfer**:
   - Uses `transfer_from(caller, pool, denomination)`
   - Requires the user to call `approve(pool, denomination)` on STRK first.
   - Reverts if transfer fails (`TOKEN_TRANSFER_FAILED`)
2. **Merkle update**:
   - Loads `filled_subtrees` from storage into an array
   - Calls `insert_leaf(next_index, commitment, filled)`
   - Writes updated `filled_subtrees` back to storage
   - Updates `root` and increments `next_index`
3. Stores `commitments_by_index[next_index] = commitment`
4. Emits `Deposit(index, commitment, new_root, memo)`

### Withdraw(nullifier, recipient, proof_placeholder)
> Proof verification is a placeholder in this MVP.
1. Checks `nullifier_spent[nullifier]` is `false`
2. Transfers `denomination` to `recipient` via `transfer(recipient, amount)`
   - Reverts if transfer fails (`TOKEN_TRANSFER_FAILED`)
3. Marks `nullifier_spent[nullifier] = true`
4. Emits `Withdraw(nullifier, recipient)`

---

## Notes / Future Work

- Add root history (if required by ZK circuit / proof verification)
- Integrate ZK verifier on-chain (withdraw must verify:
  - membership of commitment in Merkle root
  - nullifier derivation
  - correct recipient and amount)
- Encrypted memo spec + client-side decryption flow (events already carry memo payload)

---

## Build

```bash
cd contracts
scarb build
```

---
## Integration Notes — filled_subtrees Map ↔ Array

The incremental Merkle insertion runs on an `Array<felt252>` of length 10, but the contract stores
`filled_subtrees` on-chain as `Map<u8, felt252>` with keys 0..9.

### Map → Array (read)
In `deposit()` we read levels in strict order 0..9 and append to a local array.

Common bug: reading keys out of order silently changes the computed root.

### Array → Map (write)
After calling `merkle::insert_leaf(...)`, we persist the returned array back to storage keys 0..9.

Important: in this toolchain `Array::at()` returns `@felt252`, so we must dereference when writing:
`*arr.at(i_usize)`.

### Constructor init
Constructor initializes the on-chain `filled_subtrees` map using `merkle::initial_filled_subtrees()`,
writing indices 0..9.

### Deposit ordering (avoid inconsistent state)
Recommended order:
1) `transfer_from` (if it fails, do not mutate Merkle/state)
2) check capacity (`next_index < 1024`)
3) Map→Array, insert, Array→Map
4) update `root` and `next_index`
5) emit event

### Failure modes to watch
- wrong level order (0..9)
- forgetting `*` on `Array::at()`
- incrementing `next_index` before transfer/insert succeeds
