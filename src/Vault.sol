// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

import {ClaimToken} from "./ClaimToken.sol";
import {IVault} from "./IVault.sol";
import {DividendSnapshots} from "./VaultLib.sol";

import "forge-std/console.sol";

/**
 *
 */
contract Vault is IVault {
    using Counters for Counters.Counter;
    using EnumerableMap for EnumerableMap.UintToAddressMap;

    ClaimToken claimToken;
    address[] internal distributionTokens;

    DividendSnapshots dividendSnapshots;
    uint256[] public totalDividendsClaimed;
    Counters.Counter public _currentDividendId;

    uint256 immutable _rateLimit;
    uint256 lastTime;

    // CheckpointId => Shareholder address => claim bool
    mapping(uint256 => mapping(address => bool)) public tokensClaimed;

    modifier rateLimit() {
        require(
            block.timestamp - lastTime > _rateLimit,
            "Vault: Rate limit exceeded"
        );
        lastTime = block.timestamp;
        _;
    }

    constructor(
        ClaimToken _claimToken,
        address[] memory _distributionTokens,
        uint256 rateLimit_
    ) {
        claimToken = _claimToken;
        distributionTokens = _distributionTokens;

        dividendSnapshots.values = new uint256[][](_distributionTokens.length);
        totalDividendsClaimed = new uint256[](_distributionTokens.length);

        _rateLimit = rateLimit_;
    }

    function createDividend() external rateLimit returns (uint256, uint256) {
        _currentDividendId.increment();

        uint256 currentId = getCurrentDividendId();

        uint256 tokenCheckpointId = claimToken.createCheckpoint();

        dividendSnapshots.checkpoints.push(tokenCheckpointId);
        dividendSnapshots.ids.push(currentId);
        for (uint256 i = 0; i < distributionTokens.length; i++) {
            dividendSnapshots.values[i].push(
                totalDividendsClaimed[i] +
                    ERC20(distributionTokens[i]).balanceOf(address(this))
            );
        }
        return (tokenCheckpointId, currentId);
    }

    function getCurrentDividendId() public view returns (uint256) {
        return _currentDividendId.current();
    }

    function claimDividend(uint256 _dividendId) external {
        require(
            !tokensClaimed[_dividendId][msg.sender],
            "Vault: Already claimed"
        );
        _payDividend(msg.sender, _dividendId);
    }

    function _payDividend(address _shareholder, uint256 _dividendId) internal {
        require(
            _dividendId > 0 && _dividendId <= dividendSnapshots.ids.length,
            "Vault: Invalid dividend index"
        );
        uint256 index = _dividendId - 1;

        uint256 snapshotBalance = claimToken.balanceOfAt(
            _shareholder,
            dividendSnapshots.checkpoints[index]
        );
        uint256 snapshotTotalSupply = claimToken.totalSupplyAt(_dividendId);

        // No reentrancy vunerability with ERC20
        tokensClaimed[_dividendId][_shareholder] = true;

        for (uint256 i = 0; i < distributionTokens.length; i++) {
            uint256 claimAmount = _calculateClaimHelper(
                snapshotBalance,
                snapshotTotalSupply,
                _dividendId,
                i
            );

            address token = distributionTokens[i];

            totalDividendsClaimed[i] += claimAmount;
            ERC20(token).transfer(_shareholder, claimAmount);
            emit ShareholderClaim(
                _shareholder,
                _dividendId,
                token,
                claimAmount
            );
        }
    }

    function calculateClaim(
        address _shareholder,
        uint256 _dividendId,
        uint256 tokenIndex
    ) external view returns (uint256) {
        require(
            _dividendId > 0 && _dividendId <= dividendSnapshots.ids.length,
            "Vault: Invalid dividend index"
        );
        if (tokensClaimed[_dividendId][_shareholder]) return 0;

        uint256 index = _dividendId - 1;

        uint256 snapshotBalance = claimToken.balanceOfAt(
            _shareholder,
            dividendSnapshots.checkpoints[index]
        );

        uint256 snapshotTotalSupply = claimToken.totalSupplyAt(_dividendId);
        return
            _calculateClaimHelper(
                snapshotBalance,
                snapshotTotalSupply,
                _dividendId,
                tokenIndex
            );
    }

    function _calculateClaimHelper(
        uint256 snapshotBalance,
        uint256 snapshotTotalSupply,
        uint256 _dividendId,
        uint256 tokenIndex
    ) internal view returns (uint256) {
        return
            (snapshotBalance * dividendAmountAt(_dividendId, tokenIndex)) /
            snapshotTotalSupply;
    }

    function dividendAmountAt(uint256 _dividendId, uint256 tokenIndex)
        public
        view
        returns (uint256)
    {
        (bool snapshotted, uint256 currValue) = _valueAt(
            _dividendId,
            tokenIndex
        );
        (, uint256 prevValue) = _dividendId == 1
            ? (false, 0)
            : _valueAt(_dividendId - 1, tokenIndex);

        if (snapshotted) return currValue - prevValue;

        return
            totalDividendsClaimed[tokenIndex] +
            ERC20(distributionTokens[tokenIndex]).balanceOf(address(this)) -
            prevValue;
    }

    function _valueAt(uint256 _dividendId, uint256 tokenIndex)
        internal
        view
        returns (bool, uint256)
    {
        require(tokenIndex < distributionTokens.length, "Vault: Invalid token");
        require(_dividendId > 0, "Vault: id is 0");
        require(
            _dividendId <= getCurrentDividendId() + 1,
            "Vault: nonexistent id"
        );

        uint256 index = _dividendId - 1;

        if (index == dividendSnapshots.ids.length) return (false, 0);

        return (true, dividendSnapshots.values[tokenIndex][index]);
    }
}
