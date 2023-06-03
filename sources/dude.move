module meme::dude {
    use std::signer;
    use std::string::utf8;

    use aptos_framework::coin;
    use aptos_framework::coin::{BurnCapability, Coin};
    use aptos_framework::aptos_coin::AptosCoin;

    use liquidswap_v05::router;
    use liquidswap_v05::curves::Uncorrelated;
    use liquidswap_lp::lp_coin::LP;

    struct DUDE {}

    struct Capabilities has key {
        burn_cap: BurnCapability<DUDE>,
    }

    struct LockedLP has key {
        lp_coins: Coin<LP<DUDE, AptosCoin, Uncorrelated>>
    }

    /// Launch coin.
    public entry fun launch(account: &signer) {
        // Register coin.
        let (b, f, m) = coin::initialize<DUDE>(
            account,
            utf8(b"MEME DUDE"),
            utf8(b"DUDE"),
            6,
            true,
        );

        // Mint 100m.
        let dude_minted = coin::mint(100000000000000, &m);
        let initial_liq_dude = coin::extract(&mut dude_minted, 10000000000000);

        coin::register<DUDE>(account);
        coin::deposit(signer::address_of(account), dude_minted);

        // Destroy caps.
        coin::destroy_mint_cap(m);
        coin::destroy_freeze_cap(f);

        // Store burn capability.
        move_to(account, Capabilities {
            burn_cap: b,
        });

        // Extract 10 APT from account.
        let initial_liq_apt = coin::withdraw<AptosCoin>(account, 1000000000);

        // Let's create a pair on liquidswap v05.
        router::register_pool<DUDE, AptosCoin, Uncorrelated>(account);

        // Add intial liquidity.
        let min_liq_dude = coin::value(&initial_liq_dude);
        let min_liq_apt = coin::value(&initial_liq_apt);

        let (remainder_coin_x, remainder_coin_y, lp_coins) = router::add_liquidity<DUDE, AptosCoin, Uncorrelated>(
            initial_liq_dude,
            min_liq_dude,
            initial_liq_apt,
            min_liq_apt,
        );

        coin::destroy_zero(remainder_coin_x);
        coin::destroy_zero(remainder_coin_y);

        // Lock liquidity forever.
        move_to(account, LockedLP {
            lp_coins,
        });
    }

    /// Burn DUDE coins.
    public fun burn(to_burn: Coin<DUDE>) acquires Capabilities {
        let caps = borrow_global<Capabilities>(@meme);
        coin::burn(to_burn, &caps.burn_cap);
    }
}
