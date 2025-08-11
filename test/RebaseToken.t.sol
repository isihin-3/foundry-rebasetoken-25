// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test,console} from "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";

contract RebaseTokenTest is Test{
    Vault private vault;
    RebaseToken private rebaseToken;

    address public owner = makeAddr("owner");
    address public user = makeAddr("user");

    function setUp() public{
        vm.startPrank(owner);
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintAndBurnRole(address(vault));
        vm.stopPrank();
    }

    function addRewardsToTheVault(uint256 amount) public{
        payable(address(vault)).call{value: amount}("");
    }

    function testDepositLinear(uint256 amount) public{
        uint256 maxAmount = 10000 ether;
        amount = bound(amount,1e5,maxAmount);
        vm.startPrank(user);
        vm.deal(user,amount);
        vault.deposit{value: amount}();

        uint256 startingBalance = rebaseToken.balanceOf(user);
        assertEq(amount,startingBalance);

        vm.warp(block.timestamp + 1 hours);
        uint256 middleBalance = rebaseToken.balanceOf(user);
        assertGt(middleBalance,startingBalance);

        vm.warp(block.timestamp + 1 hours);
        uint256 endBalance = rebaseToken.balanceOf(user);
        assertGt(endBalance,middleBalance);

        assertApproxEqAbs(endBalance - middleBalance , middleBalance - startingBalance,1);

        vm.stopPrank();
    }

    function testReedemStraightAway(uint256 amount) public{
        uint256 maxAmount = 10000 ether;
        amount = bound(amount,1e5,maxAmount);
        vm.startPrank(user);
        vm.deal(user,amount);

        vault.deposit{value: amount}();
        assertEq(rebaseToken.balanceOf(user),amount);

        vault.redeem(type(uint256).max);
        assertEq(rebaseToken.balanceOf(user),0);
        assertEq(address(user).balance,amount);

        vm.stopPrank();
    }

    function testRedeemAfterTimePassed(uint256 amount, uint256 time) public{
        uint256 maxtime = 60*60*24*365*10;
        time = bound(time,1000,maxtime);
        uint256 maxAmount = 10000 ether;
        amount = bound(amount,1e5,maxAmount);

        vm.prank(user);
        vm.deal(user,amount);
        vault.deposit{value: amount}();
        vm.warp(block.timestamp + time);

        uint256 balance = rebaseToken.balanceOf(user);

        vm.deal(owner,balance - amount);
        vm.prank(owner);
        addRewardsToTheVault(balance - amount);

        vm.prank(user);
        vault.redeem(balance);

        uint256 ethbalance = address(user).balance;

        assertEq(balance , ethbalance);
        assertGt(balance,amount);
    }
}