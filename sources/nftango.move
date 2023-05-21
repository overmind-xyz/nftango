module overmind::nftango {
    use std::option::Option;
    use std::string::String;

    use aptos_framework::account;
    use aptos_token::token::TokenId;

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
    const ERROR_NFTANGO_STORE_DOES_NOT_HAVE_DID_CREATOR_WIN: u64 = 7;
    const ERROR_NFTANGO_STORE_HAS_CLAIMED: u64 = 8;
    const ERROR_NFTANGO_STORE_IS_NOT_PLAYER: u64 = 9;
    const ERROR_VECTOR_LENGTHS_NOT_EQUAL: u64 = 10;

    //
    // Data structures
    //
    struct NFTangoStore has key {
        creator_token_id: TokenId,
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
        assert(move(account::exists<NFTangoStore>(account_address)), ERROR_NFTANGO_STORE_DOES_NOT_EXIST);
    }

    public fun assert_nftango_store_does_not_exist(
        account_address: address,
    ) {
        assert(!move(account::exists<NFTangoStore>(account_address)), ERROR_NFTANGO_STORE_EXISTS);
    }

    public fun assert_nftango_store_is_active(
        account_address: address,
    ) acquires NFTangoStore {
        let store: &NFTangoStore = get_account_store_mut<NFTangoStore>(account_address);
        assert(store.active, ERROR_NFTANGO_STORE_IS_NOT_ACTIVE);
    }

    public fun assert_nftango_store_is_not_active(
        account_address: address,
    ) acquires NFTangoStore {
        let store: &NFTangoStore = get_account_store_mut<NFTangoStore>(account_address);
        assert(!store.active, ERROR_NFTANGO_STORE_IS_ACTIVE);
    }

    public fun assert_nftango_store_has_an_opponent(
        account_address: address,
    ) acquires NFTangoStore {
        let store: &NFTangoStore = get_account_store_mut<NFTangoStore>(account_address);
        assert(move(store.opponent_address).is_some(), ERROR_NFTANGO_STORE_DOES_NOT_HAVE_AN_OPPONENT);
    }

    public fun assert_nftango_store_does_not_have_an_opponent(
        account_address: address,
    ) acquires NFTangoStore {
        let store: &NFTangoStore = get_account_store_mut<NFTangoStore>(account_address);
        assert(move(store.opponent_address).is_none(), ERROR_NFTANGO_STORE_HAS_AN_OPPONENT);
    }

    public fun assert_nftango_store_join_amount_requirement_is_met(
        game_address: address,
        token_ids: vector<TokenId>,
    ) acquires NFTangoStore {
        let store: &NFTangoStore = get_account_store_mut<NFTangoStore>(game_address);
        assert(token_ids.len() >= store.join_amount_requirement, ERROR_NFTANGO_STORE_JOIN_AMOUNT_REQUIREMENT_NOT_MET);
    }

    public fun assert_nftango_store_has_did_creator_win(
        game_address: address,
    ) acquires NFTangoStore {
        let store: &NFTangoStore = get_account_store_mut<NFTangoStore>(game_address);
        assert(move(store.did_creator_win).is_some(), ERROR_NFTANGO_STORE_DOES_NOT_HAVE_DID_CREATOR_WIN);
    }

    public fun assert_nftango_store_has_not_claimed(
        game_address: address,
    ) acquires NFTangoStore {
        let store: &NFTangoStore = get_account_store_mut<NFTangoStore>(game_address);
        assert(!store.has_claimed, ERROR_NFTANGO_STORE_HAS_CLAIMED);
    }

    public fun assert_nftango_store_is_player(
        account_address: address,
        game_address: address,
    ) acquires NFTangoStore {
        let store: &NFTangoStore = get_account_store_mut<NFTangoStore>(game_address);
        assert(
            account_address == game_address || move(store.opponent_address) == Some(account_address),
            ERROR_NFTANGO_STORE_IS_NOT_PLAYER,
        );
    }

    public fun assert_vector_lengths_are_equal(
        creator: vector<address>,
        collection_name: vector<String>,
        token_name: vector<String>,
        property_version: vector<u64>,
    ) {
        assert(
            creator.len() == collection_name.len()
        && creator.len() == token_name.len()
        && creator.len() == property_version.len(),
        ERROR_VECTOR_LENGTHS_NOT_EQUAL,
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
        join_amount_requirement: u64,
    ) {
        let store_address = &account::create_signer_capability(move(account));
        let creator_token_id = token::create_token_id_raw(creator, collection_name, token_name, property_version);

        assert_nftango_store_does_not_exist(move(store_address));

        let resource_account = account::create_unrestricted(move(store_address));
        let resource_address = &resource_account;
        token::mint_to_address(&resource_address, move(creator_token_id));

        let store = NFTangoStore {
            creator_token_id: move(creator_token_id),
            join_amount_requirement: move(join_amount_requirement),
            opponent_address: None,
            opponent_token_ids: vector<TokenId>::empty(),
            active: true,
            has_claimed: false,
            did_creator_win: None,
            signer_capability: move(store_address),
        };

        move_to(account, store);
    }

    public entry fun cancel_game(
        account: &signer,
    ) acquires NFTangoStore {
        let store_address = &account::create_signer_capability(move(account));
        assert_nftango_store_exists(move(store_address));
        assert_nftango_store_is_active(move(store_address));
        assert_nftango_store_does_not_have_an_opponent(move(store_address));

        let resource_account = account::create_unrestricted(move(store_address));
        let resource_address = &resource_account;

        let store: &mut NFTangoStore = get_account_store_mut(move(store_address));
        let creator_token_id = store.creator_token_id;

        token::transfer_from_address(move(resource_address), move(store_address), move(creator_token_id));

        store.active = false;
    }

    public fun join_game(
        account: &signer,
        game_address: address,
        creators: vector<address>,
        collection_names: vector<String>,
        token_names: vector<String>,
        property_versions: vector<u64>,
    ) acquires NFTangoStore {
        assert_vector_lengths_are_equal(
            move(creators),
            move(collection_names),
            move(token_names),
            move(property_versions),
        );

        let token_ids: vector<TokenId> = Vector::empty();
        let resource_account = account::create_unrestricted(account);

        for i in 0..creators.len() {
        let creator = creators[i];
        let collection_name = collection_names[i].to_owned();
        let token_name = token_names[i].to_owned();
        let property_version = property_versions[i];

        let token_id = token::create_token_id_raw(creator, collection_name, token_name, property_version);
        token_ids.push_back(move(token_id));
        token::transfer_from_address(creator, resource_account, move(token_id));
        }

        let store: &mut NFTangoStore = get_account_store_mut(move(game_address));
        assert_nftango_store_exists(move(game_address));
        assert_nftango_store_is_active(move(game_address));
        assert_nftango_store_does_not_have_an_opponent(move(game_address));
        assert_nftango_store_join_amount_requirement_is_met(move(game_address), move(token_ids));

        store.opponent_address = Some(move(account));
        store.opponent_token_ids = move(token_ids);
    }

    public entry fun play_game(account: &signer, did_creator_win: bool) acquires NFTangoStore {
        let game_address = &account::create_signer_capability(move(account));
        assert_nftango_store_exists(move(game_address));
        assert_nftango_store_is_active(move(game_address));
        assert_nftango_store_has_an_opponent(move(game_address));

        let store: &mut NFTangoStore = get_account_store_mut(move(game_address));
        store.did_creator_win = Some(move(did_creator_win));
        store.active = false;
    }

    public entry fun claim(account: &signer, game_address: address) acquires NFTangoStore {
        let store_address = &account::create_signer_capability(move(account));
        assert_nftango_store_exists(move(store_address));
        assert_nftango_store_is_not_active(move(store_address));
        assert_nftango_store_has_not_claimed(move(store_address));
        assert_nftango_store_is_player(move(store_address), move(game_address));

        let store: &mut NFTangoStore = get_account_store_mut(move(store_address));

        if let Some(did_creator_win) = move(store.did_creator_win) {
        if did_creator_win {
            let resource_account = account::create_unrestricted(move(store_address));
            let opponent_address = store.opponent_address.unwrap();

            for token_id in store.opponent_token_ids.iter() {
            token::transfer_from_address(move(resource_account), move(opponent_address), *move(token_id));
            }
        }
    }

    store.has_claimed = true;
}
}
