module escrow::escrow;    
    // imports
    use sui::coin::{Self, Coin}; 
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};
    use sui::clock::{Self, Clock};

    // Error codes
    const ENotOwner: u64 = 1;
    const ENotUnlocked: u64 = 2;
    const EInsufficientFunds: u64 = 3;
    const EInvalidUnlockTime: u64 = 4;

    // The Escrow object that holds the money and also unlock timestamp
    public struct Escrow has key, store {
        id: UID,
        owner: address,
        unlock_time: u64, 
        // Unix timestamp in milliseconds (Epoch and Time). Epoch changed roughly every 24 hours. Time represents the current time in milliseconds since the Unix Epoch
        // You can check it out here:https://move-book.com/programmability/epoch-and-time.html
        funds: Balance<SUI>
    }

    // Initilaize a new escrow with a specific unlock timestamp
    public fun create_escrow(
        owner: address,
        unlock_time: u64,
        funds: Coin<SUI>,
        clock: &Clock,
        ctx: &mut TxContext
    ): Escrow {
        // Set the unlock time to the future
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

    // Withdraw money from escrow (only after unlock time and by owner)
    // also transfer the coin back to the user
    public fun withdraw(
        escrow: Escrow,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let Escrow { id, owner, unlock_time, funds } = escrow;
        
        // Check if who wants to withdraw is the owner
        assert!(owner == tx_context::sender(ctx), ENotOwner);
        
        // Check if unlock time has passed
        let current_time = clock::timestamp_ms(clock);
        assert!(current_time >= unlock_time, ENotUnlocked);
        
        // Clean up the object by deleting
        object::delete(id);
        
        // Convert balance back to coin and return. 
        let coin = coin::from_balance(funds, ctx);
        transfer::public_transfer(coin, owner);
    }

    // Partial withdrawal (only after unlock time and by owner)
    public fun withdraw_partial(
        escrow: &mut Escrow,
        amount: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // Check if who wants to withdraw is the owner
        assert!(escrow.owner == tx_context::sender(ctx), ENotOwner);
        
        // Check if unlock time has passed
        let current_time = clock::timestamp_ms(clock);
        assert!(current_time >= escrow.unlock_time, ENotUnlocked);
        
        // Check if there is enough money available
        assert!(balance::value(&escrow.funds) >= amount, EInsufficientFunds);
        
        // Split the balance and return as coin
        let withdrawn_balance = balance::split(&mut escrow.funds, amount);
        let coin = coin::from_balance(withdrawn_balance, ctx);
        transfer::public_transfer(coin, escrow.owner);
    }

    // Add more funds to existing escrow (only by owner)
    public fun add_funds(
        escrow: &mut Escrow,
        additional_funds: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        // Check if it is the owner
        assert!(escrow.owner == tx_context::sender(ctx), ENotOwner);
        
        // Add the funds to the escrow balance
        let additional_balance = coin::into_balance(additional_funds);
        balance::join(&mut escrow.funds, additional_balance);
    }

    // Cancel escrow and return funds (only before unlock time and by owner)
    public fun cancel_escrow(
        escrow: Escrow,
        clock: &Clock,
        ctx: &mut TxContext
    ): Coin<SUI> {
        let Escrow { id, owner, unlock_time, funds } = escrow;
        
        // Check if it is the owner
        assert!(owner == tx_context::sender(ctx), ENotOwner);
        
        // You can only cancel before unlock time
        let current_time = clock::timestamp_ms(clock);
        assert!(current_time < unlock_time, ENotUnlocked);
        
        // Clean up the object
        object::delete(id);
        
        // Return all funds
        coin::from_balance(funds, ctx)
    }

    // Another way of returning the coin back to the user
    // let return_coin = cancel_escrow(escrow, clock, ctx);
    // transfer::public_transfer(refund_coin, owner_address);

    // Get escrow owner
    public fun owner(escrow: &Escrow): address {
        escrow.owner
    }

    // Get unlock timestamp
    public fun unlock_time(escrow: &Escrow): u64 {
        escrow.unlock_time
    }

    // Get current balance amount
    public fun balance_value(escrow: &Escrow): u64 {
        balance::value(&escrow.funds)
    }

    // Check if escrow is unlocked
    public fun is_unlocked(escrow: &Escrow, clock: &Clock): bool {
        let current_time = clock::timestamp_ms(clock);
        current_time >= escrow.unlock_time
    }

    // Get time remaining until unlock
    public fun time_until_unlock(escrow: &Escrow, clock: &Clock): u64 {
        let current_time = clock::timestamp_ms(clock);
        if (current_time >= escrow.unlock_time) {
            0
        } else {
            escrow.unlock_time - current_time
        }
    }