// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {ERC20PresetFixedSupply} from "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import "../src/ClaimToken.sol";
import "../src/Vault.sol";

contract VaultTest is Test {
    ClaimToken public ownershipToken;
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

    function setUp() external {
        vm.startPrank(dividendCreator);

        ownershipToken = new ClaimToken("Claim", "CLM");
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

        vaultSingle = new Vault(ownershipToken, addresses1, 0);

        address[] memory addresses2 = new address[](3);
        addresses2[0] = address(distributionToken1);
        addresses2[1] = address(distributionToken2);
        addresses2[2] = address(distributionToken3);

        vaultMultiple = new Vault(ownershipToken, addresses2, 0);

        ownershipToken.mint(shareholder1, SHAREHOLDER1_AMOUNT);
        ownershipToken.mint(shareholder2, SHAREHOLDER2_AMOUNT);

        ownershipToken.grantCheckpoint(address(vaultSingle));
        distributionToken1.approve(address(vaultSingle), 2**256 - 1);

        ownershipToken.grantCheckpoint(address(vaultMultiple));
        distributionToken1.approve(address(vaultMultiple), 2**256 - 1);
        distributionToken2.approve(address(vaultMultiple), 2**256 - 1);
        distributionToken3.approve(address(vaultMultiple), 2**256 - 1);

        vm.label(shareholder1, "SHAREHOLDER1");
        vm.label(shareholder2, "SHAREHOLDER2");
        vm.label(dividendCreator, "DIVIDEND_CREATOR");
        vm.label(address(distributionToken1), "DISTRIBUTION_TOKEN1");
        vm.label(address(distributionToken2), "DISTRIBUTION_TOKEN2");
        vm.label(address(distributionToken3), "DISTRIBUTION_TOKEN3");
        vm.label(address(ownershipToken), "OWNERSHIP_TOKEN");
        vm.label(address(vaultSingle), "VAULT");
    }

    function testCreateDividend() external {
        vm.expectRevert(bytes("Vault: id is 0"));
        vaultSingle.dividendAmountsAt(0);

        distributionToken1.transfer(address(vaultSingle), 1000);
        (, uint256 dividendIndex1) = vaultSingle.createDividend();
        assertEq(dividendIndex1, 1, "dividendIndex1");
        assertEq(vaultSingle.dividendAmountsAt(dividendIndex1)[0], 1000);

        //By pass rate limit
        vm.warp(block.timestamp + 1);

        distributionToken1.transfer(address(vaultSingle), 2000);
        (, uint256 dividendIndex2) = vaultSingle.createDividend();
        assertEq(dividendIndex2, 2, "dividendIndex2");
        assertEq(vaultSingle.dividendAmountsAt(dividendIndex2)[0], 2000);

        //By pass rate limit
        vm.warp(block.timestamp + 1);

        distributionToken1.transfer(address(vaultSingle), 5000);
        (, uint256 dividendIndex3) = vaultSingle.createDividend();
        assertEq(dividendIndex3, 3, "dividendIndex3");
        assertEq(vaultSingle.dividendAmountsAt(dividendIndex3)[0], 5000);

        distributionToken1.transfer(address(vaultSingle), 2500);
        assertEq(vaultSingle.dividendAmountsAt(dividendIndex3 + 1)[0], 2500);

        vm.expectRevert(bytes("Vault: nonexistent id"));
        vaultSingle.dividendAmountsAt(dividendIndex3 + 2);
    }

    function testCreateDividendMultiple() external {
        vm.expectRevert(bytes("Vault: id is 0"));
        vaultMultiple.dividendAmountsAt(0);

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

        distributionToken1.transfer(address(vaultMultiple), dt1Amount1);
        distributionToken2.transfer(address(vaultMultiple), dt2Amount1);
        distributionToken3.transfer(address(vaultMultiple), dt3Amount1);

        (, uint256 dividendIndex1) = vaultMultiple.createDividend();
        assertEq(dividendIndex1, 1, "dividendIndex1");
        assertEq(
            vaultMultiple.dividendAmountsAt(dividendIndex1)[0],
            dt1Amount1
        );
        assertEq(
            vaultMultiple.dividendAmountsAt(dividendIndex1)[1],
            dt2Amount1
        );
        assertEq(
            vaultMultiple.dividendAmountsAt(dividendIndex1)[2],
            dt3Amount1
        );

        //By pass rate limit
        vm.warp(block.timestamp + 1);

        distributionToken1.transfer(address(vaultMultiple), dt1Amount2);
        distributionToken2.transfer(address(vaultMultiple), dt2Amount2);
        distributionToken3.transfer(address(vaultMultiple), dt3Amount2);

        (, uint256 dividendIndex2) = vaultMultiple.createDividend();
        assertEq(dividendIndex2, 2, "dividendIndex2");
        assertEq(
            vaultMultiple.dividendAmountsAt(dividendIndex2)[0],
            dt1Amount2
        );
        assertEq(
            vaultMultiple.dividendAmountsAt(dividendIndex2)[1],
            dt2Amount2
        );
        assertEq(
            vaultMultiple.dividendAmountsAt(dividendIndex2)[2],
            dt3Amount2
        );

        //By pass rate limit
        vm.warp(block.timestamp + 1);

        distributionToken1.transfer(address(vaultMultiple), dt1Amount3);
        distributionToken2.transfer(address(vaultMultiple), dt2Amount3);
        distributionToken3.transfer(address(vaultMultiple), dt3Amount3);

        (, uint256 dividendIndex3) = vaultMultiple.createDividend();
        assertEq(dividendIndex3, 3, "dividendIndex3");
        assertEq(
            vaultMultiple.dividendAmountsAt(dividendIndex3)[0],
            dt1Amount3
        );
        assertEq(
            vaultMultiple.dividendAmountsAt(dividendIndex3)[1],
            dt2Amount3
        );
        assertEq(
            vaultMultiple.dividendAmountsAt(dividendIndex3)[2],
            dt3Amount3
        );

        distributionToken1.transfer(address(vaultMultiple), dt1Amount4);
        distributionToken2.transfer(address(vaultMultiple), dt2Amount4);
        distributionToken3.transfer(address(vaultMultiple), dt3Amount4);

        assertEq(
            vaultMultiple.dividendAmountsAt(dividendIndex3 + 1)[0],
            dt1Amount4
        );
        assertEq(
            vaultMultiple.dividendAmountsAt(dividendIndex3 + 1)[1],
            dt2Amount4
        );
        assertEq(
            vaultMultiple.dividendAmountsAt(dividendIndex3 + 1)[2],
            dt3Amount4
        );

        vm.expectRevert(bytes("Vault: nonexistent id"));
        vaultMultiple.dividendAmountsAt(dividendIndex3 + 2);
    }

    function testDividendClaim() external {
        // distributionToken1.transfer(address(vaultSingle), 1000);
        // (, uint256 dividendIndex1) = vaultSingle.createDividend();
        // distributionToken1.transfer(address(vaultSingle), 2000);
        // (, uint256 dividendIndex2) = vaultSingle.createDividend();
        // distributionToken1.transfer(address(vaultSingle), 5000);
        // (, uint256 dividendIndex3) = vaultSingle.createDividend();
        // distributionToken1.transfer(address(vaultSingle), 2500);
        // vm.expectRevert(bytes("Vault: Invalid dividend index"));
        // vaultSingle.claimDividend(dividendIndex3 + 1);
        // (, , , uint256 amount, , ) = vaultSingle.dividends(dividendIndex);
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
        // assertEq(distributionToken1.balanceOf(shareholder1), 0);
        // assertEq(distributionToken1.balanceOf(shareholder2), 0);
        // assertEq(distributionToken1.balanceOf(nonShareholder), 0);
        // vm.stopPrank();
        // vm.prank(shareholder1);
        // vaultSingle.claimDividend(dividendIndex);
        // assertEq(distributionToken1.balanceOf(shareholder1), shareholder1Claim);
        // assertEq(
        //     distributionToken1.balanceOf(address(vaultSingle)),
        //     DISTRIBUTION_AMOUNT - shareholder1Claim
        // );
        // vm.prank(shareholder1);
        // vm.expectRevert(bytes("Vault: Already claimed"));
        // vaultSingle.claimDividend(dividendIndex);
        // vm.prank(nonShareholder);
        // vaultSingle.claimDividend(dividendIndex);
        // assertEq(distributionToken1.balanceOf(nonShareholder), 0);
        // vm.prank(shareholder2);
        // vaultSingle.claimDividend(dividendIndex);
        // assertEq(distributionToken1.balanceOf(shareholder2), shareholder2Claim);
        // assertEq(
        //     distributionToken1.balanceOf(address(vaultSingle)),
        //     DISTRIBUTION_AMOUNT - shareholder1Claim - shareholder2Claim
        // );
    }
}
