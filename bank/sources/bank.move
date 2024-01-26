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

    #[test_only]
    use sui::test_scenario;
    #[test_only]
    use sui::test_utils::assert_eq;

    const FEE: u128 = 5;
    
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
        
        let deposit_value = value - (((value as u128) * FEE / 100) as u64);
        
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

    public fun claim(_: &OwnerCap, self: &mut Bank, ctx: &mut TxContext): Coin<SUI> {
         let balance_mut = dynamic_field::borrow_mut<AdminBalance, Balance<SUI>>(&mut self.id, AdminBalance {});
         let total_admin_bal = balance::value(balance_mut);
         coin::take(balance_mut, total_admin_bal, ctx)
    }

   #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx)
    }

    #[test]
    fun test_init_success_init() {
        let admin = @0xA;

        let scenario_val = test_scenario::begin(admin);
        
        let scenario = &mut scenario_val;
        {
            let ctx = test_scenario::ctx(scenario);
            init_for_testing(ctx);
        };

        test_scenario::next_tx(scenario, admin);

        {
            let owner_cap = test_scenario::take_from_sender<OwnerCap>(scenario);
            let tested_bank = test_scenario::take_shared<Bank>(scenario);
            let admin_balance = dynamic_field::borrow<AdminBalance, Balance<SUI>>(&tested_bank.id, AdminBalance {});

            assert_eq(balance::value(admin_balance), 0);
            
            test_scenario::return_to_sender(scenario, owner_cap);
            test_scenario::return_shared(tested_bank);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_deposit_success() {
        let admin = @0xA;
        let user = @0xB;
        let deposit_amount = 100;

        let scenario_val = test_scenario::begin(admin);
        
        let scenario = &mut scenario_val;
        {
            init_for_testing(test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, user);
        {
            let tested_bank = test_scenario::take_shared<Bank>(scenario);
            let deposit_coin = sui::coin::mint_for_testing<SUI>(
                deposit_amount, 
                test_scenario::ctx(scenario)
            );

            deposit(&mut tested_bank, deposit_coin, test_scenario::ctx(scenario));
            test_scenario::return_shared(tested_bank);
        };

        test_scenario::next_tx(scenario, user);
        {
            let tested_bank = test_scenario::take_shared<Bank>(scenario);
            let admin_balance = dynamic_field::borrow<AdminBalance, Balance<SUI>>(&tested_bank.id, AdminBalance {});

            let expected_admin_deposite: u64 = (deposit_amount * (FEE as u64)) / 100; 
            assert_eq(balance::value(admin_balance), expected_admin_deposite);

            let user_balance = dynamic_field::borrow<UserBalance, Balance<SUI>>(&tested_bank.id, UserBalance { user: user });
            assert_eq(balance::value(user_balance), deposit_amount - expected_admin_deposite);

            test_scenario::return_shared(tested_bank);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_withdraw_success() {
        let admin = @0xA;
        let user = @0xB;
        let deposit_amount = 100;

        let scenario_val = test_scenario::begin(admin);
        
        let scenario = &mut scenario_val;
        {
            init_for_testing(test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, user);
        {
            let tested_bank = test_scenario::take_shared<Bank>(scenario);
            let deposit_coin = sui::coin::mint_for_testing<SUI>(
                deposit_amount, 
                test_scenario::ctx(scenario)
            );

            deposit(&mut tested_bank, deposit_coin, test_scenario::ctx(scenario));
            test_scenario::return_shared(tested_bank);
        };

        test_scenario::next_tx(scenario, user);
        {
            let tested_bank = test_scenario::take_shared<Bank>(scenario);
            
            let expected_admin_deposite: u64 = (deposit_amount * (FEE as u64)) / 100; 
            let user_balance = dynamic_field::borrow<UserBalance, Balance<SUI>>(&tested_bank.id, UserBalance { user: user });
            assert_eq(balance::value(user_balance), deposit_amount - expected_admin_deposite);

            let withdraw_coin = withdraw(&mut tested_bank, test_scenario::ctx(scenario));
            assert_eq(coin::value(&withdraw_coin), deposit_amount - expected_admin_deposite);

             coin::burn_for_testing(withdraw_coin);
            test_scenario::return_shared(tested_bank);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_claim_success() {
        let admin = @0xA;
        let user = @0xB;
        let deposit_amount = 100;

        let scenario_val = test_scenario::begin(admin);
        
        let scenario = &mut scenario_val;
        {
            init_for_testing(test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, user);
        {
            let tested_bank = test_scenario::take_shared<Bank>(scenario);
            let deposit_coin = sui::coin::mint_for_testing<SUI>(
                deposit_amount, 
                test_scenario::ctx(scenario)
            );

            deposit(&mut tested_bank, deposit_coin, test_scenario::ctx(scenario));
            test_scenario::return_shared(tested_bank);
        };

        test_scenario::next_tx(scenario, admin);
        {
            let tested_bank = test_scenario::take_shared<Bank>(scenario);
            let expected_admin_deposite: u64 = (deposit_amount * (FEE as u64)) / 100; 

            let owner_cap = test_scenario::take_from_sender<OwnerCap>(scenario);
            let withdraw_coin = claim(&owner_cap, &mut tested_bank, test_scenario::ctx(scenario));
            assert_eq(coin::value(&withdraw_coin), expected_admin_deposite);

            coin::burn_for_testing(withdraw_coin);
            test_scenario::return_shared(tested_bank);
            test_scenario::return_to_sender(scenario, owner_cap);
        };

        test_scenario::end(scenario_val);
    }
}