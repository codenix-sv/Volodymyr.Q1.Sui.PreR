module bank::bank {
    use sui::object::{Self, UID};
    use sui::coin::{Self, Coin};
    use sui::tx_context::{TxContext};
    use sui::sui::SUI;
    use sui::dynamic_field;
    use sui::balance;
    use sui::balance::{Balance};
    use sui::transfer;
    use sui::tx_context;

    const FEE: u128 = 5;

    const ENotEnoughBalance: u64 = 1;

    struct Bank has key {
        id: UID
    }

    struct OwnerCap has key, store {
        id: UID
    }

    struct UserBalance has copy, drop, store { user: address }
    struct AdminBalance has copy, drop, store {}

    fun init(ctx: &mut TxContext) {
        let bank = Bank { id: object::new(ctx) };
        dynamic_field::add(&mut bank.id, AdminBalance { }, balance::zero<SUI>());
        transfer::share_object(bank);

        let owner_cap = OwnerCap { id: object::new(ctx) };
        transfer::transfer(owner_cap, tx_context::sender(ctx));
    }

    public fun deposit(self: &mut Bank, token: Coin<SUI>, ctx: &mut TxContext) {
        let value = coin::value(&token);

        let deposit_value = value - (((value as u128) * fee(self) / 100) as u64);

        let admin_fee = value - deposit_value;
        let admin_coin = coin::split(&mut token, admin_fee, ctx);

        balance::join(dynamic_field::borrow_mut<AdminBalance, Balance<SUI>>(&mut self.id, AdminBalance {}), coin::into_balance(admin_coin));

        let sender = tx_context::sender(ctx);

        if (dynamic_field::exists_(&self.id, UserBalance { user: sender })) {
            balance::join(dynamic_field::borrow_mut<UserBalance, Balance<SUI>>(&mut self.id, UserBalance { user: sender }), coin::into_balance(token));
        } else {
            dynamic_field::add(&mut self.id, UserBalance { user: sender }, coin::into_balance(token));
        };
    }

    public fun withdraw(self: &mut Bank, ctx: &mut TxContext): Coin<SUI> {
        let sender = tx_context::sender(ctx);

        if (dynamic_field::exists_(&self.id, UserBalance { user: sender })) {
            coin::from_balance(dynamic_field::remove(&mut self.id, UserBalance { user: sender }), ctx)
        } else {
            coin::zero(ctx)
        }
    }

    public fun partial_withdraw(self: &mut Bank, value: u64, ctx: &mut TxContext): Coin<SUI> {
        let user_balance = dynamic_field::borrow_mut<UserBalance, Balance<SUI>>(&mut self.id, UserBalance { user: tx_context::sender(ctx) });

        assert!(balance::value(user_balance) >= value, ENotEnoughBalance);

        coin::take(user_balance, value, ctx)
    }

    public fun claim(_: &OwnerCap, self: &mut Bank, ctx: &mut TxContext): Coin<SUI> {
        let balance_mut = dynamic_field::borrow_mut<AdminBalance, Balance<SUI>>(&mut self.id, AdminBalance {});
        let total_admin_bal = balance::value(balance_mut);
        coin::take(balance_mut, total_admin_bal, ctx)
    }

    public fun user_balance(self: &Bank, user: address): u64 {
        let key = UserBalance { user };
        if (dynamic_field::exists_(&self.id, key)) {
            balance::value(dynamic_field::borrow<UserBalance, Balance<SUI>>(&self.id, key))
        } else {
            0
        }
    }

    public fun admin_balance(self: &Bank): u64 {
        balance::value(dynamic_field::borrow<AdminBalance, Balance<SUI>>(&self.id, AdminBalance {}))
    }

    public fun fee(_: &Bank): u128 {
        FEE
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx)
    }
}
