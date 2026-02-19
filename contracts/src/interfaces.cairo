use starknet::ContractAddress;

#[starknet::interface]
pub trait IERC20<TState> {
    fn transfer_from(
        ref self: TState,
        sender: ContractAddress,
        recipient: ContractAddress,
        amount: u256
    ) -> bool;

    fn transfer(
        ref self: TState,
        recipient: ContractAddress,
        amount: u256
    ) -> bool;

    fn balance_of(self: @TState, account: ContractAddress) -> u256;
}
