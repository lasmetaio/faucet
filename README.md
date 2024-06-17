# Lasmeta Faucet Smart Contract

## Overview

The `LasmFaucet` contract manages token distribution with cooldown periods to prevent abuse. It allows users to claim tokens after a specified cooldown period and includes functionalities for updating payout amounts, cooldown periods, and supporting vesting and claiming mechanisms. The contract also ensures that only certain chain IDs are allowed and handles vesting token claims.

## Tech Stack

- **Solidity**
- **OpenZeppelin Contracts**
  - `SafeERC20`
  - `Pausable`
  - `ReentrancyGuard`

## Features

- **Token Distribution**: Allows users to claim tokens after a cooldown period.
- **Cooldown Management**: Ensures users can only claim tokens after a specified cooldown period to prevent abuse.
- **Payout Amount Management**: Allows the owner to update the amount of tokens distributed per claim.
- **Vesting Claim Support**: Integrates with a vesting contract to claim vested tokens.
- **Chain ID Restrictions**: Ensures that the contract only operates on specified chain IDs.
- **Event Notifications**: Emits events for key actions such as token claims, updates to configuration, and withdrawals.

## Events

- `TokensClaimed(address indexed _wallet, uint256 indexed _paymentAmount)`
- `CoolDownPeriodUpdated(uint256 indexed _oldPeriod, uint256 indexed _newPeriod)`
- `PayoutAmountUpdated(uint256 indexed _oldAmount, uint256 indexed _newAmount)`
- `VestingTokensClaimed(uint256 indexed _oldBalance, uint256 indexed _currentBalance)`
- `VestingClaimContractUpdated(address indexed oldVestingClaimImplementation, address indexed _newVestingClaimImplementation)`
- `ChainIdUpdated(uint256 indexed _oldChain, uint256 indexed _newChainId)`
- `Withdrawal(address indexed _owner, address indexed _destination, uint256 indexed _amount)`

## Security

- **Pausable Functionality**: Allows pausing of contract operations in case of emergency.
- **Reentrancy Protection**: Prevents reentrancy attacks for secure contract interactions.

## Contract Configuration

### Cooldown Management

The contract includes a cooldown period that users must wait before making another claim. This is managed through the following functions:

- **`updateCooldownPeriod`**: Allows the owner to update the cooldown period.
- **`getCoolDownPeriod`**: Returns the current cooldown period.

### Payout Amount Management

The owner can update the amount of tokens distributed per claim. This is managed through the following functions:

- **`updatePayoutAmount`**: Allows the owner to update the payout amount.
- **`getPayoutAmount`**: Returns the current payout amount.

### Vesting Claim Support

The contract integrates with a vesting contract to claim vested tokens. This is managed through the following functions:

- **`updateVestingClaimContract`**: Updates the vesting claim contract address.
- **`claimVestedTokens`**: Claims vested tokens for a specified template.

### Chain ID Restrictions

The contract ensures it only operates on specified chain IDs to prevent unauthorized use on other networks. This is managed through the following functions:

- **`updateChainID`**: Updates the allowed chain ID.
- **`isChainAllowed`**: Checks if the current chain ID is allowed.

## Administrative Functions

- **`pause`**: Pauses the contract.
- **`unpause`**: Unpauses the contract.
- **`rescueTokens`**: Allows the owner to rescue tokens from the contract.
- **`withdraw`**: Allows the owner to withdraw native tokens from the contract.