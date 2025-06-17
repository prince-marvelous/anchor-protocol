# Anchor Protocol

## Bitcoin-Native Multi-Collateral Stablecoin Platform

## Overview

Anchor Protocol is a decentralized, over-collateralized stablecoin protocol built on Stacks that enables users to mint USDx stablecoins against STX and xBTC collateral while maintaining Bitcoin's security and programmability. The protocol revolutionizes DeFi on Bitcoin by providing a robust, multi-collateral CDP (Collateralized Debt Position) system that combines Bitcoin's security with smart contract flexibility.

## Key Features

- **Multi-Asset Collateral Support**: STX and xBTC collateral backing
- **Decentralized Oracle Integration**: Real-time price feeds with confidence scoring
- **Automated Liquidation Engine**: Penalty mechanisms for undercollateralized positions
- **SIP-010 Compliant Token**: Fully compliant USDx stablecoin implementation
- **Comprehensive Vault Management**: Complete lifecycle management of debt positions
- **Emergency Governance Controls**: Protocol safety mechanisms

## System Architecture

### Core Components

#### 1. Vault Management System

The vault system manages user collateralized debt positions (CDPs):

- **Vault Creation**: Users deposit STX/xBTC collateral to open positions
- **Collateral Management**: Add/withdraw collateral with safety checks
- **Debt Management**: Mint USDx against collateral, burn to reduce debt
- **Position Tracking**: Real-time monitoring of vault health

#### 2. Oracle Network

Decentralized price feed system ensuring accurate asset valuations:

- **Price Feed Management**: Authorized operators update asset prices
- **Confidence Scoring**: Quality assessment of price data (1-100%)
- **Staleness Protection**: Maximum 1-hour price age validation
- **Multi-Asset Support**: STX and xBTC price feeds

#### 3. Liquidation Engine

Automated system for maintaining protocol solvency:

- **Health Factor Calculation**: Real-time collateral ratio monitoring
- **Authorized Liquidators**: Permissioned liquidation participants
- **Penalty Mechanism**: 10% liquidation penalty for undercollateralized vaults
- **Collateral Distribution**: Automatic transfer of seized assets

#### 4. USDx Stablecoin Token

SIP-010 compliant fungible token implementation:

- **Standard Compliance**: Full SIP-010 interface implementation
- **Secure Transfers**: Comprehensive validation and authorization
- **Supply Management**: Mint/burn operations tied to vault positions
- **Metadata Support**: Token name, symbol, decimals, and URI

