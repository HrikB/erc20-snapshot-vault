// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Arrays} from "@openzeppelin/contracts/utils/Arrays.sol";
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

import {ClaimToken} from "./ClaimToken.sol";
import {IVault} from "./IVault.sol";
import {DividendSnapshots} from "./VaultLib.sol";

import "forge-std/console.sol";

contract Vault is IVault {
    using Arrays for uint256[];
    using Counters for Counters.Counter;
    using EnumerableMap for EnumerableMap.UintToAddressMap;

    ClaimToken claimToken;
    EnumerableMap.UintToAddressMap private distributionTokens;

    DividendSnapshots dividendSnapshots;
    uint256[] public totalDividendsClaimed;
    Counters.Counter public _currentDividendId;

    uint256 immutable _rateLimit;
    uint256 lastTime;

    mapping(uint256 => address) public dividendTokens;
    // CheckpointId => Shareholder address => claim bool
    mapping(uint256 => mapping(address => bool)) public tokensClaimed;

    modifier rateLimit() {
        require(
            block.timestamp - lastTime > _rateLimit,
            "DividendCreator: Rate limit exceeded"
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
        for (uint256 i = 0; i < _distributionTokens.length; i++)
            distributionTokens.set(i, _distributionTokens[i]);

        dividendSnapshots.values = new uint256[][](_distributionTokens.length);
        console.log(dividendSnapshots.values.length);

        _rateLimit = rateLimit_;
    }

    function createDividend() public rateLimit returns (uint256, uint256) {
        _currentDividendId.increment();

        uint256 currentId = getCurrentDividendId();

        uint256 tokenCheckpointId = claimToken.createCheckpoint();

        dividendSnapshots.checkpoints.push(tokenCheckpointId);
        dividendSnapshots.ids.push(currentId);
        for (uint256 i = 0; i < distributionTokens.length(); i++) {
            dividendSnapshots.values[i].push(
                totalDividendsClaimed[i] +
                    ERC20(distributionTokens.get(i)).balanceOf(address(this))
            );
        }
        return (tokenCheckpointId, currentId);
    }

    function getCurrentDividendId() public view returns (uint256) {
        return _currentDividendId.current();
    }

    function dividendAmountsAt(uint256 _dividendId)
        public
        view
        returns (uint256[] memory)
    {
        (bool snapshotted, uint256[] memory currValues) = _valuesAt(
            _dividendId
        );
        (, uint256[] memory prevValues) = _dividendId == 1
            ? (false, new uint256[](0))
            : _valuesAt(_dividendId - 1);

        if (snapshotted) {
            for (uint256 i = 0; i < currValues.length; i++) {
                currValues[i] -= prevValues[i];
            }
            return currValues;
        }

        for (uint256 i = 0; i < prevValues.length; i++) {
            prevValues[i] =
                totalDividendsClaimed[i] +
                ERC20(distributionTokens.get(i)).balanceOf(address(this)) -
                prevValues[i];
        }
        return prevValues;
    }

    function _valuesAt(uint256 _dividendId)
        private
        view
        returns (bool, uint256[] memory)
    {
        require(_dividendId > 0, "ERC20Snapshot: id is 0");
        require(
            _dividendId <= getCurrentDividendId(),
            "ERC20Snapshot: nonexistent id"
        );

        uint256 index = dividendSnapshots.ids.findUpperBound(_dividendId);

        uint256[] memory valuesArr = new uint256[](distributionTokens.length());
        for (uint256 i = 0; i < valuesArr.length; i++)
            valuesArr[i] = dividendSnapshots.values[i][index];

        if (index == dividendSnapshots.ids.length) return (false, valuesArr);
        else return (true, valuesArr);
    }

    function claimDividend(uint256 _dividendId) public {
        require(
            !tokensClaimed[_dividendId][msg.sender],
            "Vault: Already claimed"
        );
        _payDividend(msg.sender, _dividendId);
    }

    function _payDividend(address _shareholder, uint256 _dividendId) internal {
        uint256[] memory claims = calculateDividend(_dividendId, _shareholder);
        tokensClaimed[_dividendId][_shareholder] = true;

        // This for loop is uneccesary since transfers can be done in the same
        // loop as calculations (from within calcualteDividend())
        for (uint256 i = 0; i < claims.length; i++) {
            address token = distributionTokens.get(i);
            uint256 claimAmount = claims[i];

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

    // Can probably removed since running for loop here and another for loop
    // during transfer doesn't make sense (extra gas cost). Just calculate and
    // transfer in the same loop.
    function calculateDividend(uint256 _dividendId, address _shareholder)
        public
        view
        returns (uint256[] memory)
    {
        require(
            _dividendId < dividendSnapshots.ids.length,
            "Vault: Invalid dividend index"
        );
        if (tokensClaimed[_dividendId][_shareholder])
            return new uint256[](distributionTokens.length());

        uint256 index = dividendSnapshots.ids.findUpperBound(_dividendId);

        uint256 snapshotBalance = claimToken.balanceOfAt(_shareholder, index);
        // Potentially storing this value in Dividend struct could save gas
        uint256 snapshotTotalSupply = claimToken.totalSupplyAt(_dividendId);

        uint256[] memory claims = dividendAmountsAt(_dividendId);
        for (uint256 i = 0; i < claims.length; i++)
            claims[i] = (snapshotBalance * claims[i]) / snapshotTotalSupply;

        return claims;
    }
}
