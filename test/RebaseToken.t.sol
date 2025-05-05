// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "../src/core/RebaseToken.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";
import {Vault} from "../src/core/Vault.sol";

contract RebaseTokenTest is Test {
    RebaseToken private rebaseToken;
    Vault private vault;

    address public owner = makeAddr("OWNER");
    address public user = makeAddr("USER");

    function setUp() public {
        vm.startPrank(owner);

        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintAndBurnRole(address(vault));

        vm.stopPrank();
    }

    function testDepositLinier(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);

        vm.startPrank(user);
        // Give amount of ETH
        vm.deal(user, amount);

        // Test deposit
        vault.deposit{value: amount}();

        // Get initial balance
        uint256 initialBalance = rebaseToken.balanceOf(user);

        // wrap for the time with 1 days after
        uint256 timeInterval = 1 days;
        vm.warp(block.timestamp + timeInterval);
        // check balance after time wrap
        uint256 afterTimeWarpBalance_1 = rebaseToken.balanceOf(user);

        vm.warp(block.timestamp + timeInterval);
        // Check again balance after time warp
        uint256 afterTimeWarpBalance_2 = rebaseToken.balanceOf(user);

        // Calculate interest of that 2
        uint256 interest_1 = afterTimeWarpBalance_1 - initialBalance;
        uint256 interest_2 = afterTimeWarpBalance_2 - afterTimeWarpBalance_1;

        assertEq(interest_1, interest_2, "Interest accrual is not linear");

        vm.stopPrank();
    }

    function testRedeemStraightAway(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);

        vm.deal(user, amount);
        vm.startPrank(user);

        // Deposit first
        vault.deposit{value: amount}();
        assertEq(rebaseToken.balanceOf(user), amount);

        // Redeem
        uint256 startEthBalance = address(user).balance;
        vault.redeem(type(uint256).max); // Redeem all

        // Check end of balances
        assertEq(rebaseToken.balanceOf(user), 0);
        assertEq(address(user).balance, startEthBalance + amount);

        vm.stopPrank();
    }

    function testRedeemAfterTimePassed(uint256 dayCount, uint256 amount) public {
        dayCount = bound(dayCount, 1e5, type(uint96).max);
        amount = bound(amount, 1_000, type(uint16).max);

        vm.deal(user, amount);
        vm.startPrank(user);
        vault.deposit{value: amount}();
        vm.warp(block.timestamp + dayCount);
        uint256 afterTimeWarpBalance = rebaseToken.balanceOf(user);
        vm.stopPrank();

        uint256 rewardAmount = afterTimeWarpBalance - amount;

        console.log("Reward Amount:\t", rewardAmount);
        console.log("Reward: \t\t", afterTimeWarpBalance);
        console.log("Amount: \t\t", amount);
        console.log("Time Warp: \t", dayCount);

        vm.deal(owner, rewardAmount);
        vm.startPrank(owner);
        (bool ok,) = payable(address(vault)).call{value: rewardAmount}("");
        assertTrue(ok);
        vm.stopPrank();

        uint256 ethBalanceBeforeRedeem = address(user).balance;

        vm.startPrank(user);
        vault.redeem(type(uint256).max);

        assertEq(rebaseToken.balanceOf(user), 0);
        assertEq(address(user).balance, ethBalanceBeforeRedeem + afterTimeWarpBalance);
        assertGt(address(user).balance, ethBalanceBeforeRedeem + amount);

        vm.stopPrank();
    }

    function testTransfer(uint256 amount, uint256 amountToSend) public {
        amount = bound(amount, 2e5, type(uint96).max);
        amountToSend = bound(amountToSend, 1e5, amount - 1e5);
        uint256 oldRate = 5e10;
        uint256 newRate = 6e10;

        vm.prank(owner);
        rebaseToken.setInterestRate(oldRate);

        address user_2 = makeAddr("USER_RECEIPIENT");
        vm.deal(user, amount);
        vm.prank(user);

        // Deposit by user 1
        vault.deposit{value: amount}();

        uint256 balanceBeforeUser_1 = rebaseToken.balanceOf(user);
        uint256 balanceBeforeUser_2 = rebaseToken.balanceOf(user_2);
        assertEq(balanceBeforeUser_2, 0);
        assertEq(balanceBeforeUser_1, amount);

        // Owner lowers the global interest rate
        uint256 originalRate = rebaseToken.getUserInterestRate(user);
        vm.prank(owner);
        rebaseToken.setInterestRate(newRate);

        // Transfer tokens
        vm.prank(user);
        rebaseToken.transfer(user_2, amountToSend);

        // Check final balances
        assertEq(rebaseToken.balanceOf(user), balanceBeforeUser_1 - amountToSend);
        assertEq(rebaseToken.balanceOf(user_2), amountToSend);

        // Check interest rate inheritance
        assertEq(rebaseToken.getUserInterestRate(user), originalRate);
        assertEq(rebaseToken.getUserInterestRate(user_2), originalRate);
    }
}
