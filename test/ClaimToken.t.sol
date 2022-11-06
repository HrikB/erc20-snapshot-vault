// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import "../src/ClaimToken.sol";

contract ClaimTokenTest is Test {
    function testGrantCheckpoint() external {
        ClaimToken token = new ClaimToken("Claim", "CLM");
        address addr = vm.addr(1);
        vm.label(addr, "ADDR");
        token.grantCheckpoint(addr);
        assertEq(token.hasRole(keccak256("CHECKPOINT_ROLE"), addr), true);
    }

    function testMint() external {
        ClaimToken token = new ClaimToken("Claim", "CLM");
        address addr = vm.addr(1);
        vm.label(addr, "ADDR");
        token.mint(addr, 100);
        assertEq(token.balanceOf(addr), 100);
    }
}
