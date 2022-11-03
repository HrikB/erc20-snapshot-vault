// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {ERC20PresetFixedSupply} from "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";

import "../src/ClaimToken.sol";
import "../src/Vault.sol";

contract VaultTest is Test {
    ClaimToken public ownershipToken;
    ERC20PresetFixedSupply public distribtionToken;
    Vault public vault;

    uint256 public constant DISTRIBUTION_AMOUNT = 10e18;

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
        distribtionToken = new ERC20PresetFixedSupply(
            "Distribution",
            "DSTR",
            DISTRIBUTION_AMOUNT,
            dividendCreator
        );
        vault = new Vault(ownershipToken);

        successAddress = address(distribtionToken);

        ownershipToken.mint(shareholder1, 3e18);
        ownershipToken.mint(shareholder2, 7e18);

        ownershipToken.grantCheckpoint(address(vault));
        distribtionToken.approve(address(vault), 2**256 - 1);

        vm.label(shareholder1, "SHAREHOLDER1");
        vm.label(shareholder2, "SHAREHOLDER2");
        vm.label(dividendCreator, "DIVIDEND_CREATOR");
        vm.label(address(distribtionToken), "DISTRIBUTION_TOKEN");
        vm.label(address(ownershipToken), "OWNERSHIP_TOKEN");
        vm.label(address(vault), "VAULT");
    }

    function testCheckpointCreation() external {
        uint256 prevSnapshotId = ownershipToken.getCurrentCheckpointId();
        uint256 prevDistributorBalance = distribtionToken.balanceOf(
            dividendCreator
        );
        uint256 prevVaultBalance = distribtionToken.balanceOf(address(vault));

        assertEq(prevDistributorBalance, DISTRIBUTION_AMOUNT);
        assertEq(prevVaultBalance, 0);

        uint256 failTime = block.timestamp - 1;
        uint256 failAmount = 0;
        address failAddress = address(0);

        vm.expectRevert(bytes("Vault: Expiry must be in the future"));
        vault.createDividend(failTime, successAddress, successAmount);
        vm.expectRevert(bytes("Vault: Amount must be greater than 0"));
        vault.createDividend(successTime, successAddress, failAmount);
        vm.expectRevert(bytes("Vault: Token must be valid address"));
        vault.createDividend(successTime, failAddress, successAmount);

        (uint256 checkpointId, uint256 dividendIndex) = vault.createDividend(
            successTime,
            successAddress,
            successAmount
        );

        uint256 currentSnapshotId = ownershipToken.getCurrentCheckpointId();
        uint256 postDistributorBalance = distribtionToken.balanceOf(
            dividendCreator
        );
        uint256 postVaultBalance = distribtionToken.balanceOf(address(vault));

        assertEq(currentSnapshotId, checkpointId);
        assertEq(prevSnapshotId + 1, currentSnapshotId);

        assertEq(postDistributorBalance, 0);
        assertEq(postVaultBalance, DISTRIBUTION_AMOUNT);

        // Test Dividend creation
        (
            uint256 checkpointIdDiv,
            uint256 created,
            uint256 expiry,
            uint256 amount,
            uint256 claimedAmount,
            bool reclaimed
        ) = vault.dividends(dividendIndex);

        assertEq(checkpointIdDiv, checkpointId);
        assertEq(created, block.timestamp);
        assertEq(expiry, successTime);
        assertEq(amount, successAmount);
        assertEq(claimedAmount, 0);
        assertEq(reclaimed, false);
    }

    function testDividendClaim() external {
        (uint256 checkpointId, uint256 dividendIndex) = vault.createDividend(
            successTime,
            successAddress,
            successAmount
        );
    }
}
