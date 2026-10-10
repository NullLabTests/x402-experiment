// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {MockUSDC} from "../src/MockUSDC.sol";

contract MockUSDCTest is Test {
    MockUSDC internal token;
    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    uint256 internal constant SUPPLY = 1_000_000;

    function setUp() public {
        token = new MockUSDC(SUPPLY);
    }

    function test_Metadata() public view {
        assertEq(token.name_(), "MockUSDC");
        assertEq(token.symbol_(), "mUSDC");
        assertEq(token.decimals_(), 6);
    }

    function test_ConstructorMintsSupply() public view {
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.nonces(address(this)), 0);
    }

    function test_Transfer() public {
        assertTrue(token.transfer(bob, 100));
        assertEq(token.balanceOf(bob), 100);
        assertEq(token.balanceOf(address(this)), SUPPLY - 100);
    }

    function test_RevertWhen_InsufficientBalance() public {
        vm.expectRevert(bytes("insufficient balance"));
        token.transfer(bob, SUPPLY + 1);
    }

    function test_Approve() public {
        assertTrue(token.approve(bob, 42));
        assertEq(token.allowance(address(this), bob), 42);
    }

    function test_TransferWithAuthorization() public {
        token.transferWithAuthorization(bob, 5, bytes32(0), bytes32(type(uint256).max));
        assertEq(token.balanceOf(bob), 5);
        assertEq(token.nonces(address(this)), 1);
    }

    function test_TransferWithAuthorization_ReusedNonce() public {
        token.transferWithAuthorization(bob, 5, bytes32(0), bytes32(type(uint256).max));
        vm.expectRevert(bytes("nonce exhausted"));
        token.transferWithAuthorization(bob, 5, bytes32(0), bytes32(type(uint256).max));
    }

    function test_CancelAuthorization_NoAuth() public {
        vm.expectRevert(bytes("no auth to cancel"));
        token.cancelAuthorization(bytes32(0));
    }

    function test_DomainSeparator() public view {
        assertTrue(token.DOMAIN_SEPARATOR() != bytes32(0));
    }
}
