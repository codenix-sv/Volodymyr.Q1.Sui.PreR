#[test_only]
module bank::bank_tests {
    use sui::sui::SUI;
    use sui::test_utils::assert_eq;
    use sui::coin::{Self};
    use sui::test_scenario;
    use bank::bank::{Self, Bank, OwnerCap, ENotEnoughBalance};

    const ADMIN: address = @0xA;
    const USER: address = @0xB;

    #[test]
    fun test_init_success_init() {

        let scenario_val = test_scenario::begin(ADMIN);

        let scenario = &mut scenario_val;
        {
            let ctx = test_scenario::ctx(scenario);
            bank::init_for_testing(ctx);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let owner_cap = test_scenario::take_from_sender<OwnerCap>(scenario);
            let tested_bank = test_scenario::take_shared<Bank>(scenario);

            assert_eq(bank::admin_balance(&tested_bank), 0);

            test_scenario::return_to_sender(scenario, owner_cap);
            test_scenario::return_shared(tested_bank);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_deposit_success() {
        let deposit_amount = 100;

        let scenario_val = test_scenario::begin(ADMIN);

        let scenario = &mut scenario_val;
        {
            bank::init_for_testing(test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, USER);
        {
            let tested_bank = test_scenario::take_shared<Bank>(scenario);
            let deposit_coin = sui::coin::mint_for_testing<SUI>(
                deposit_amount,
                test_scenario::ctx(scenario)
            );

            bank::deposit(&mut tested_bank, deposit_coin, test_scenario::ctx(scenario));
            test_scenario::return_shared(tested_bank);
        };

        test_scenario::next_tx(scenario, USER);
        {
            let tested_bank = test_scenario::take_shared<Bank>(scenario);
            let admin_balance = bank::admin_balance(&tested_bank);

            let expected_admin_deposite: u64 = (deposit_amount * (bank::fee(&tested_bank) as u64)) / 100;
            assert_eq(admin_balance, expected_admin_deposite);

            let user_balance = bank::user_balance(&tested_bank, USER);
            assert_eq(user_balance, deposit_amount - expected_admin_deposite);

            test_scenario::return_shared(tested_bank);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_withdraw_success() {
        let deposit_amount = 100;

        let scenario_val = test_scenario::begin(ADMIN);

        let scenario = &mut scenario_val;
        {
            bank::init_for_testing(test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, USER);
        {
            let tested_bank = test_scenario::take_shared<Bank>(scenario);
            let deposit_coin = sui::coin::mint_for_testing<SUI>(
                deposit_amount,
                test_scenario::ctx(scenario)
            );

            bank::deposit(&mut tested_bank, deposit_coin, test_scenario::ctx(scenario));
            test_scenario::return_shared(tested_bank);
        };

        test_scenario::next_tx(scenario, USER);
        {
            let tested_bank = test_scenario::take_shared<Bank>(scenario);

            let expected_admin_deposite: u64 = (deposit_amount * (bank::fee(&tested_bank) as u64)) / 100;
            let user_balance = bank::user_balance(&tested_bank, USER);

            assert_eq(user_balance, deposit_amount - expected_admin_deposite);

            let withdraw_coin = bank::withdraw(&mut tested_bank, test_scenario::ctx(scenario));
            assert_eq(coin::value(&withdraw_coin), deposit_amount - expected_admin_deposite);

            coin::burn_for_testing(withdraw_coin);
            test_scenario::return_shared(tested_bank);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_claim_success() {
        let deposit_amount = 100;

        let scenario_val = test_scenario::begin(ADMIN);

        let scenario = &mut scenario_val;
        {
            bank::init_for_testing(test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, USER);
        {
            let tested_bank = test_scenario::take_shared<Bank>(scenario);
            let deposit_coin = sui::coin::mint_for_testing<SUI>(
                deposit_amount,
                test_scenario::ctx(scenario)
            );

            bank::deposit(&mut tested_bank, deposit_coin, test_scenario::ctx(scenario));
            test_scenario::return_shared(tested_bank);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let tested_bank = test_scenario::take_shared<Bank>(scenario);
            let expected_admin_deposite: u64 = (deposit_amount * (bank::fee(&tested_bank) as u64)) / 100;

            let owner_cap = test_scenario::take_from_sender<OwnerCap>(scenario);
            let withdraw_coin = bank::claim(&owner_cap, &mut tested_bank, test_scenario::ctx(scenario));
            assert_eq(coin::value(&withdraw_coin), expected_admin_deposite);

            coin::burn_for_testing(withdraw_coin);
            test_scenario::return_shared(tested_bank);
            test_scenario::return_to_sender(scenario, owner_cap);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_partial_withdraw() {
        let deposit_amount = 100;
        let scenario_val = test_scenario::begin(ADMIN);

        let scenario = &mut scenario_val;
        {
            bank::init_for_testing(test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, USER);
        {
            let tested_bank = test_scenario::take_shared<Bank>(scenario);
            let deposit_coin = sui::coin::mint_for_testing<SUI>(
                deposit_amount,
                test_scenario::ctx(scenario)
            );

            bank::deposit(&mut tested_bank, deposit_coin, test_scenario::ctx(scenario));
            test_scenario::return_shared(tested_bank);
        };

        test_scenario::next_tx(scenario, USER);
        {
            let tested_bank = test_scenario::take_shared<Bank>(scenario);
            let expected_admin_deposite: u64 = (deposit_amount * (bank::fee(&tested_bank) as u64)) / 100;
            let user_balance = bank::user_balance(&tested_bank, USER);

            assert_eq(user_balance, deposit_amount - expected_admin_deposite);

            let withdraw_coin = bank::partial_withdraw(&mut tested_bank, 50, test_scenario::ctx(scenario));
            assert_eq(coin::value(&withdraw_coin), 50);

            coin::burn_for_testing(withdraw_coin);
            test_scenario::return_shared(tested_bank);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = ENotEnoughBalance)]
    fun test_partial_withdraw_not_enough_balance() {
        let deposit_amount = 100;
        let scenario_val = test_scenario::begin(ADMIN);

        let scenario = &mut scenario_val;
        {
            bank::init_for_testing(test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, USER);
        {
            let tested_bank = test_scenario::take_shared<Bank>(scenario);
            let deposit_coin = sui::coin::mint_for_testing<SUI>(
                deposit_amount,
                test_scenario::ctx(scenario)
            );

            bank::deposit(&mut tested_bank, deposit_coin, test_scenario::ctx(scenario));
            test_scenario::return_shared(tested_bank);
        };

        test_scenario::next_tx(scenario, USER);
        {
            let tested_bank = test_scenario::take_shared<Bank>(scenario);
            let expected_admin_deposite: u64 = (deposit_amount * (bank::fee(&tested_bank) as u64)) / 100;
            let user_balance = bank::user_balance(&tested_bank, USER);

            assert_eq(user_balance, deposit_amount - expected_admin_deposite);

            let withdraw_coin = bank::partial_withdraw(&mut tested_bank, 250, test_scenario::ctx(scenario));
            assert_eq(coin::value(&withdraw_coin), 50);

            coin::burn_for_testing(withdraw_coin);
            test_scenario::return_shared(tested_bank);
        };

        test_scenario::end(scenario_val);
    }
}
