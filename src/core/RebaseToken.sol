// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title Rebase Token
 * @author Fahmi Lukistriya
 * @notice Implements crosschain ERC20 token where balances increase over the time automatically
 * @dev This contract uses a rebasing mechanism based on a per-second interest rate
 * The global interest rate can only increase or stay the same. Each user gets assigned
 * the prevailing global interest rate upon their first interaction involving balance updates.
 * Balances are calculated dynamically in the `balanceOf` function.
 */
contract RebaseToken is ERC20, Ownable, AccessControl {
    /**
     * Variable
     */

    // Represent 1 to 18 decimals places
    uint256 private constant PRECISION_FACTOR = 1e18;
    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");

    // Global interest rate per second (scaled by PRECISION_FACTOR)
    // Here we use 0.000_000_05 or 0.000_005% per second
    uint256 private s_interestRate = 5e10;

    // Maps the user to their interestRate
    mapping(address user => uint256 interestRate) private s_userInterestRate;

    // Maps the uset to block timestamp their last balance update/interacting with in
    mapping(address user => uint256 ts) private s_userLastUpdateAtTimestamp;

    /**
     * Error
     */

    /**
     * @notice Error reverted when interest not up
     * @param currentInterest Current interest position
     * @param proposedInterest Propose new interest to replace existing one
     */
    error RebaseToken__InteresetRateCanOnlyIncrease(uint256 currentInterest, uint256 proposedInterest);

    /**
     * Event
     */

    /**
     * @notice Event emitted when global interest is updated
     * @param newInterestRate new global interest rate per second
     */
    event InterestRateSet(uint256 newInterestRate);

    /**
     * Send ownership to the deployer
     */
    constructor() ERC20("Rebase Token", "RBT") Ownable(msg.sender) {}

    /**
     * @notice Grant burn and mint role to addres, only owner can access this
     * @param _account address want to be granted
     */
    function grantMintAndBurnRole(address _account) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, _account);
    }

    /**
     * @notice setInterestRate Set new global interest rate, only owner can call this
     * @dev It will revert when new interest rate is lower than existing one
     * @param _newInterestRate proposed interest rate
     * Will emit {InterestRateSet} event on this process
     */
    function setInterestRate(uint256 _newInterestRate) external onlyOwner {
        // Make sure interest never decreased
        if (_newInterestRate < s_interestRate) {
            revert RebaseToken__InteresetRateCanOnlyIncrease(s_interestRate, _newInterestRate);
        }
        s_interestRate = _newInterestRate;
        emit InterestRateSet(_newInterestRate);
    }

    /**
     * @notice Mints new principal tokens to user's account
     * @param _to address to mint
     * @param _amount amount principal token to mint
     * @param _userInterestRate user interest rate
     */
    function mint(address _to, uint256 _amount, uint256 _userInterestRate) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(_to);
        s_userInterestRate[_to] = _userInterestRate;

        _mint(_to, _amount);
    }

    /**
     * @notice Burn principal tokens from user's account
     * @param _from address to burn from
     * @param _amount amount principal token to burn
     */
    function burn(address _from, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(_from);
        _burn(_from, _amount);
    }

    /**
     * @notice Gets the spesific interest rate assigned to a user
     * @param _user address of user
     * @return user assigned interest rate per second (scaled)
     */
    function getUserInterestRate(address _user) external view returns (uint256) {
        return s_userInterestRate[_user];
    }

    /**
     * @notice Gets the global interest rate
     * @return global interest rate
     */
    function getInterestRate() external view returns (uint256) {
        return s_interestRate;
    }

    /**
     * @notice Get principle balance of a user
     * @dev just return balanceOf using normal ERC20 function
     * @param _user address of user
     * @return user principle balanceOf from user
     */
    function principleBalanceOf(address _user) public view returns (uint256) {
        return super.balanceOf(_user);
    }

    /**
     * @notice calculate intereset multiplier for user since last interact
     * @dev multiplier represents (1 + (user_rate * time_elapsed))
     * Result then scalled by PRECISION_FACTOR.
     * @param _user is address of user
     * @return linierInterest calculated interest multiplier (scaled)
     */
    function _calculateUserAccumulatedInterestLastUpdate(address _user)
        internal
        view
        returns (uint256 linierInterest)
    {
        // Get last timestamp
        uint256 lastTimestamp = s_userLastUpdateAtTimestamp[_user];
        if (lastTimestamp == 0) {
            // if zero then set it from block timestampt
            lastTimestamp = block.timestamp;
        }

        // Calculate elapsed time
        uint256 timeElapsed = block.timestamp - lastTimestamp;

        // Calculate interest part
        uint256 interest = s_userInterestRate[_user] * timeElapsed;

        // Calculate multiplier: 1 + interest part
        // PRECISION_FACTOR represent 1 (scaled)
        linierInterest = PRECISION_FACTOR + interest;
    }

    /**
     * @notice Get dynamic balance including accrued interest
     * @dev Override normal ERC20 balanceOf
     * Calculates balances as: Principal * (1 + (User rate * Time elapsed))
     * Uses fixed point math.
     * @param _user  address that query the balance for
     * @return Calculated balance (principal + accrued interest)
     */
    function balanceOf(address _user) public view override returns (uint256) {
        // Get principal balance using super balanceOf
        uint256 principalBalance = super.balanceOf(_user);
        // if zero then return 0
        if (principalBalance == 0) return 0;

        // Get interest multiplier
        uint256 interestMultiplier = _calculateUserAccumulatedInterestLastUpdate(_user);
        // Calculate final balance with (principal + accrued interest)
        return (principalBalance * interestMultiplier) / PRECISION_FACTOR;
    }

    /**
     * @notice Do transfer including accrued interest
     * @dev Override normal ERC20 transfer
     * Calculate balance with accrued interest before transfer
     * @param _recipient address that receive the transfer
     * @param _amount amount of token want to transfer
     */
    function transfer(address _recipient, uint256 _amount) public override returns (bool) {
        if (_amount == type(uint256).max) {
            _amount = super.balanceOf(msg.sender);
        }
        // Mint accrued interest
        _mintAccruedInterest(msg.sender);
        // Mint recipient interest
        _mintAccruedInterest(_recipient);
        if (balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[msg.sender];
        }

        return super.transfer(_recipient, _amount);
    }

    /**
     * @notice Do transfer including accrued interest
     * @dev Override normal ERC20 transferFrom
     * Calculate balance with accrued interest before transfer
     * @param _from address that transfer the transfer
     * @param _to address that receive the transfer
     * @param _amount amount of token want to transfer
     */
    function transferFrom(address _from, address _to, uint256 _amount) public override returns (bool) {
        if (_amount == type(uint256).max) {
            _amount = super.balanceOf(_from);
        }
        // Mint accrued interest
        _mintAccruedInterest(_from);
        // Mint recipient interest
        _mintAccruedInterest(_to);
        if (balanceOf(_to) == 0) {
            s_userInterestRate[_to] = s_userInterestRate[_from];
        }

        return super.transferFrom(_from, _to, _amount);
    }

    /**
     * @notice Calculates accrued interest, mints it and update the user last timestamp
     * @dev This function should call before operations that rely on an uptodate principal balance or modify the principal
     * @param _user address for which to accrue interest
     */
    function _mintAccruedInterest(address _user) internal {
        // Get principal balance using super balanceOf
        uint256 principalBalance = super.balanceOf(_user);
        uint256 totalBalanceWithInterest = balanceOf(_user);
        uint256 interestToMint = totalBalanceWithInterest - principalBalance;
        _mint(_user, interestToMint);
        s_userLastUpdateAtTimestamp[_user] = block.timestamp;
    }
}