## Contract Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Anchor Protocol                           │
├─────────────────────────────────────────────────────────────┤
│  Oracle System          │  Vault Management                 │
│  ┌─────────────────┐    │  ┌─────────────────────────────┐   │
│  │ Price Feeds     │    │  │ Vault Operations            │   │
│  │ - STX Price     │    │  │ - Create Vault              │   │
│  │ - xBTC Price    │    │  │ - Add Collateral            │   │
│  │ - Confidence    │    │  │ - Mint USDx                 │   │
│  │ - Staleness     │    │  │ - Burn USDx                 │   │
│  └─────────────────┘    │  │ - Withdraw Collateral       │   │
│                          │  └─────────────────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│  Liquidation Engine      │  USDx Token (SIP-010)            │
│  ┌─────────────────┐    │  ┌─────────────────────────────┐   │
│  │ Health Monitor  │    │  │ Token Operations            │   │
│  │ - Ratio Check   │    │  │ - Transfer                  │   │
│  │ - Liquidation   │    │  │ - Mint/Burn                 │   │
│  │ - Penalties     │    │  │ - Balance Query             │   │
│  └─────────────────┘    │  │ - Metadata                  │   │
│                          │  └─────────────────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│  Storage Layer                                              │
│  - Vaults Map           - User Vaults Map                   │
│  - Price Feeds Map      - Authorization Maps                │
│  - Protocol Statistics - Access Control                     │
└─────────────────────────────────────────────────────────────┘
```

## Data Flow

### Vault Creation Flow

1. User initiates vault creation with STX/xBTC collateral
2. Oracle system validates current asset prices (< 1 hour old)
3. System calculates total collateral value
4. Vault created with unique ID, collateral locked
5. User vault registry updated
6. Protocol statistics incremented

### USDx Minting Flow

1. User requests USDx minting against existing vault
2. System retrieves current oracle prices
3. Collateral ratio calculated (collateral value / debt)
4. Minimum 200% collateral ratio enforced
5. USDx tokens minted to user wallet
6. Vault debt position updated

### Liquidation Flow

1. Liquidator identifies undercollateralized vault (< 150%)
2. Health factor calculated using current prices
3. Liquidator burns USDx equivalent to vault debt
4. Liquidation penalty (10%) applied
5. Collateral transferred to liquidator
6. Vault deactivated, protocol statistics updated

## Risk Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| Minimum Collateral Ratio | 200% | Required ratio for new vaults |
| Liquidation Ratio | 150% | Threshold for liquidation eligibility |
| Liquidation Penalty | 10% | Additional penalty for liquidated vaults |
| Stability Fee Rate | 2% | Annual fee on outstanding debt |
| Max Price Age | 1 hour | Maximum allowed oracle price staleness |

## Key Functions

### Vault Management

- `create-vault`: Initialize new CDP with collateral
- `add-collateral`: Increase vault collateral
- `mint-usdx`: Generate stablecoins against collateral
- `burn-usdx`: Reduce debt by burning stablecoins
- `withdraw-collateral`: Remove excess collateral

### Oracle Operations

- `update-price`: Submit new price data
- `get-price`: Retrieve current asset price
- `set-oracle-operator`: Manage oracle permissions

### Liquidation System

- `liquidate-vault`: Execute liquidation of unsafe vaults
- `calculate-health-factor`: Assess vault safety
- `set-liquidator`: Authorize liquidation agents

### Token Operations (SIP-010)

- `transfer`: Move USDx between accounts
- `get-balance`: Query token balance
- `get-total-supply`: Total USDx in circulation

## Access Control

### Roles and Permissions

- **Contract Owner**: Protocol governance, parameter updates
- **Oracle Operators**: Price feed management
- **Authorized Liquidators**: Liquidation execution
- **Vault Owners**: Collateral and debt management

## Security Features

- **Over-Collateralization**: Minimum 200% collateral ratio
- **Price Staleness Protection**: Maximum 1-hour price age
- **Authorization Checks**: Role-based access control
- **Liquidation Penalties**: Economic incentives for protocol stability
- **Emergency Shutdown**: Governance safety mechanism

## Error Handling

The protocol implements comprehensive error handling with descriptive error codes:

- `ERR-NOT-AUTHORIZED`: Insufficient permissions
- `ERR-VAULT-NOT-FOUND`: Invalid vault reference
- `ERR-INSUFFICIENT-COLLATERAL`: Inadequate collateral amount
- `ERR-ORACLE-PRICE-STALE`: Outdated price data
- `ERR-MINIMUM-COLLATERAL-RATIO`: Below minimum ratio

## Deployment

The contract initializes with:

- Contract owner as initial oracle operator
- Baseline STX price: $1.00 (confidence: 95%)
- Baseline xBTC price: $100,000 (confidence: 95%)
- All protocol parameters set to secure defaults

## Integration

### For Developers

- Implement SIP-010 token interface for USDx integration
- Use read-only functions for vault and protocol data
- Monitor vault health factors for liquidation opportunities

### For Users

- Maintain collateral ratios above 200% for safety
- Monitor oracle price feeds for market conditions
- Understand liquidation risks and penalties

## Governance

The protocol includes governance mechanisms for:

- Liquidation ratio adjustments
- Oracle operator management
- Emergency protocol shutdown
- Parameter optimization

## Future Enhancements

- Additional collateral asset support
- Automated stability fee collection
- Governance token implementation
- Cross-chain asset integration
- Advanced liquidation mechanisms
