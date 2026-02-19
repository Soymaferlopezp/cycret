#[starknet::contract]
mod ShieldedPool {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use starknet::get_contract_address;
    use crate::interfaces::IERC20Dispatcher;
    use crate::interfaces::IERC20DispatcherTrait;
    use starknet::storage::{
        Map,
        StoragePointerReadAccess,
        StoragePointerWriteAccess,
        StorageMapReadAccess,
        StorageMapWriteAccess,
    };
    use core::array::ArrayTrait;

    use crate::merkle;

    // --------------------
    // Storage
    // --------------------
    #[storage]
    struct Storage {
        // config
        token: ContractAddress,
        denomination: u256,
        tree_depth: u8,

        // merkle incremental (depth=10)
        root: felt252,
        next_index: u32,
        filled_subtrees: Map<u8, felt252>,
        commitments_by_index: Map<u32, felt252>,

        // nullifiers
        nullifier_spent: Map<felt252, bool>,
    }

    // --------------------
    // Events
    // --------------------
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Deposit: Deposit,
        Withdraw: Withdraw,
    }

    #[derive(Drop, starknet::Event)]
    struct Deposit {
        index: u32,
        commitment: felt252,
        new_root: felt252,
        memo: Span<felt252>,
    }

    #[derive(Drop, starknet::Event)]
    struct Withdraw {
        nullifier: felt252,
        recipient: ContractAddress,
    }

    // --------------------
    // Constructor
    // --------------------
    #[constructor]
    fn constructor(ref self: ContractState, token: ContractAddress, denomination: u256) {
        self.token.write(token);
        self.denomination.write(denomination);
        self.tree_depth.write(10_u8);

        self.root.write(0);
        self.next_index.write(0);

        // Init filled_subtrees in storage from merkle zeros (depth=10)
        let filled = merkle::initial_filled_subtrees();
        self.filled_subtrees.write(0_u8, *filled.at(0_usize));
        self.filled_subtrees.write(1_u8, *filled.at(1_usize));
        self.filled_subtrees.write(2_u8, *filled.at(2_usize));
        self.filled_subtrees.write(3_u8, *filled.at(3_usize));
        self.filled_subtrees.write(4_u8, *filled.at(4_usize));
        self.filled_subtrees.write(5_u8, *filled.at(5_usize));
        self.filled_subtrees.write(6_u8, *filled.at(6_usize));
        self.filled_subtrees.write(7_u8, *filled.at(7_usize));
        self.filled_subtrees.write(8_u8, *filled.at(8_usize));
        self.filled_subtrees.write(9_u8, *filled.at(9_usize));
    }

    // --------------------
    // External
    // --------------------
    #[external(v0)]
    fn deposit(ref self: ContractState, commitment: felt252, memo: Span<felt252>) {

        // --- Token transfer (approve requerido) ---
        let caller = get_caller_address();
        let token = self.token.read();
        let amount = self.denomination.read();

        let ok = IERC20Dispatcher { contract_address: token }
            .transfer_from(caller, get_contract_address(), amount);


        if !ok {
            panic!("TOKEN_TRANSFER_FAILED");
        }

        // NOTE: transfer_from (approve requerido) se integra en el siguiente módulo.
        let idx = self.next_index.read();

        // revert if tree full
        if idx >= merkle::CAPACITY {
            panic!("TREE_FULL");
        }

        // Load filled_subtrees from storage Map<u8,felt252> into Array<felt252>
        let mut filled: Array<felt252> = ArrayTrait::new();
        filled.append(self.filled_subtrees.read(0_u8));
        filled.append(self.filled_subtrees.read(1_u8));
        filled.append(self.filled_subtrees.read(2_u8));
        filled.append(self.filled_subtrees.read(3_u8));
        filled.append(self.filled_subtrees.read(4_u8));
        filled.append(self.filled_subtrees.read(5_u8));
        filled.append(self.filled_subtrees.read(6_u8));
        filled.append(self.filled_subtrees.read(7_u8));
        filled.append(self.filled_subtrees.read(8_u8));
        filled.append(self.filled_subtrees.read(9_u8));

        // Insert leaf and get updated root + filled
        let (new_root, new_filled) = merkle::insert_leaf(idx, commitment, filled);

        // Persist updated filled_subtrees back to storage Map
        self.filled_subtrees.write(0_u8, *new_filled.at(0_usize));
        self.filled_subtrees.write(1_u8, *new_filled.at(1_usize));
        self.filled_subtrees.write(2_u8, *new_filled.at(2_usize));
        self.filled_subtrees.write(3_u8, *new_filled.at(3_usize));
        self.filled_subtrees.write(4_u8, *new_filled.at(4_usize));
        self.filled_subtrees.write(5_u8, *new_filled.at(5_usize));
        self.filled_subtrees.write(6_u8, *new_filled.at(6_usize));
        self.filled_subtrees.write(7_u8, *new_filled.at(7_usize));
        self.filled_subtrees.write(8_u8, *new_filled.at(8_usize));
        self.filled_subtrees.write(9_u8, *new_filled.at(9_usize));

        // Save commitment by index
        self.commitments_by_index.write(idx, commitment);

        // Update root + next_index
        self.root.write(new_root);
        self.next_index.write(idx + 1_u32);

        self.emit(Event::Deposit(Deposit { index: idx, commitment, new_root, memo }));
    }

    #[external(v0)]
    fn withdraw(
        ref self: ContractState,
        nullifier: felt252,
        recipient: ContractAddress,
        _proof: Span<felt252>,
    ) {
        // 1) Prevent double spend
        if self.nullifier_spent.read(nullifier) {
            panic!("NULLIFIER_SPENT");
        }

        // 2) Token transfer (proof verification comes later)
        let token = self.token.read();
        let amount = self.denomination.read();

        let ok = IERC20Dispatcher { contract_address: token }
            .transfer(recipient, amount);

        if !ok {
            panic!("TOKEN_TRANSFER_FAILED");
        }

        // 3) Mark nullifier as spent ONLY after successful transfer
        self.nullifier_spent.write(nullifier, true);

        // 4) Emit event
        self.emit(Event::Withdraw(Withdraw { nullifier, recipient }));
    }


    // --------------------
    // Views
    // --------------------
    #[external(v0)]
    fn get_root(self: @ContractState) -> felt252 {
        self.root.read()
    }

    #[external(v0)]
    fn get_next_index(self: @ContractState) -> u32 {
        self.next_index.read()
    }

    #[external(v0)]
    fn is_nullifier_spent(self: @ContractState, n: felt252) -> bool {
        self.nullifier_spent.read(n)
    }
}
