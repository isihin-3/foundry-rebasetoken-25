// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";

contract RebaseTokenTest is Test {
    Vault private vault;
    RebaseToken private rebaseToken;

    address public owner = makeAddr("owner");
    address public user = makeAddr("user");

    function setUp() public {
        vm.startPrank(owner);
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintAndBurnRole(address(vault));
        vm.stopPrank();
    }

    function addRewardsToTheVault(uint256 amount) public {
        (bool success,) = payable(address(vault)).call{value: amount}("");
        require(success, "Failed to send Ether to vault");
    }

    function testDepositLinear(uint256 amount) public {
        uint256 maxAmount = 10000 ether;
        amount = bound(amount, 1e5, maxAmount);
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();

        uint256 startingBalance = rebaseToken.balanceOf(user);
        assertEq(amount, startingBalance);

        vm.warp(block.timestamp + 1 hours);
        uint256 middleBalance = rebaseToken.balanceOf(user);
        assertGt(middleBalance, startingBalance);

        vm.warp(block.timestamp + 1 hours);
        uint256 endBalance = rebaseToken.balanceOf(user);
        assertGt(endBalance, middleBalance);

        assertApproxEqAbs(endBalance - middleBalance, middleBalance - startingBalance, 1);

        vm.stopPrank();
    }

    function testReedemStraightAway(uint256 amount) public {
        uint256 maxAmount = 10000 ether;
        amount = bound(amount, 1e5, maxAmount);
        vm.startPrank(user);
        vm.deal(user, amount);

        vault.deposit{value: amount}();
        assertEq(rebaseToken.balanceOf(user), amount);

        vault.redeem(type(uint256).max);
        assertEq(rebaseToken.balanceOf(user), 0);
        assertEq(address(user).balance, amount);

        vm.stopPrank();
    }

    function testRedeemAfterTimePassed(uint256 amount, uint256 time) public {
        uint256 maxtime = 60 * 60 * 24 * 365 * 10;
        time = bound(time, 1000, maxtime);
        uint256 maxAmount = 10000 ether;
        amount = bound(amount, 1e5, maxAmount);

        vm.prank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        vm.warp(block.timestamp + time);

        uint256 balance = rebaseToken.balanceOf(user);

        vm.deal(owner, balance - amount);
        vm.prank(owner);
        addRewardsToTheVault(balance - amount);

        vm.prank(user);
        vault.redeem(balance);

        uint256 ethbalance = address(user).balance;

        assertEq(balance, ethbalance);
        assertGt(balance, amount);
    }

    function testTransfer(uint256 amount, uint256 amountToSend) public {
        amount = bound(amount, 1e5 + 1e3, type(uint96).max);
        amountToSend = bound(amountToSend, 1e5, amount - 1e3);

        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();

        address user2 = makeAddr("user2");
        uint256 userBalance = rebaseToken.balanceOf(user);
        uint256 user2Balance = rebaseToken.balanceOf(user2);
        assertEq(userBalance, amount);
        assertEq(user2Balance, 0);

        vm.prank(owner);
        rebaseToken.setIntrestRate(4e10);

        vm.prank(user);
        rebaseToken.transfer(user2, amountToSend);
        uint256 userBalanceAfterTransfer = rebaseToken.balanceOf(user);
        uint256 user2BalanceAfterTransfer = rebaseToken.balanceOf(user2);
        assertEq(user2BalanceAfterTransfer, user2Balance + amountToSend);
        assertEq(userBalanceAfterTransfer, userBalance - amountToSend);

        vm.warp(block.timestamp + 1 days);

        uint256 userBalanceAfterWarp = rebaseToken.balanceOf(user);
        uint256 userTwoBalanceAfterWarp = rebaseToken.balanceOf(user2);
        uint256 userTwoInterestRate = rebaseToken.getUserInterest(user2);
        assertEq(userTwoInterestRate, 5e10);
        uint256 userInterestRate = rebaseToken.getUserInterest(user);
        assertEq(userInterestRate, 5e10);

        assertGt(userBalanceAfterWarp, userBalanceAfterTransfer);
        assertGt(userTwoBalanceAfterWarp, user2BalanceAfterTransfer);
    }
}
