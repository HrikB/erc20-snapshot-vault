// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {ERC20PresetFixedSupply} from "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import "../src/ClaimToken.sol";
import "../src/Vault.sol";

contract VaultTest is Test {
    ClaimToken public claimToken;
    ERC20PresetFixedSupply public distributionToken1;
    ERC20PresetFixedSupply public distributionToken2;
    ERC20PresetFixedSupply public distributionToken3;

    Vault public vaultSingle;
    Vault public vaultMultiple;

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

    // Amounts to transfer into vault contract
    uint256 dt1Amount1 = 1000;
    uint256 dt1Amount2 = 3500;
    uint256 dt1Amount3 = 2250;
    uint256 dt1Amount4 = 2000;

    uint256 dt2Amount1 = 2000;
    uint256 dt2Amount2 = 4000;
    uint256 dt2Amount3 = 1500;
    uint256 dt2Amount4 = 1000;

    uint256 dt3Amount1 = 3000;
    uint256 dt3Amount2 = 4250;
    uint256 dt3Amount3 = 1250;
    uint256 dt3Amount4 = 2500;

    function setUp() external {
        vm.startPrank(dividendCreator);

        claimToken = new ClaimToken("Claim", "CLM");
        distributionToken1 = new ERC20PresetFixedSupply(
            "Distribution1",
            "DSTR1",
            DISTRIBUTION_AMOUNT,
            dividendCreator
        );
        distributionToken2 = new ERC20PresetFixedSupply(
            "Distribution2",
            "DSTR2",
            DISTRIBUTION_AMOUNT,
            dividendCreator
        );
        distributionToken3 = new ERC20PresetFixedSupply(
            "Distribution3",
            "DSTR3",
            DISTRIBUTION_AMOUNT,
            dividendCreator
        );

        address[] memory addresses1 = new address[](1);
        addresses1[0] = address(distributionToken1);

        vaultSingle = new Vault(claimToken, addresses1, 0);

        address[] memory addresses2 = new address[](3);
        addresses2[0] = address(distributionToken1);
        addresses2[1] = address(distributionToken2);
        addresses2[2] = address(distributionToken3);

        vaultMultiple = new Vault(claimToken, addresses2, 0);

        claimToken.mint(shareholder1, SHAREHOLDER1_AMOUNT);
        claimToken.mint(shareholder2, SHAREHOLDER2_AMOUNT);

        claimToken.grantCheckpoint(address(vaultSingle));
        distributionToken1.approve(address(vaultSingle), 2**256 - 1);

        claimToken.grantCheckpoint(address(vaultMultiple));
        distributionToken1.approve(address(vaultMultiple), 2**256 - 1);
        distributionToken2.approve(address(vaultMultiple), 2**256 - 1);
        distributionToken3.approve(address(vaultMultiple), 2**256 - 1);

        vm.label(shareholder1, "SHAREHOLDER1");
        vm.label(shareholder2, "SHAREHOLDER2");
        vm.label(dividendCreator, "DIVIDEND_CREATOR");
        vm.label(address(distributionToken1), "DISTRIBUTION_TOKEN1");
        vm.label(address(distributionToken2), "DISTRIBUTION_TOKEN2");
        vm.label(address(distributionToken3), "DISTRIBUTION_TOKEN3");
        vm.label(address(claimToken), "OWNERSHIP_TOKEN");
        vm.label(address(vaultSingle), "VAULT");
    }

    function testCreateDividend() external {
        vm.expectRevert(bytes("Vault: id is 0"));
        vaultSingle.dividendAmountAt(0, 0);

        distributionToken1.transfer(address(vaultSingle), dt1Amount1);
        (, uint256 dividendId1) = vaultSingle.createDividend();
        assertEq(dividendId1, 1, "dividendId1");
        assertEq(vaultSingle.dividendAmountAt(dividendId1, 0), dt1Amount1);

        //By pass rate limit
        vm.warp(block.timestamp + 1);

        distributionToken1.transfer(address(vaultSingle), dt1Amount2);
        (, uint256 dividendId2) = vaultSingle.createDividend();
        assertEq(dividendId2, 2, "dividendId2");
        assertEq(vaultSingle.dividendAmountAt(dividendId2, 0), dt1Amount2);

        //By pass rate limit
        vm.warp(block.timestamp + 1);

        distributionToken1.transfer(address(vaultSingle), dt1Amount3);
        (, uint256 dividendId3) = vaultSingle.createDividend();
        assertEq(dividendId3, 3, "dividendId3");
        assertEq(vaultSingle.dividendAmountAt(dividendId3, 0), dt1Amount3);

        distributionToken1.transfer(address(vaultSingle), dt1Amount4);
        assertEq(vaultSingle.dividendAmountAt(dividendId3 + 1, 0), dt1Amount4);

        vm.expectRevert(bytes("Vault: nonexistent id"));
        vaultSingle.dividendAmountAt(dividendId3 + 2, 0);
    }

    function testCreateDividendMultiple() external {
        vm.expectRevert(bytes("Vault: id is 0"));
        vaultMultiple.dividendAmountAt(0, 0);

        distributionToken1.transfer(address(vaultMultiple), dt1Amount1);
        distributionToken2.transfer(address(vaultMultiple), dt2Amount1);
        distributionToken3.transfer(address(vaultMultiple), dt3Amount1);

        (, uint256 dividendId1) = vaultMultiple.createDividend();
        assertEq(dividendId1, 1, "dividendId1");
        assertEq(vaultMultiple.dividendAmountAt(dividendId1, 0), dt1Amount1);
        assertEq(vaultMultiple.dividendAmountAt(dividendId1, 1), dt2Amount1);
        assertEq(vaultMultiple.dividendAmountAt(dividendId1, 2), dt3Amount1);

        //By pass rate limit
        vm.warp(block.timestamp + 1);

        distributionToken1.transfer(address(vaultMultiple), dt1Amount2);
        distributionToken2.transfer(address(vaultMultiple), dt2Amount2);
        distributionToken3.transfer(address(vaultMultiple), dt3Amount2);

        (, uint256 dividendId2) = vaultMultiple.createDividend();
        assertEq(dividendId2, 2, "dividendId2");
        assertEq(vaultMultiple.dividendAmountAt(dividendId2, 0), dt1Amount2);
        assertEq(vaultMultiple.dividendAmountAt(dividendId2, 1), dt2Amount2);
        assertEq(vaultMultiple.dividendAmountAt(dividendId2, 2), dt3Amount2);

        //By pass rate limit
        vm.warp(block.timestamp + 1);

        distributionToken1.transfer(address(vaultMultiple), dt1Amount3);
        distributionToken2.transfer(address(vaultMultiple), dt2Amount3);
        distributionToken3.transfer(address(vaultMultiple), dt3Amount3);

        (, uint256 dividendId3) = vaultMultiple.createDividend();
        assertEq(dividendId3, 3, "dividendId3");
        assertEq(vaultMultiple.dividendAmountAt(dividendId3, 0), dt1Amount3);
        assertEq(vaultMultiple.dividendAmountAt(dividendId3, 1), dt2Amount3);
        assertEq(vaultMultiple.dividendAmountAt(dividendId3, 2), dt3Amount3);

        distributionToken1.transfer(address(vaultMultiple), dt1Amount4);
        distributionToken2.transfer(address(vaultMultiple), dt2Amount4);
        distributionToken3.transfer(address(vaultMultiple), dt3Amount4);

        assertEq(
            vaultMultiple.dividendAmountAt(dividendId3 + 1, 0),
            dt1Amount4
        );
        assertEq(
            vaultMultiple.dividendAmountAt(dividendId3 + 1, 1),
            dt2Amount4
        );
        assertEq(
            vaultMultiple.dividendAmountAt(dividendId3 + 1, 2),
            dt3Amount4
        );

        vm.expectRevert(bytes("Vault: nonexistent id"));
        vaultMultiple.dividendAmountAt(dividendId3 + 2, 0);
    }

    function testClaimXDividend() external {
        distributionToken1.transfer(address(vaultSingle), dt1Amount1);
        (, uint256 dividendId1) = vaultSingle.createDividend();
        distributionToken1.transfer(address(vaultSingle), dt1Amount2);
        vm.warp(block.timestamp + 1);
        (, uint256 dividendId2) = vaultSingle.createDividend();

        uint256 totalVaultAmount1 = dt1Amount1 + dt1Amount2;
        assertEq(
            distributionToken1.balanceOf(address(vaultSingle)),
            totalVaultAmount1
        );

        vm.stopPrank();
        uint256 s1Claim1Amount = (SHAREHOLDER1_AMOUNT * dt1Amount1) /
            DISTRIBUTION_AMOUNT;
        uint256 s2Claim1Amount = (SHAREHOLDER2_AMOUNT * dt1Amount1) /
            DISTRIBUTION_AMOUNT;
        uint256 s1Claim2Amount = (SHAREHOLDER1_AMOUNT * dt1Amount2) /
            DISTRIBUTION_AMOUNT;
        uint256 s2Claim2Amount = (SHAREHOLDER2_AMOUNT * dt1Amount2) /
            DISTRIBUTION_AMOUNT;

        assertEq(distributionToken1.balanceOf(shareholder1), 0);
        assertEq(distributionToken1.balanceOf(shareholder2), 0);
        vm.prank(shareholder1);
        vaultSingle.claimDividend(dividendId1);
        assertEq(distributionToken1.balanceOf(shareholder1), s1Claim1Amount);
        assertEq(distributionToken1.balanceOf(shareholder2), 0);

        totalVaultAmount1 -= s1Claim1Amount;
        assertEq(
            distributionToken1.balanceOf(address(vaultSingle)),
            totalVaultAmount1
        );

        vm.prank(shareholder2);
        vaultSingle.claimDividend(dividendId2);
        assertEq(distributionToken1.balanceOf(shareholder1), s1Claim1Amount);
        assertEq(distributionToken1.balanceOf(shareholder2), s2Claim2Amount);

        totalVaultAmount1 -= s2Claim2Amount;
        assertEq(
            distributionToken1.balanceOf(address(vaultSingle)),
            totalVaultAmount1
        );

        vm.prank(shareholder1);
        vaultSingle.claimDividend(dividendId2);
        assertEq(
            distributionToken1.balanceOf(shareholder1),
            s1Claim1Amount + s1Claim2Amount
        );
        assertEq(distributionToken1.balanceOf(shareholder2), s2Claim2Amount);

        totalVaultAmount1 -= s1Claim2Amount;
        assertEq(
            distributionToken1.balanceOf(address(vaultSingle)),
            totalVaultAmount1
        );

        vm.prank(shareholder2);
        vaultSingle.claimDividend(dividendId1);
        assertEq(
            distributionToken1.balanceOf(shareholder1),
            s1Claim1Amount + s1Claim2Amount
        );
        assertEq(
            distributionToken1.balanceOf(shareholder2),
            s2Claim1Amount + s2Claim2Amount
        );
        assertEq(distributionToken1.balanceOf(address(vaultSingle)), 0);

        vm.expectRevert(bytes("Vault: Invalid dividend index"));
        vaultSingle.claimDividend(dividendId2 + 1);
    }

    // Stack too deep
    uint256 s1Claim1AmountToken1 =
        (SHAREHOLDER1_AMOUNT * dt1Amount1) / DISTRIBUTION_AMOUNT;
    uint256 s2Claim1AmountToken1 =
        (SHAREHOLDER2_AMOUNT * dt1Amount1) / DISTRIBUTION_AMOUNT;
    uint256 s1Claim2AmountToken1 =
        (SHAREHOLDER1_AMOUNT * dt1Amount2) / DISTRIBUTION_AMOUNT;
    uint256 s2Claim2AmountToken1 =
        (SHAREHOLDER2_AMOUNT * dt1Amount2) / DISTRIBUTION_AMOUNT;

    uint256 s1Claim1AmountToken2 =
        (SHAREHOLDER1_AMOUNT * dt2Amount1) / DISTRIBUTION_AMOUNT;
    uint256 s2Claim1AmountToken2 =
        (SHAREHOLDER2_AMOUNT * dt2Amount1) / DISTRIBUTION_AMOUNT;
    uint256 s1Claim2AmountToken2 =
        (SHAREHOLDER1_AMOUNT * dt2Amount2) / DISTRIBUTION_AMOUNT;
    uint256 s2Claim2AmountToken2 =
        (SHAREHOLDER2_AMOUNT * dt2Amount2) / DISTRIBUTION_AMOUNT;

    uint256 s1Claim1AmountToken3 =
        (SHAREHOLDER1_AMOUNT * dt3Amount1) / DISTRIBUTION_AMOUNT;
    uint256 s2Claim1AmountToken3 =
        (SHAREHOLDER2_AMOUNT * dt3Amount1) / DISTRIBUTION_AMOUNT;
    uint256 s1Claim2AmountToken3 =
        (SHAREHOLDER1_AMOUNT * dt3Amount2) / DISTRIBUTION_AMOUNT;
    uint256 s2Claim2AmountToken3 =
        (SHAREHOLDER2_AMOUNT * dt3Amount2) / DISTRIBUTION_AMOUNT;

    function testClaimDividendMultiple() external {
        distributionToken1.transfer(address(vaultMultiple), dt1Amount1);
        distributionToken2.transfer(address(vaultMultiple), dt2Amount1);
        distributionToken3.transfer(address(vaultMultiple), dt3Amount1);
        (, uint256 dividendId1) = vaultMultiple.createDividend();
        distributionToken1.transfer(address(vaultMultiple), dt1Amount2);
        distributionToken2.transfer(address(vaultMultiple), dt2Amount2);
        distributionToken3.transfer(address(vaultMultiple), dt3Amount2);
        vm.warp(block.timestamp + 1);
        (, uint256 dividendId2) = vaultMultiple.createDividend();

        uint256 totalVaultAmount1 = dt1Amount1 + dt1Amount2;
        assertEq(
            distributionToken1.balanceOf(address(vaultMultiple)),
            totalVaultAmount1
        );
        uint256 totalVaultAmount2 = dt2Amount1 + dt2Amount2;
        assertEq(
            distributionToken2.balanceOf(address(vaultMultiple)),
            totalVaultAmount2
        );
        uint256 totalVaultAmount3 = dt3Amount1 + dt3Amount2;
        assertEq(
            distributionToken3.balanceOf(address(vaultMultiple)),
            totalVaultAmount3
        );

        vm.stopPrank();

        assertEq(distributionToken1.balanceOf(shareholder1), 0);
        assertEq(distributionToken1.balanceOf(shareholder2), 0);
        assertEq(distributionToken2.balanceOf(shareholder1), 0);
        assertEq(distributionToken2.balanceOf(shareholder2), 0);
        assertEq(distributionToken3.balanceOf(shareholder1), 0);
        assertEq(distributionToken3.balanceOf(shareholder2), 0);
        vm.prank(shareholder1);
        vaultMultiple.claimDividend(dividendId1);
        assertEq(
            distributionToken1.balanceOf(shareholder1),
            s1Claim1AmountToken1
        );
        assertEq(
            distributionToken2.balanceOf(shareholder1),
            s1Claim1AmountToken2
        );
        assertEq(
            distributionToken3.balanceOf(shareholder1),
            s1Claim1AmountToken3
        );
        assertEq(distributionToken1.balanceOf(shareholder2), 0);
        assertEq(distributionToken2.balanceOf(shareholder2), 0);
        assertEq(distributionToken3.balanceOf(shareholder2), 0);

        totalVaultAmount1 -= s1Claim1AmountToken1;
        totalVaultAmount2 -= s1Claim1AmountToken2;
        totalVaultAmount3 -= s1Claim1AmountToken3;
        assertEq(
            distributionToken1.balanceOf(address(vaultMultiple)),
            totalVaultAmount1
        );
        assertEq(
            distributionToken2.balanceOf(address(vaultMultiple)),
            totalVaultAmount2
        );
        assertEq(
            distributionToken3.balanceOf(address(vaultMultiple)),
            totalVaultAmount3
        );

        vm.prank(shareholder2);
        vaultMultiple.claimDividend(dividendId2);
        assertEq(
            distributionToken1.balanceOf(shareholder1),
            s1Claim1AmountToken1
        );
        assertEq(
            distributionToken2.balanceOf(shareholder1),
            s1Claim1AmountToken2
        );
        assertEq(
            distributionToken3.balanceOf(shareholder1),
            s1Claim1AmountToken3
        );
        assertEq(
            distributionToken1.balanceOf(shareholder2),
            s2Claim2AmountToken1
        );
        assertEq(
            distributionToken2.balanceOf(shareholder2),
            s2Claim2AmountToken2
        );
        assertEq(
            distributionToken3.balanceOf(shareholder2),
            s2Claim2AmountToken3
        );

        totalVaultAmount1 -= s2Claim2AmountToken1;
        totalVaultAmount2 -= s2Claim2AmountToken2;
        totalVaultAmount3 -= s2Claim2AmountToken3;
        assertEq(
            distributionToken1.balanceOf(address(vaultMultiple)),
            totalVaultAmount1
        );
        assertEq(
            distributionToken2.balanceOf(address(vaultMultiple)),
            totalVaultAmount2
        );
        assertEq(
            distributionToken3.balanceOf(address(vaultMultiple)),
            totalVaultAmount3
        );

        vm.prank(shareholder1);
        vaultMultiple.claimDividend(dividendId2);
        assertEq(
            distributionToken1.balanceOf(shareholder1),
            s1Claim1AmountToken1 + s1Claim2AmountToken1
        );
        assertEq(
            distributionToken2.balanceOf(shareholder1),
            s1Claim1AmountToken2 + s1Claim2AmountToken2
        );
        assertEq(
            distributionToken3.balanceOf(shareholder1),
            s1Claim1AmountToken3 + s1Claim2AmountToken3
        );
        assertEq(
            distributionToken1.balanceOf(shareholder2),
            s2Claim2AmountToken1
        );
        assertEq(
            distributionToken2.balanceOf(shareholder2),
            s2Claim2AmountToken2
        );
        assertEq(
            distributionToken3.balanceOf(shareholder2),
            s2Claim2AmountToken3
        );

        totalVaultAmount1 -= s1Claim2AmountToken1;
        totalVaultAmount2 -= s1Claim2AmountToken2;
        totalVaultAmount3 -= s1Claim2AmountToken3;
        assertEq(
            distributionToken1.balanceOf(address(vaultMultiple)),
            totalVaultAmount1
        );
        assertEq(
            distributionToken2.balanceOf(address(vaultMultiple)),
            totalVaultAmount2
        );
        assertEq(
            distributionToken3.balanceOf(address(vaultMultiple)),
            totalVaultAmount3
        );

        vm.prank(shareholder2);
        vaultMultiple.claimDividend(dividendId1);
        assertEq(
            distributionToken1.balanceOf(shareholder1),
            s1Claim1AmountToken1 + s1Claim2AmountToken1
        );
        assertEq(
            distributionToken2.balanceOf(shareholder1),
            s1Claim1AmountToken2 + s1Claim2AmountToken2
        );
        assertEq(
            distributionToken3.balanceOf(shareholder1),
            s1Claim1AmountToken3 + s1Claim2AmountToken3
        );
        assertEq(
            distributionToken1.balanceOf(shareholder2),
            s2Claim1AmountToken1 + s2Claim2AmountToken1
        );
        assertEq(
            distributionToken2.balanceOf(shareholder2),
            s2Claim1AmountToken2 + s2Claim2AmountToken2
        );
        assertEq(
            distributionToken3.balanceOf(shareholder2),
            s2Claim1AmountToken3 + s2Claim2AmountToken3
        );

        assertEq(distributionToken1.balanceOf(address(vaultMultiple)), 0);
        assertEq(distributionToken2.balanceOf(address(vaultMultiple)), 0);
        assertEq(distributionToken3.balanceOf(address(vaultMultiple)), 0);
    }
}
