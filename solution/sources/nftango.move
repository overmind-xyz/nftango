module overmind::nftango {
    use std::error;
    use std::option::{Self, Option};
    use std::signer;
    use std::string::String;
    use std::vector;

    use aptos_framework::account;

    use aptos_token::token::{Self, TokenId};

    //
    // Errors
    //
    const ERROR_NFTANGO_STORE_EXISTS: u64 = 0;
    const ERROR_NFTANGO_STORE_DOES_NOT_EXIST: u64 = 1;
    const ERROR_NFTANGO_STORE_IS_ACTIVE: u64 = 2;
    const ERROR_NFTANGO_STORE_IS_NOT_ACTIVE: u64 = 3;
    const ERROR_NFTANGO_STORE_HAS_AN_OPPONENT: u64 = 4;
    const ERROR_NFTANGO_STORE_DOES_NOT_HAVE_AN_OPPONENT: u64 = 5;
    const ERROR_NFTANGO_STORE_JOIN_AMOUNT_REQUIREMENT_NOT_MET: u64 = 6;
    const ERROR_NFTS_ARE_NOT_IN_THE_SAME_COLLECTION: u64 = 7;
    const ERROR_NFTANGO_STORE_DOES_NOT_HAVE_DID_CREATOR_WIN: u64 = 8;
    const ERROR_NFTANGO_STORE_HAS_CLAIMED: u64 = 9;
    const ERROR_NFTANGO_STORE_IS_NOT_PLAYER: u64 = 10;
    const ERROR_VECTOR_LENGTHS_NOT_EQUAL: u64 = 11;

    //
    // Data structures
    //
    struct NFTangoStore has key {
        creator_token_id: TokenId,
        // The number of NFTs (one more more) from the same collection that the opponent needs to bet to enter the game
        join_amount_requirement: u64,
        opponent_address: Option<address>,
        opponent_token_ids: vector<TokenId>,
        active: bool,
        has_claimed: bool,
        did_creator_win: Option<bool>,
        signer_capability: account::SignerCapability
    }

    //
    // Assert functions
    //
    public fun assert_nftango_store_exists(
        account_address: address,
    ) {
        assert!(
            exists<NFTangoStore>(account_address),
            error::invalid_state(ERROR_NFTANGO_STORE_DOES_NOT_EXIST)
        );
    }

    public fun assert_nftango_store_does_not_exist(
        account_address: address,
    ) {
        assert!(
            !exists<NFTangoStore>(account_address),
            error::invalid_state(ERROR_NFTANGO_STORE_EXISTS)
        );
    }

    public fun assert_nftango_store_is_active(
        account_address: address,
    ) acquires NFTangoStore {
        let nftango_store = borrow_global_mut<NFTangoStore>(account_address);

        assert!(
            nftango_store.active,
            error::invalid_argument(ERROR_NFTANGO_STORE_IS_NOT_ACTIVE)
        );
    }

    public fun assert_nftango_store_is_not_active(
        account_address: address,
    ) acquires NFTangoStore {
        let nftango_store = borrow_global_mut<NFTangoStore>(account_address);

        assert!(
            !nftango_store.active,
            error::invalid_argument(ERROR_NFTANGO_STORE_IS_ACTIVE)
        );
    }

    public fun assert_nftango_store_has_an_opponent(
        account_address: address,
    ) acquires NFTangoStore {
        let nftango_store = borrow_global_mut<NFTangoStore>(account_address);

        assert!(
            nftango_store.opponent_address != option::none(),
            error::invalid_argument(ERROR_NFTANGO_STORE_DOES_NOT_HAVE_AN_OPPONENT)
        );
    }

    public fun assert_nftango_store_does_not_have_an_opponent(
        account_address: address,
    ) acquires NFTangoStore {
        let nftango_store = borrow_global_mut<NFTangoStore>(account_address);

        assert!(
            nftango_store.opponent_address == option::none(),
            error::invalid_argument(ERROR_NFTANGO_STORE_HAS_AN_OPPONENT)
        );
    }

    public fun assert_nftango_store_join_amount_requirement_is_met(
        game_address: address,
        token_ids: vector<TokenId>,
    ) acquires NFTangoStore {
        let nftango_store = borrow_global_mut<NFTangoStore>(game_address);

        assert!(
            nftango_store.join_amount_requirement == vector::length(&token_ids),
            error::invalid_argument(ERROR_NFTANGO_STORE_JOIN_AMOUNT_REQUIREMENT_NOT_MET)
        );
    }

    public fun assert_nftango_store_has_did_creator_win(
        game_address: address,
    ) acquires NFTangoStore {
        let nftango_store = borrow_global_mut<NFTangoStore>(game_address);

        assert!(
            nftango_store.did_creator_win != option::none(),
            error::invalid_argument(ERROR_NFTANGO_STORE_DOES_NOT_HAVE_DID_CREATOR_WIN)
        );
    }

    public fun assert_nftango_store_has_not_claimed(
        game_address: address,
    ) acquires NFTangoStore {
        let nftango_store = borrow_global_mut<NFTangoStore>(game_address);

        assert!(
            !nftango_store.has_claimed,
            error::invalid_argument(ERROR_NFTANGO_STORE_HAS_CLAIMED)
        );
    }

    public fun assert_nftango_store_is_player(account_address: address, game_address: address) acquires NFTangoStore {
        let nftango_store = borrow_global_mut<NFTangoStore>(game_address);

        let is_creator = account_address == game_address;
        let is_opponenet = option::some(account_address) == nftango_store.opponent_address;

        assert!(
            is_creator || is_opponenet,
            error::invalid_argument(ERROR_NFTANGO_STORE_IS_NOT_PLAYER)
        );
    }

    public fun assert_vector_lengths_are_equal(creator: vector<address>,
                                               collection_name: vector<String>,
                                               token_name: vector<String>,
                                               property_version: vector<u64>) {
        assert!(
            vector::length(&creator) == vector::length(&collection_name) && vector::length(
                &collection_name
            ) == vector::length(&token_name) && vector::length(&token_name) == vector::length(&property_version),
            error::invalid_argument(ERROR_VECTOR_LENGTHS_NOT_EQUAL)
        );
    }

    //
    // Entry functions
    //
    public entry fun initialize_game(
        account: &signer,
        creator: address,
        collection_name: String,
        token_name: String,
        property_version: u64,
        join_amount_requirement: u64
    ) {
        let account_address = signer::address_of(account);

        assert_nftango_store_does_not_exist(account_address);

        let (account_signer, signer_capability) = account::create_resource_account(account, vector::empty());

        let resource_account_address = account::get_signer_capability_address(&signer_capability);

        let token_id = token::create_token_id_raw(creator, collection_name, token_name, property_version);

        token::opt_in_direct_transfer(&account_signer, true);
        token::transfer(account, token_id, resource_account_address, 1);

        move_to(account, NFTangoStore {
            creator_token_id: token_id,
            join_amount_requirement,
            opponent_address: option::none(),
            opponent_token_ids: vector::empty(),
            active: true,
            has_claimed: false,
            did_creator_win: option::none(),
            signer_capability
        });
    }

    public entry fun cancel_game(
        account: &signer,
    ) acquires NFTangoStore {
        let account_address = signer::address_of(account);

        assert_nftango_store_exists(account_address);
        assert_nftango_store_is_active(account_address);
        assert_nftango_store_does_not_have_an_opponent(account_address);

        let nftango_store = borrow_global_mut<NFTangoStore>(account_address);

        token::opt_in_direct_transfer(account, true);
        token::transfer(
            &account::create_signer_with_capability(&nftango_store.signer_capability),
            nftango_store.creator_token_id,
            account_address,
            1
        );

        nftango_store.active = false;
    }

    public fun join_game(
        account: &signer,
        game_address: address,
        creators: vector<address>,
        collection_names: vector<String>,
        token_names: vector<String>,
        property_versions: vector<u64>,
    ) acquires NFTangoStore {
        let account_address = signer::address_of(account);

        assert_vector_lengths_are_equal(creators, collection_names, token_names, property_versions);

        let token_ids: vector<TokenId> = vector::empty();

        let i = 0;
        while (i < vector::length(&creators)) {
            let current_creator = *vector::borrow(&creators, i);
            let current_collection_name = *vector::borrow(&collection_names, i);
            let current_token_name = *vector::borrow(&token_names, i);
            let current_property_version = *vector::borrow(&property_versions, i);

            let current_token_data_id = token::create_token_data_id(
                current_creator,
                current_collection_name,
                current_token_name
            );

            vector::push_back(&mut token_ids, token::create_token_id(current_token_data_id, current_property_version));

            i = i + 1;
        };

        assert_nftango_store_exists(game_address);
        assert_nftango_store_is_active(game_address);
        assert_nftango_store_does_not_have_an_opponent(game_address);
        assert_nftango_store_join_amount_requirement_is_met(game_address, token_ids);

        let nftango_store = borrow_global_mut<NFTangoStore>(game_address);

        let i = 0;
        while (i < vector::length(&token_ids)) {
            let current_token_id = *vector::borrow(&token_ids, i);

            token::transfer(
                account,
                current_token_id,
                account::get_signer_capability_address(&nftango_store.signer_capability),
                1
            );

            i = i + 1;
        };

        nftango_store.opponent_address = option::some(account_address);
        nftango_store.opponent_token_ids = token_ids;
    }

    public entry fun play_game(account: &signer, did_creator_win: bool) acquires NFTangoStore {
        let account_address = signer::address_of(account);

        assert_nftango_store_exists(account_address);
        assert_nftango_store_is_active(account_address);
        assert_nftango_store_has_an_opponent(account_address);

        let nftango_store = borrow_global_mut<NFTangoStore>(account_address);

        nftango_store.did_creator_win = option::some(did_creator_win);
        nftango_store.active = false;
    }

    public entry fun claim(account: &signer, game_address: address) acquires NFTangoStore {
        let account_address = signer::address_of(account);

        assert_nftango_store_exists(game_address);
        assert_nftango_store_is_not_active(game_address);
        assert_nftango_store_has_not_claimed(game_address);
        assert_nftango_store_is_player(account_address, game_address);

        let nftango_store = borrow_global_mut<NFTangoStore>(game_address);

        let is_creator = account_address == game_address;
        let is_opponenet = option::some(account_address) == nftango_store.opponent_address;

        if ((is_creator && nftango_store.did_creator_win == option::some(
            true
        )) || (is_opponenet && nftango_store.did_creator_win == option::some(false))) {
            token::transfer(
                &account::create_signer_with_capability(&nftango_store.signer_capability),
                nftango_store.creator_token_id,
                account_address,
                1
            );

            let i = 0;
            while (i < vector::length(&nftango_store.opponent_token_ids)) {
                let current_token_id = *vector::borrow(&nftango_store.opponent_token_ids, i);

                token::transfer(
                    &account::create_signer_with_capability(&nftango_store.signer_capability),
                    current_token_id,
                    account_address,
                    1
                );

                i = i + 1;
            };
        };

        nftango_store.has_claimed = true;
    }
}