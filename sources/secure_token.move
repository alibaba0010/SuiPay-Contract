module secure_token_contract::secure_token {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use std::string::{Self, String};
    use sui::balance::{Self, Balance};
    use sui::event;
    use sui::table::{Self, Table};
    use std::option::{Self, Option};
    use sui::clock::{Self, Clock};
    use usdc::usdc::USDC;


    /// Transaction Status enum
    const STATUS_ACTIVE: u8 = 0;
    const STATUS_COMPLETED: u8 = 1;
    const STATUS_CLAIMED: u8 = 2;
    const STATUS_REJECTED: u8 = 3;
    const STATUS_REFUNDED: u8 = 4;
    const STATUS_EXPIRED: u8 = 5;
    const STATUS_PENDING: u8 = 6;

    /// Token types for multi-currency support
    const TOKEN_TYPE_SUI: bool = true;
    const TOKEN_TYPE_USDC: bool = false;

    /// User information
    public struct UserInfo has key, store {
        id: UID,
        username: String,
        email: String,
        wallet_address: address,
    }

    /// Token transfer information
    public struct TokenTransfer has key, store {
        id: UID,
        sender: address,
        receiver: address,
        amount: u64,
        status: u8,
        verification_code: String,
        timestamp: u64,
        updated_digest: Option<String>,
        is_sui: bool, // Token type: true for SUI, false for USDC
    }

    /// Structure for Bulk Transfer Recipients
    public struct Recipient has store, copy, drop {
        address: address,
        amount: u64,
        status: u8,
        verification_code: String,
    }

    /// Bulk Transfer information
    public struct BulkTokenTransfer has key, store {
        id: UID,
        sender: address,
        recipients: vector<Recipient>,
        total_amount: u64,
        timestamp: u64,
        updated_digests: Table<address, String>,
        is_sui: bool, // Token type: true for SUI, false for USDC
    }

    /// Scheduled Transaction information
    public struct ScheduledTransaction has key, store {
        id: UID,
        sender: address,
        receiver: address,
        amount: u64,
        scheduled_date: u64, // timestamp in milliseconds
        status: u8,
        transaction_digest: String,
        is_sui: bool, // Token type: true for SUI, false for USDC
    }

    /// Scheduled Bulk Transaction information
    public struct ScheduledBulkTransaction has key, store {
        id: UID,
        sender: address,
        recipients: vector<Recipient>,
        total_amount: u64,
        scheduled_date: u64, // timestamp in milliseconds
        status: u8,
        transaction_digest: String,
        is_sui: bool, // Token type: true for SUI, false for USDC
    }

    /// New structure for payroll information
    public struct PayrollInfo has store {
        name: String,
        recipients: vector<address>,
        amounts: vector<u64>,
        created_by: address,
        created_at: u64,
        is_sui: bool,
    }

    /// Event emitted when a payroll is created
    public struct PayrollCreated has copy, drop, store {
        name: String,
        created_by: address,
        recipient_count: u64,
        total_amount: u64,
        is_sui: bool,
    }

    /// Event emitted when a user is registered
    public struct UserRegistered has copy, drop, store {
        username: String,
        email: String,
        wallet_address: address,
    }

    /// Event emitted when a token transfer is initiated
    public struct TransferInitiated has copy, drop, store {
        sender: address,
        receiver: address,
        amount: u64,
        transaction_digest: String,
        is_sui: bool,
    }

    /// Event emitted when a token is claimed
    public struct TokenClaimed has copy, drop, store {
        receiver: address,
        amount: u64,
        transaction_digest: String,
        is_sui: bool,
    }

    /// Event emitted when a token is rejected
    public struct TokenRejected has copy, drop, store {
        receiver: address,
        amount: u64,
        transaction_digest: String,
        is_sui: bool,
    }

    /// Event emitted when a token is refunded
    public struct TokenRefunded has copy, drop, store {
        sender: address,
        amount: u64,
        transaction_digest: String,
        is_sui: bool,
    }

    /// Event emitted when a bulk transfer is initiated
    public struct BulkTransferInitiated has copy, drop, store {
        sender: address,
        total_amount: u64,
        recipient_count: u64,
        transaction_digest: String,
        is_sui: bool,
    }

    /// Event emitted when a transaction is scheduled
    public struct TransactionScheduled has copy, drop, store {
        sender: address,
        receiver: address,
        amount: u64,
        scheduled_date: u64,
        transaction_digest: String,
        is_sui: bool,
    }

    /// Event emitted when a bulk transaction is scheduled
    public struct BulkTransactionScheduled has copy, drop, store {
        sender: address,
        total_amount: u64,
        recipient_count: u64,
        scheduled_date: u64,
        transaction_digest: String,
        is_sui: bool,
    }

    /// Event emitted when a scheduled transaction is executed
    public struct ScheduledTransactionExecuted has copy, drop, store {
        sender: address,
        receiver: address,
        amount: u64,
        transaction_digest: String,
        is_sui: bool,
    }

    /// Event emitted when a scheduled bulk transaction is executed
    public struct ScheduledBulkTransactionExecuted has copy, drop, store {
        sender: address,
        total_amount: u64,
        recipient_count: u64,
        transaction_digest: String,
        is_sui: bool,
    }

    /// Event emitted for notification purposes
    public struct NotificationEvent has copy, drop, store {
        recipient: address,
        notification_type: String, // "payment", "claim", etc.
        title: String,
        description: String,
        transaction_digest: String,
    }

    #[allow(unused_const)]
    /// Main contract state
    public struct SecureToken has key, store {
        id: UID,
        users: Table<address, UserInfo>,
        transfers: Table<String, TokenTransfer>,
        bulk_transfers: Table<String, BulkTokenTransfer>,
        scheduled_transactions: Table<String, ScheduledTransaction>,
        scheduled_bulk_transactions: Table<String, ScheduledBulkTransaction>,
        // Store indexes for lookup
        email_to_address: Table<String, address>,
        username_to_address: Table<String, address>,
        // Track all user addresses for iteration
        all_users: vector<address>,
        // Escrow balances for tokens
        escrow_balance_sui: Balance<SUI>,
        escrow_balance_usdc: Balance<USDC>,
        // Payroll information
        payrolls: Table<String, PayrollInfo>,
        // Track payrolls per user
        user_payrolls: Table<address, vector<String>>,
    }

    /// User information for return values (without UID)
    public struct UserInfoReturn has copy, drop, store {
        username: String,
        email: String,
        wallet_address: address,
    }

    /// Payroll information for return values
    public struct PayrollInfoReturn has copy, drop, store {
        name: String,
        recipients: vector<address>,
        amounts: vector<u64>,
        total_amount: u64,
        created_at: u64,
        is_sui: bool,
    }

    /// Transaction info for return values
    public struct TransactionInfoReturn has copy, drop, store {
        sender: address,
        receiver: address,
        amount: u64,
        status: u8,
        verification_code: String,
        timestamp: u64,
        transaction_digest: String,
        is_sui: bool,
    }

    /// Bulk Transaction info for return values
    public struct BulkTransactionInfoReturn has copy, drop, store {
        sender: address,
        recipients: vector<Recipient>,
        total_amount: u64,
        timestamp: u64,
        transaction_digest: String,
        is_sui: bool,
    }

    /// Scheduled Transaction info for return values
    public struct ScheduledTransactionInfoReturn has copy, drop, store {
        sender: address,
        receiver: address,
        amount: u64,
        scheduled_date: u64,
        status: u8,
        transaction_digest: String,
        is_sui: bool,
    }

    /// Error codes
    const EUSER_ALREADY_EXISTS: u64 = 1;
    const EINVALID_RECEIVER: u64 = 3;
    const EINSUFFICIENT_BALANCE: u64 = 7;
    const EEMAIL_ALREADY_REGISTERED: u64 = 8;
    const EUSERNAME_ALREADY_REGISTERED: u64 = 9;
    const EINVALID_AMOUNT: u64 = 10;
    const EINVALID_PARAMETERS: u64 = 11;
    const EINVALID_VERIFICATION_CODE: u64 = 12;
    const EINSUFFICIENT_FUNDS: u64 = 13;
    const EEMPTY_RECIPIENTS_LIST: u64 = 14;
    const EPAYROLL_ALREADY_EXISTS: u64 = 15;
    const EPAYROLL_NOT_FOUND: u64 = 16;
    const ENOT_PAYROLL_OWNER: u64 = 17;
    const ETRANSACTION_NOT_FOUND: u64 = 18;
    const EINVALID_STATUS: u64 = 19;
    const EINVALID_SENDER: u64 = 20;
    const EINVALID_SCHEDULED_DATE: u64 = 21;
    const ETRANSACTION_NOT_ACTIVE: u64 = 22;
    const ETRANSACTION_NOT_SCHEDULED: u64 = 23;
    const ESCHEDULE_TIME_NOT_REACHED: u64 = 24;

    /// Initialize the contract
    fun init(ctx: &mut TxContext) {
        let secure_token = SecureToken {
            id: object::new(ctx),
            users: table::new<address, UserInfo>(ctx),
            transfers: table::new<String, TokenTransfer>(ctx),
            bulk_transfers: table::new<String, BulkTokenTransfer>(ctx),
            scheduled_transactions: table::new<String, ScheduledTransaction>(ctx),
            scheduled_bulk_transactions: table::new<String, ScheduledBulkTransaction>(ctx),
            email_to_address: table::new<String, address>(ctx),
            username_to_address: table::new<String, address>(ctx),
            all_users: vector::empty<address>(),
            escrow_balance_sui: balance::zero<SUI>(),
            escrow_balance_usdc: balance::zero<USDC>(),
            payrolls: table::new<String, PayrollInfo>(ctx),
            user_payrolls: table::new<address, vector<String>>(ctx),
        };
        transfer::share_object(secure_token);
    }

    /// Register a new user
    public entry fun register_user(
        secure_token: &mut SecureToken,
        username: vector<u8>,
        email: vector<u8>,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        
        // Check if user already exists
        assert!(!table::contains(&secure_token.users, sender), EUSER_ALREADY_EXISTS);
        
        let username_str = string::utf8(username);
        let email_str = string::utf8(email);
        
        // Check if email or username already registered
        assert!(!table::contains(&secure_token.email_to_address, email_str), EEMAIL_ALREADY_REGISTERED);
        assert!(!table::contains(&secure_token.username_to_address, username_str), EUSERNAME_ALREADY_REGISTERED);
        
        let user_info = UserInfo {
            id: object::new(ctx),
            username: username_str,
            email: email_str,
            wallet_address: sender,
        };
        
        // Add user to main table
        table::add(&mut secure_token.users, sender, user_info);
        
        // Add to lookup tables
        table::add(&mut secure_token.email_to_address, email_str, sender);
        table::add(&mut secure_token.username_to_address, username_str, sender);
        
        // Add to the list of all users
        vector::push_back(&mut secure_token.all_users, sender);        
        
        // Initialize user's payroll list
        table::add(&mut secure_token.user_payrolls, sender, vector::empty<String>());
        
        event::emit(UserRegistered {
            username: username_str,
            email: email_str,
            wallet_address: sender,
        });
    }

    /// Create a new payroll
    public entry fun create_payroll(
        secure_token: &mut SecureToken,
        name: vector<u8>,
        recipients: vector<address>,
        amounts: vector<u64>,
        is_sui: bool,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let name_str = string::utf8(name);
        
        // Validate inputs
        let recipients_len = vector::length(&recipients);
        assert!(recipients_len > 0, EEMPTY_RECIPIENTS_LIST);
        assert!(recipients_len == vector::length(&amounts), EINVALID_PARAMETERS);
        
        // Check if payroll name already exists
        assert!(!table::contains(&secure_token.payrolls, name_str), EPAYROLL_ALREADY_EXISTS);
        
        // Calculate total amount
        let mut total_amount = 0u64;
        let mut i = 0;
        while (i < recipients_len) {
            let amount = *vector::borrow(&amounts, i);
            assert!(amount > 0, EINVALID_AMOUNT);
            total_amount = total_amount + amount;
            i = i + 1;
        };
        
        // Create payroll info with timestamp
        let payroll_info = PayrollInfo {
            name: name_str,
            recipients: recipients,
            amounts: amounts,
            created_by: sender,
            created_at: tx_context::epoch(ctx), // Use epoch as timestamp
            is_sui: is_sui,
        };
        
        // Add payroll to tables
        table::add(&mut secure_token.payrolls, name_str, payroll_info);
        
        // Add payroll name to user's payroll list
        if (!table::contains(&secure_token.user_payrolls, sender)) {
            table::add(&mut secure_token.user_payrolls, sender, vector::empty<String>());
        };
        let user_payrolls = table::borrow_mut(&mut secure_token.user_payrolls, sender);
        vector::push_back(user_payrolls, name_str);
        
        // Emit event
        event::emit(PayrollCreated {
            name: name_str,
            created_by: sender,
            recipient_count: recipients_len,
            total_amount: total_amount,
            is_sui: is_sui,
        });
    }

    /// Execute payroll - send tokens to all recipients in a payroll
    public entry fun execute_payroll_sui(
        secure_token: &mut SecureToken,
        payroll_name: vector<u8>,
        payment: Coin<SUI>,
        tx_digest: vector<u8>,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let name_str = string::utf8(payroll_name);
        let tx_digest_str = string::utf8(tx_digest);
        
        // Verify payroll exists
        assert!(table::contains(&secure_token.payrolls, name_str), EPAYROLL_NOT_FOUND);
        
        let payroll = table::borrow(&secure_token.payrolls, name_str);
        
        // Verify sender is payroll owner
        assert!(payroll.created_by == sender, ENOT_PAYROLL_OWNER);
        
        // Verify payroll is for SUI
        assert!(payroll.is_sui == true, EINVALID_PARAMETERS);
        
        // Calculate total amount needed
        let mut total_amount = 0u64;
        let mut i = 0;
        let amounts_len = vector::length(&payroll.amounts);
        while (i < amounts_len) {
            total_amount = total_amount + *vector::borrow(&payroll.amounts, i);
            i = i + 1;
        };
        
        // Verify sufficient funds
        let payment_value = coin::value(&payment);
        assert!(payment_value >= total_amount, EINSUFFICIENT_FUNDS);
        
        // Take payment into escrow
        let payment_balance = coin::into_balance(payment);
        balance::join(&mut secure_token.escrow_balance_sui, payment_balance);
        
        // Create bulk transfer record
        let mut recipients = vector::empty<Recipient>();
        let timestamp = tx_context::epoch(ctx);
        
        // For each recipient, generate verification code and add to recipients
        i = 0;
        while (i < vector::length(&payroll.recipients)) {
            let recipient_addr = *vector::borrow(&payroll.recipients, i);
            let amount = *vector::borrow(&payroll.amounts, i);
            
            // Generate verification code
            let verification_code = generate_verification_code(sender, recipient_addr, timestamp);
            
            let recipient = Recipient {
                address: recipient_addr,
                amount: amount,
                status: STATUS_ACTIVE,
                verification_code: verification_code,
            };
            
            vector::push_back(&mut recipients, recipient);
            
            // Emit notification for each recipient
            event::emit(NotificationEvent {
                recipient: recipient_addr,
                notification_type: string::utf8(b"claim"),
                title: string::utf8(b"Payroll Payment Available"),
                description: string::utf8(b"You have a payroll payment available to claim"),
                transaction_digest: tx_digest_str,
            });
            
            i = i + 1;
        };
        
        // Create bulk transfer record
        let bulk_transfer = BulkTokenTransfer {
            id: object::new(ctx),
            sender: sender,
            recipients: recipients,
            total_amount: total_amount,
            timestamp: timestamp,
            updated_digests: table::new<address, String>(ctx),
            is_sui: true,
        };
        
        // Add to bulk transfers table
        table::add(&mut secure_token.bulk_transfers, tx_digest_str, bulk_transfer);
        
        // Emit event
        event::emit(BulkTransferInitiated {
            sender: sender,
            total_amount: total_amount,
            recipient_count: vector::length(&payroll.recipients),
            transaction_digest: tx_digest_str,
            is_sui: true,
        });
    }

    /// Execute payroll with USDC
    public entry fun execute_payroll_usdc(
        secure_token: &mut SecureToken,
        payroll_name: vector<u8>,
        payment: Coin<USDC>,
        tx_digest: vector<u8>,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let name_str = string::utf8(payroll_name);
        let tx_digest_str = string::utf8(tx_digest);
        
        // Verify payroll exists
        assert!(table::contains(&secure_token.payrolls, name_str), EPAYROLL_NOT_FOUND);
        
        let payroll = table::borrow(&secure_token.payrolls, name_str);
        
        // Verify sender is payroll owner
        assert!(payroll.created_by == sender, ENOT_PAYROLL_OWNER);
        
        // Verify payroll is for USDC
        assert!(payroll.is_sui == false, EINVALID_PARAMETERS);
        
        // Calculate total amount needed
        let mut total_amount = 0u64;
        let mut i = 0;
        let amounts_len = vector::length(&payroll.amounts);
        while (i < amounts_len) {
            total_amount = total_amount + *vector::borrow(&payroll.amounts, i);
            i = i + 1;
        };
        
        // Verify sufficient funds
        let payment_value = coin::value(&payment);
        assert!(payment_value >= total_amount, EINSUFFICIENT_FUNDS);
        
        // Take payment into escrow
        let payment_balance = coin::into_balance(payment);
        balance::join(&mut secure_token.escrow_balance_usdc, payment_balance);
        
        // Create bulk transfer record
        let mut recipients = vector::empty<Recipient>();
        let timestamp = tx_context::epoch(ctx);
        
        // For each recipient, generate verification code and add to recipients
        i = 0;
        while (i < vector::length(&payroll.recipients)) {
            let recipient_addr = *vector::borrow(&payroll.recipients, i);
            let amount = *vector::borrow(&payroll.amounts, i);
            
            // Generate verification code
            let verification_code = generate_verification_code(sender, recipient_addr, timestamp);
            
            let recipient = Recipient {
                address: recipient_addr,
                amount: amount,
                status: STATUS_ACTIVE,
                verification_code: verification_code,
            };
            
            vector::push_back(&mut recipients, recipient);
            
            // Emit notification for each recipient
            event::emit(NotificationEvent {
                recipient: recipient_addr,
                notification_type: string::utf8(b"claim"),
                title: string::utf8(b"USDC Payroll Payment Available"),
                description: string::utf8(b"You have a USDC payroll payment available to claim"),
                transaction_digest: tx_digest_str,
            });
            
            i = i + 1;
        };
        
        // Create bulk transfer record
        let bulk_transfer = BulkTokenTransfer {
            id: object::new(ctx),
            sender: sender,
            recipients: recipients,
            total_amount: total_amount,
            timestamp: timestamp,
            updated_digests: table::new<address, String>(ctx),
            is_sui: false,
        };
        
        // Add to bulk transfers table
        table::add(&mut secure_token.bulk_transfers, tx_digest_str, bulk_transfer);
        
        // Emit event
        event::emit(BulkTransferInitiated {
            sender: sender,
            total_amount: total_amount,
            recipient_count: vector::length(&payroll.recipients),
            transaction_digest: tx_digest_str,
            is_sui: false,
        });
    }

    /// Get all user payrolls
    public fun get_all_user_payrolls(
        secure_token: &SecureToken, 
        sender: address
    ): vector<PayrollInfoReturn> {
        let mut result = vector::empty<PayrollInfoReturn>();
        
        // Check if user has any payrolls
        if (!table::contains(&secure_token.user_payrolls, sender)) {
            return result
        };
        
        let payroll_names = table::borrow(&secure_token.user_payrolls, sender);
        let mut i = 0;
        let len = vector::length(payroll_names);
        
        while (i < len) {
            let name = *vector::borrow(payroll_names, i);
            if (table::contains(&secure_token.payrolls, name)) {
                let payroll = table::borrow(&secure_token.payrolls, name);
                
                // Calculate total amount - fixed calculation
                let mut total_amount = 0u64;
                let mut j = 0;
                let amounts_len = vector::length(&payroll.amounts);
                
                while (j < amounts_len) {
                    total_amount = total_amount + *vector::borrow(&payroll.amounts, j);
                    j = j + 1;
                };
                
                // Create return structure with all fields properly set
                let payroll_return = PayrollInfoReturn {
                    name: payroll.name,
                    recipients: payroll.recipients,
                    amounts: payroll.amounts,
                    total_amount: total_amount,
                    created_at: payroll.created_at,
                    is_sui: payroll.is_sui,
                };
                
                vector::push_back(&mut result, payroll_return);
            };
            i = i + 1;
        };
        
        result
    }

    /// Get payroll by name
    public fun get_payroll_by_name(
        secure_token: &SecureToken,
        name: vector<u8>
    ): Option<PayrollInfoReturn> {
        let name_str = string::utf8(name);
        
        if (table::contains(&secure_token.payrolls, name_str)) {
            let payroll = table::borrow(&secure_token.payrolls, name_str);
            
            // Calculate total amount
            let mut total_amount = 0u64;
            let mut i = 0;
            let amounts_len = vector::length(&payroll.amounts);
            while (i < amounts_len) {
                total_amount = total_amount + *vector::borrow(&payroll.amounts, i);
                i = i + 1;
            };
            
            // Create return structure with created_at
            option::some(PayrollInfoReturn {
                name: payroll.name,
                recipients: payroll.recipients,
                amounts: payroll.amounts,
                total_amount: total_amount,
                created_at: payroll.created_at,
                is_sui: payroll.is_sui,
            })
        } else {
            option::none<PayrollInfoReturn>()
        }
    }

    /// Get user payroll names
    public fun get_user_payroll_names(
        secure_token: &SecureToken,
        sender: address
    ): vector<String> {
        if (!table::contains(&secure_token.user_payrolls, sender)) {
            return vector::empty<String>()
        };
        
        // Return the vector of payroll names directly
        *table::borrow(&secure_token.user_payrolls, sender)
    }

    /// Get all registered users
    public fun get_all_users(secure_token: &SecureToken): vector<UserInfoReturn> {
        let mut users = vector::empty<UserInfoReturn>();
        let mut i = 0;
        let len = vector::length(&secure_token.all_users);
        
        while (i < len) {
            let addr = *vector::borrow(&secure_token.all_users, i);
            let user = table::borrow(&secure_token.users, addr);
            
            vector::push_back(&mut users, UserInfoReturn {
                username: user.username,
                email: user.email,
                wallet_address: user.wallet_address,
            });
            i = i + 1;
        };
        
        users
    }

    /// Get user info by email
    public fun get_user_by_email(secure_token: &SecureToken, email: vector<u8>): Option<UserInfoReturn> {
        let email_str = string::utf8(email);
        
        if (table::contains(&secure_token.email_to_address, email_str)) {
            let addr = *table::borrow(&secure_token.email_to_address, email_str);
            let user = table::borrow(&secure_token.users, addr);
            
            option::some(UserInfoReturn {
                username: user.username,
                email: user.email,
                wallet_address: user.wallet_address,
            })
        } else {
            option::none<UserInfoReturn>()
        }
    }

    /// Get user info by username
    public fun get_user_by_username(secure_token: &SecureToken, username: vector<u8>): Option<UserInfoReturn> {
        let username_str = string::utf8(username);
        
        if (table::contains(&secure_token.username_to_address, username_str)) {
            let addr = *table::borrow(&secure_token.username_to_address, username_str);
            let user = table::borrow(&secure_token.users, addr);
            
            option::some(UserInfoReturn {
                username: user.username,
                email: user.email,
                wallet_address: user.wallet_address,
            })
        } else {
            option::none<UserInfoReturn>()
        }
    }

    /// Get user info by wallet address
    public fun get_user_by_address(secure_token: &SecureToken, wallet_address: address): Option<UserInfoReturn> {
        if (table::contains(&secure_token.users, wallet_address)) {
            let user_info = table::borrow(&secure_token.users, wallet_address);
            option::some(UserInfoReturn {
                username: user_info.username,
                email: user_info.email,
                wallet_address: user_info.wallet_address,
            })
        } else {
            option::none<UserInfoReturn>()
        }
    }

    /// Get all usernames
    public fun get_all_usernames(secure_token: &SecureToken): vector<String> {
        let mut usernames = vector::empty<String>();
        let mut i = 0;
        let len = vector::length(&secure_token.all_users);
        
        while (i < len) {
            let addr = *vector::borrow(&secure_token.all_users, i);
            let user = table::borrow(&secure_token.users, addr);
            vector::push_back(&mut usernames, user.username);
            i = i + 1;
        };
        
        usernames
    }

    /// Get all emails
    public fun get_all_emails(secure_token: &SecureToken): vector<String> {
        let mut emails = vector::empty<String>();
        let mut i = 0;
        let len = vector::length(&secure_token.all_users);
        
        while (i < len) {
            let addr = *vector::borrow(&secure_token.all_users, i);
            let user = table::borrow(&secure_token.users, addr);
            vector::push_back(&mut emails, user.email);
            i = i + 1;
        };
        
        emails
    }
    
       /// Generate verification code (helper function)
    fun generate_verification_code(sender: address, receiver: address, timestamp: u64): String {
        // Simple hash-based code generation
        // In production, use a more secure method
        let mut code_parts = vector::empty<u8>();
        vector::append(&mut code_parts, std::bcs::to_bytes(&sender));
        vector::append(&mut code_parts, std::bcs::to_bytes(&receiver));
        vector::append(&mut code_parts, std::bcs::to_bytes(&timestamp));
        
        // Take first 6 bytes and convert to hex string
        let mut hex_code = string::utf8(b"");
        let mut i = 0;
        while (i < 6 && i < vector::length(&code_parts)) {
            let byte = *vector::borrow(&code_parts, i);
            
            // Convert byte to hex
            let hex_chars = b"0123456789ABCDEF";
            let high = vector::borrow(&hex_chars, ((byte >> 4) & 0xF) as u64);
            let low = vector::borrow(&hex_chars, (byte & 0xF) as u64);
            
            string::append_utf8(&mut hex_code, vector::singleton(*high));
            string::append_utf8(&mut hex_code, vector::singleton(*low));
            
            i = i + 1;
        };
        
        hex_code
    }

    /// Init transfer to escrow with verification and token type
    public entry fun init_transfer(
        secure_token: &mut SecureToken,
        amount: Coin<SUI>,
        receiver: address,
        tx_digest: vector<u8>,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let amount_value = coin::value(&amount);
        let timestamp = tx_context::epoch(ctx);
        let tx_digest_str = string::utf8(tx_digest);
        
        assert!(amount_value > 0, EINVALID_AMOUNT);
        
        // Generate verification code
        let verification_code = generate_verification_code(sender, receiver, timestamp);
        
        // Convert to balance and add to escrow
        let balance_to_escrow = coin::into_balance(amount);
        balance::join(&mut secure_token.escrow_balance_sui, balance_to_escrow);
        
        // Create transfer record
        let transfer_record = TokenTransfer {
            id: object::new(ctx),
            sender,
            receiver,
            amount: amount_value,
            status: STATUS_ACTIVE,
            verification_code,
            timestamp,
            updated_digest: option::none(),
            token_type: TOKEN_TYPE_SUI,
        };
        
        // Add to transfers table
        table::add(&mut secure_token.transfers, tx_digest_str, transfer_record);
        
        // Emit event
        event::emit(TransferInitiated {
            sender,
            receiver,
            amount: amount_value,
            transaction_digest: tx_digest_str,
            token_type: TOKEN_TYPE_SUI,
        });
        
        // Emit notification event for receiver
        event::emit(NotificationEvent {
            recipient: receiver,
            notification_type: string::utf8(b"claim"),
            title: string::utf8(b"Payment Available to Claim"),
            description: string::utf8(b"You have a payment available to claim"),
            transaction_digest: tx_digest_str,
        });
    }

    /// Init transfer to escrow with USDC
    public entry fun init_transfer_usdc(
        secure_token: &mut SecureToken,
        amount: Coin<USDC>,
        receiver: address,
        tx_digest: vector<u8>,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let amount_value = coin::value(&amount);
        let timestamp = tx_context::epoch(ctx);
        let tx_digest_str = string::utf8(tx_digest);
        
        assert!(amount_value > 0, EINVALID_AMOUNT);
        
        // Generate verification code
        let verification_code = generate_verification_code(sender, receiver, timestamp);
        
        // Convert to balance and add to escrow
        let balance_to_escrow = coin::into_balance(amount);
        balance::join(&mut secure_token.escrow_balance_usdc, balance_to_escrow);
        
        // Create transfer record
        let transfer_record = TokenTransfer {
            id: object::new(ctx),
            sender,
            receiver,
            amount: amount_value,
            status: STATUS_ACTIVE,
            verification_code,
            timestamp,
            updated_digest: option::none(),
            token_type: TOKEN_TYPE_USDC,
        };
        
        // Add to transfers table
        table::add(&mut secure_token.transfers, tx_digest_str, transfer_record);
        
        // Emit event
        event::emit(TransferInitiated {
            sender,
            receiver,
            amount: amount_value,
            transaction_digest: tx_digest_str,
            token_type: TOKEN_TYPE_USDC,
        });A
        
        // Emit notification event for receiver
        event::emit(NotificationEvent {
            recipient: receiver,
            notification_type: string::utf8(b"claim"),
            title: string::utf8(b"USDC Payment Available to Claim"),
            description: string::utf8(b"You have a USDC payment available to claim"),
            transaction_digest: tx_digest_str,
        });
    }

    /// Send funds directly to receiver with SUI
    public entry fun send_funds_directly(
        secure_token: &mut SecureToken,
        receiver: address,
        amount: Coin<SUI>,
        tx_digest: vector<u8>,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let amount_value = coin::value(&amount);
        let tx_digest_str = string::utf8(tx_digest);

        assert!(amount_value > 0, EINVALID_AMOUNT);
        
        // Create a record for tracking purposes
        let transfer_record = TokenTransfer {
            id: object::new(ctx),
            sender,
            receiver,
            amount: amount_value,
            status: STATUS_COMPLETED,
            verification_code: string::utf8(b""),
            timestamp: tx_context::epoch(ctx),
            updated_digest: option::none(),
            token_type: TOKEN_TYPE_SUI,
        };

        table::add(&mut secure_token.transfers, tx_digest_str, transfer_record);
      // Emit event
        event::emit(TransferInitiated {
            sender,
            receiver,
            amount: amount_value,
            transaction_digest: tx_digest_str,
            token_type: TOKEN_TYPE_USDC,
        });A
        
        // Emit notification event for receiver
        event::emit(NotificationEvent {
            recipient: receiver,
            notification_type: string::utf8(b"claim"),
            title: string::utf8(b"USDC Payment Available to Claim"),
            description: string::utf8(b"You have a USDC payment available to claim"),
            transaction_digest: tx_digest_str,
        });
    }
 }