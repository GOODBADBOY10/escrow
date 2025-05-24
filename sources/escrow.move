module escrow::escrow {
    use sui::coin::{Self, Coin}; 
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};
    use sui::clock::{Self, Clock};
    // use sui::object::{Self, UID};
    // use sui::tx_context::TxContext;

    // Error codes
    const ENotOwner: u64 = 1;
    const ENotUnlocked: u64 = 2;
    const EInsufficientFunds: u64 = 3;
    const EInvalidUnlockTime: u64 = 4;

    // Escrow object that holds the funds and unlock timestamp
    public struct Escrow has key, store {
        id: UID,
        owner: address,
        unlock_time: u64, // Unix timestamp in milliseconds
        funds: Balance<SUI>
    }

    /// Create a new escrow with a specific unlock timestamp
    public fun create_escrow(
        owner: address,
        unlock_time: u64,
        funds: Coin<SUI>,
        clock: &Clock,
        ctx: &mut TxContext
    ): Escrow {
        // Ensure unlock time is in the future
        let current_time = clock::timestamp_ms(clock);
        assert!(unlock_time > current_time, EInvalidUnlockTime);
        
        let balance_funds = coin::into_balance(funds);
        Escrow {
            id: object::new(ctx),
            owner,
            unlock_time,
            funds: balance_funds
        }
    }

    /// Withdraw funds from escrow (only after unlock time and by owner)
    public fun withdraw(
        escrow: Escrow,
        clock: &Clock,
        ctx: &mut TxContext
    ): Coin<SUI> {
        let Escrow { id, owner, unlock_time, funds } = escrow;
        
        // Check if caller is the owner
        assert!(owner == tx_context::sender(ctx), ENotOwner);
        
        // Check if unlock time has passed
        let current_time = clock::timestamp_ms(clock);
        assert!(current_time >= unlock_time, ENotUnlocked);
        
        // Clean up the object
        object::delete(id);
        
        // Convert balance back to coin and return
        coin::from_balance(funds, ctx)
    }

    /// Partial withdrawal (only after unlock time and by owner)
    public fun withdraw_partial(
        escrow: &mut Escrow,
        amount: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ): Coin<SUI> {
        // Check if caller is the owner
        assert!(escrow.owner == tx_context::sender(ctx), ENotOwner);
        
        // Check if unlock time has passed
        let current_time = clock::timestamp_ms(clock);
        assert!(current_time >= escrow.unlock_time, ENotUnlocked);
        
        // Check if sufficient funds
        assert!(balance::value(&escrow.funds) >= amount, EInsufficientFunds);
        
        // Split the balance and return as coin
        let withdrawn_balance = balance::split(&mut escrow.funds, amount);
        coin::from_balance(withdrawn_balance, ctx)
    }

    /// Add more funds to existing escrow (only by owner)
    public fun add_funds(
        escrow: &mut Escrow,
        additional_funds: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        // Check if caller is the owner
        assert!(escrow.owner == tx_context::sender(ctx), ENotOwner);
        
        // Add the funds to the escrow balance
        let additional_balance = coin::into_balance(additional_funds);
        balance::join(&mut escrow.funds, additional_balance);
    }

    /// Cancel escrow and return funds (only before unlock time and by owner)
    public fun cancel_escrow(
        escrow: Escrow,
        clock: &Clock,
        ctx: &mut TxContext
    ): Coin<SUI> {
        let Escrow { id, owner, unlock_time, funds } = escrow;
        
        // Check if caller is the owner
        assert!(owner == tx_context::sender(ctx), ENotOwner);
        
        // Can only cancel before unlock time
        let current_time = clock::timestamp_ms(clock);
        assert!(current_time < unlock_time, ENotUnlocked);
        
        // Clean up the object
        object::delete(id);
        
        // Return all funds
        coin::from_balance(funds, ctx)
    }

    // === View Functions ===

    /// Get escrow owner
    public fun owner(escrow: &Escrow): address {
        escrow.owner
    }

    /// Get unlock timestamp
    public fun unlock_time(escrow: &Escrow): u64 {
        escrow.unlock_time
    }

    /// Get current balance amount
    public fun balance_value(escrow: &Escrow): u64 {
        balance::value(&escrow.funds)
    }

    /// Check if escrow is unlocked
    public fun is_unlocked(escrow: &Escrow, clock: &Clock): bool {
        let current_time = clock::timestamp_ms(clock);
        current_time >= escrow.unlock_time
    }

    /// Get time remaining until unlock (returns 0 if already unlocked)
    public fun time_until_unlock(escrow: &Escrow, clock: &Clock): u64 {
        let current_time = clock::timestamp_ms(clock);
        if (current_time >= escrow.unlock_time) {
            0
        } else {
            escrow.unlock_time - current_time
        }
    }

    // === Test Functions ===
    #[test_only]
    public fun create_escrow_for_testing(
        owner: address,
        unlock_time: u64,
        funds: Balance<SUI>,
        ctx: &mut TxContext
    ): Escrow {
        Escrow {
            id: object::new(ctx),
            owner,
            unlock_time,
            funds
        }
    }
}