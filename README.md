# RebaseToken

A dynamic ERC20 token with automatic rebasing functionality, where balances grow over time based on a per-second interest rate.

## 📜 Overview

**RebaseToken** is an ERC20-compliant token that increases user balances automatically over time using a linear interest model. This interest rate is applied per second and affects each user's balance based on their last interaction with the contract.

## ✨ Features

- 📈 **Auto-Rebasing**: Balances increase over time without requiring user action.
- ⏱️ **Per-Second Interest**: Global interest rate applied linearly per second.
- 🔒 **Interest Rate Only Increases**: Cannot be decreased, ensuring forward-only growth.
- 👤 **User-Specific Accrual**: Each user accrues interest individually from their last interaction.

## 🛠️ Usage

### Deploy

The contract uses Solidity `^0.8.28` and requires OpenZeppelin's ERC20 dependency:

```bash
npm install @openzeppelin/contracts
```

### Key Functions

```solidity
setInterestRate(uint256 newRate)
```

- Set a new global interest rate (must be >= current rate).

```solidity
mint(address to, uint256 amount)
```

- Mint new principal tokens to a user, after accruing interest.

```solidity
balanceOf(address user) → uint256
```

- Returns the dynamically calculated balance including accrued interest.

```solidity
getUserInterestRate(address user) → uint256
```

- Returns the interest rate assigned to a specific user.

## 📄 License

MIT © Fahmi Lukistriya
