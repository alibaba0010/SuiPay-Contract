# Secure Token Contract

A comprehensive Sui Move smart contract for secure token transfers, scheduled payments, and payroll management with built-in escrow functionality.

## Features

### User Management

- User registration with unique username and email
- Username and email verification
- Wallet address association
- User lookup by email, username, or wallet address

### Token Transfers

- Secure escrow-based transfers with verification codes
- Direct transfers between addresses
- Transaction status tracking (Active, Completed, Claimed, Rejected, Refunded)
- Transaction verification system
- Multi-step claim process for added security

### Payroll Management

- Create and manage payroll lists
- Support for multiple recipients
- Automated total amount calculation
- Payroll tracking per user
- Detailed payroll information storage

### Events and Notifications

- Comprehensive event emission system
- Notification events for all major actions
- Transaction status updates
- Payment claims and rejections tracking

## Contract Structure

### Core Components

#### User Information

```move
public struct UserInfo has key, store {
    id: UID,
    username: String,
    email: String,
    wallet_address: address,
}
```

#### Token Transfer

```move
public struct TokenTransfer has key, store {
    id: UID,
    sender: address,
    receiver: address,
    amount: u64,
    status: u8,
    verification_code: String,
    timestamp: u64,
    updated_digest: Option<String>,
}
```

#### Payroll System

```move
public struct PayrollInfo has store {
    name: String,
    recipients: vector<address>,
    amounts: vector<u64>,
    created_by: address,
    created_at: u64,
}
```

## Usage

### Initializing the Contract

The contract is automatically initialized when deployed, creating necessary storage tables and structures.

### User Registration

```move
public entry fun register_user(
    secure_token: &mut SecureToken,
    username: vector<u8>,
    email: vector<u8>,
    ctx: &mut TxContext
)
```

### Creating a Transfer

```move
public entry fun init_transfer(
    secure_token: &mut SecureToken,
    amount: Coin<SUI>,
    receiver: address,
    tx_digest: vector<u8>,
    ctx: &mut TxContext
)
```

## Usage

### Prerequisites

- Sui CLI installed
- Move compiler
- Development environment setup

## Installation Guide

### Installing Sui

Follow the [official Sui installation guide](https://docs.sui.io/guides/developer/getting-started) or use these commands:

```bash
# Install prerequisites
cargo install --locked --git https://github.com/MystenLabs/sui.git --branch devnet sui

# Verify installation
sui --version
```

### Common Sui CLI Commands

#### Network Management

```bash
# List available networks
sui client envs

# Switch networks (devnet, testnet, mainnet)
sui client switch --env devnet

# Add new network
sui client new-env --alias testnet --rpc https://fullnode.testnet.sui.io:443
```

#### Address Management

```bash
# List addresses
sui client addresses

# Create new address
sui client new-address ed25519

# Get active address
sui client active-address
```

#### Publishing Commands

```bash
# Build project
sui move build

# Publish with dependency verification
sui client publish --gas-budget 50000000 --verify-deps

# Publish skipping dependency verification
sui client publish --gas-budget 50000000 --skip-dependency-verification
```

#### Object Management

```bash
# View object details
sui client object <object-id>

# View all objects owned by address
sui client objects
```

#### Gas Management

```bash
# View gas objects
sui client gas

# Get SUI tokens from faucet (devnet/testnet)
curl --location --request POST 'https://faucet.devnet.sui.io/gas' \
--header 'Content-Type: application/json' \
--data-raw '{
    "FixedAmountRequest": {
        "recipient": "<YOUR_ADDRESS>"
    }
}'
```

### Network RPC Endpoints

- Devnet: https://fullnode.devnet.sui.io:443
- Testnet: https://fullnode.testnet.sui.io:443
- Mainnet: https://fullnode.mainnet.sui.io:443

### Managing Payrolls

```move
public entry fun create_payroll(
    secure_token: &mut SecureToken,
    name: vector<u8>,
    recipients: vector<address>,
    amounts: vector<u64>,
    ctx: &mut TxContext
)
```

## Error Codes

| Code | Description                 |
| ---- | --------------------------- |
| 1    | User already exists         |
| 3    | Invalid receiver            |
| 7    | Insufficient balance        |
| 8    | Email already registered    |
| 9    | Username already registered |
| 10   | Invalid amount              |
| 11   | Invalid parameters          |
| 12   | Invalid verification code   |
| 13   | Insufficient funds          |
| 14   | Empty recipients list       |
| 15   | Payroll already exists      |

## Security Features

- Escrow-based transfer system
- Verification codes for claims
- Status tracking for all transactions
- Balance checks and validations
- Access control for sensitive operations

## Events

The contract emits various events for tracking and monitoring:

- UserRegistered
- PayrollCreated
- TransferInitiated
- TokenClaimed
- TokenRejected
- TokenRefunded
- NotificationEvent

## Dependencies

- Sui Framework
- Move Standard Library

## Building and Testing

1. Install Sui CLI
2. Build the contract:

```bash
sui move build
```

3. Run tests:

```bash
sui move test
```

## License

[Add your license information here]

## Contributing

[Add contribution guidelines here]

## Authors

[Add author information here]
