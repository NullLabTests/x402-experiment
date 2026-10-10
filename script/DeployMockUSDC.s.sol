// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {MockUSDC} from "../src/MockUSDC.sol";

contract DeployMockUSDC is Script {
    function run() external {
        uint256 initialSupply = 1_000_000 * 10 ** 6; // 1M mUSDC
        MockUSDC token = new MockUSDC(initialSupply);
    }
}