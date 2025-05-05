// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IRebaseToken} from "../interfaces/IRebaseToken.sol";
/**
 * Vault purpose:
 * 1. ETH deposit: user need a way to deposit into the system
 * 2. Token minting: when deposit, the vault must interract with associated RebaseToken contract to min the corresponding amount of tokens for user
 * 3. Token redemption: user need to be able to redeem their rebase token backt to underlying ETH
 * 4. Token burning: upon redemption, vault must interract with RebaseToken to burn user tokens
 * 5. ETH withdrawl: vault must securely transfer the corresponding amount of ETH back to user during redemption
 * 6. Reward accumulation: vault should able to receive ETH transfers, potensially representing reward generated elsewhere in the system, acting as central pool for all related ETH
 */

contract Vault {
    /**
     * State and Variable
     */
    /**
     * State variable to store the RebaseToken contract address
     */
    IRebaseToken private immutable i_rebaseToken;

    /**
     * Event
     */
    event Redeem(address indexed user, uint256 amount);
    event Deposit(address indexed user, uint256 amount);

    /**
     * Error
     */
    error Vault__RedeemFailed();
    error Vault__RedeemAmountCannotBeZero();

    constructor(IRebaseToken _rebaseToken) {
        i_rebaseToken = _rebaseToken;
    }

    /**
     * @notice Allow contract to receive plain ETH transfer (e.g., for rewards)
     */
    receive() external payable {}

    function deposit() external payable {
        i_rebaseToken.mint(msg.sender, msg.value, i_rebaseToken.getInterestRate());
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @notice Allow user to burn their rebase token and receive equivalent amount of ETH
     * @param _amount amount rebase token to be burn and redeemed with equivalent amount of ETH
     */
    function redeem(uint256 _amount) external {
        /**
         * Do:
         * Check -> Effect -> Interactions Pattern
         */
        // Check
        if (_amount == 0) {
            revert Vault__RedeemAmountCannotBeZero();
        }

        if (_amount == type(uint256).max) {
            _amount = i_rebaseToken.balanceOf(msg.sender);
        }

        // Effect
        i_rebaseToken.burn(msg.sender, _amount);

        // Interactions
        (bool ok,) = payable(msg.sender).call{value: _amount}("");
        if (!ok) {
            revert Vault__RedeemFailed();
        }
        emit Redeem(msg.sender, _amount);
    }

    /**
     * @notice return address of the RebaseToken contract this vaule interact with
     * @return address of the RebaseToken contract this vaule interact with
     */
    function getRebaseTokenAddress() external view returns (address) {
        return address(i_rebaseToken);
    }
}
