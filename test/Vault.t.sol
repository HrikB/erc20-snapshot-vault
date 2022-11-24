// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {ERC20PresetFixedSupply} from "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import "../src/ClaimToken.sol";
import "../src/Vault.sol";

contract VaultTest is Test {
    ClaimToken public ownershipToken;
    ERC20PresetFixedSupply public distributionToken;
    Vault public vault;

    uint256 public constant DISTRIBUTION_AMOUNT = 10e18;
    uint256 public constant SHAREHOLDER1_AMOUNT = 3e18;
    uint256 public constant SHAREHOLDER2_AMOUNT = 7e18;

    address shareholder1 = vm.addr(1);
    address shareholder2 = vm.addr(2);
    address nonShareholder = vm.addr(3);
    address dividendCreator = vm.addr(4);

    uint256 successTime = block.timestamp + 30 * 24 * 3600;
    uint256 successAmount = DISTRIBUTION_AMOUNT;
    address successAddress;

    function setUp() external {
        vm.startPrank(dividendCreator);

        ownershipToken = new ClaimToken("Claim", "CLM");
        distributionToken = new ERC20PresetFixedSupply(
            "Distribution",
            "DSTR",
            DISTRIBUTION_AMOUNT,
            dividendCreator
        );
        vault = new Vault(ownershipToken, address(distributionToken));

        ownershipToken.mint(shareholder1, SHAREHOLDER1_AMOUNT);
        ownershipToken.mint(shareholder2, SHAREHOLDER2_AMOUNT);

        ownershipToken.grantCheckpoint(address(vault));
        distributionToken.approve(address(vault), 2**256 - 1);

        vm.label(shareholder1, "SHAREHOLDER1");
        vm.label(shareholder2, "SHAREHOLDER2");
        vm.label(dividendCreator, "DIVIDEND_CREATOR");
        vm.label(address(distributionToken), "DISTRIBUTION_TOKEN");
        vm.label(address(ownershipToken), "OWNERSHIP_TOKEN");
        vm.label(address(vault), "VAULT");
    }

    function testCreateDividend() external {
        distributionToken.transfer(address(vault), 1000);
        (, uint256 dividendIndex1) = vault.createDividend();
        assertEq(dividendIndex1, 1, "dividendIndex1");
        assertEq(vault.dividendAmountAt(dividendIndex1), 1000);

        distributionToken.transfer(address(vault), 2000);
        (, uint256 dividendIndex2) = vault.createDividend();
        assertEq(dividendIndex2, 2, "dividendIndex2");
        assertEq(vault.dividendAmountAt(dividendIndex2), 2000);

        distributionToken.transfer(address(vault), 5000);
        (, uint256 dividendIndex3) = vault.createDividend();
        assertEq(dividendIndex3, 3, "dividendIndex3");
        assertEq(vault.dividendAmountAt(dividendIndex3), 5000);

        distributionToken.transfer(address(vault), 2500);
        assertEq(vault.dividendAmountAt(dividendIndex3 + 1), 2500);
    }

    function testDividendClaim() external {
        distributionToken.transfer(address(vault), 1000);
        (, uint256 dividendIndex1) = vault.createDividend();

        distributionToken.transfer(address(vault), 2000);
        (, uint256 dividendIndex2) = vault.createDividend();

        distributionToken.transfer(address(vault), 5000);
        (, uint256 dividendIndex3) = vault.createDividend();

        distributionToken.transfer(address(vault), 2500);

        vm.expectRevert(bytes("Vault: Invalid dividend index"));
        vault.claimDividend(dividendIndex3 + 1);

        // (, , , uint256 amount, , ) = vault.dividends(dividendIndex);
        // uint256 snapshotTotalSupply = ownershipToken.totalSupplyAt(
        //     checkpointId
        // );

        // uint256 shareholder1Claim = (ownershipToken.balanceOfAt(
        //     shareholder1,
        //     checkpointId
        // ) * amount) / snapshotTotalSupply;
        // uint256 shareholder2Claim = (ownershipToken.balanceOfAt(
        //     shareholder2,
        //     checkpointId
        // ) * amount) / snapshotTotalSupply;

        // assertEq(distributionToken.balanceOf(shareholder1), 0);
        // assertEq(distributionToken.balanceOf(shareholder2), 0);
        // assertEq(distributionToken.balanceOf(nonShareholder), 0);

        // vm.stopPrank();
        // vm.prank(shareholder1);
        // vault.claimDividend(dividendIndex);
        // assertEq(distributionToken.balanceOf(shareholder1), shareholder1Claim);
        // assertEq(
        //     distributionToken.balanceOf(address(vault)),
        //     DISTRIBUTION_AMOUNT - shareholder1Claim
        // );

        // vm.prank(shareholder1);
        // vm.expectRevert(bytes("Vault: Already claimed"));
        // vault.claimDividend(dividendIndex);

        // vm.prank(nonShareholder);
        // vault.claimDividend(dividendIndex);
        // assertEq(distributionToken.balanceOf(nonShareholder), 0);

        // vm.prank(shareholder2);
        // vault.claimDividend(dividendIndex);
        // assertEq(distributionToken.balanceOf(shareholder2), shareholder2Claim);
        // assertEq(
        //     distributionToken.balanceOf(address(vault)),
        //     DISTRIBUTION_AMOUNT - shareholder1Claim - shareholder2Claim
        // );
    }

    function testGrantDividend() external {
        address addr = vm.addr(17);
        vault.grantDividend(addr);
        assertEq(vault.hasRole(keccak256("DIVIDEND_ROLE"), addr), true);
    }
}
