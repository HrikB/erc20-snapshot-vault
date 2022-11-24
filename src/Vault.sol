// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Arrays} from "@openzeppelin/contracts/utils/Arrays.sol";
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";

import {ClaimToken} from "./ClaimToken.sol";
import {IVault} from "./IVault.sol";
import {DividendSnapshots} from "./VaultLib.sol";

import "forge-std/console.sol";

contract Vault is AccessControl, IVault {
    using Arrays for uint256[];
    using Counters for Counters.Counter;

    ClaimToken claimToken;
    ERC20 distributionToken;

    DividendSnapshots dividendSnapshots;
    uint256 public totalDividendsClaimed;
    Counters.Counter public _currentDividendId;

    mapping(uint256 => address) public dividendTokens;
    // CheckpointId => Shareholder address => claim bool
    mapping(uint256 => mapping(address => bool)) public tokensClaimed;

    bytes32 internal constant DIVIDEND_ROLE = keccak256("DIVIDEND_ROLE");

    constructor(ClaimToken _claimToken, address _distributionToken) {
        claimToken = _claimToken;
        distributionToken = ERC20(_distributionToken);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(DIVIDEND_ROLE, msg.sender);
    }

    function grantDividend(address _newAddress)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _grantRole(DIVIDEND_ROLE, _newAddress);
    }

    function createDividend()
        public
        onlyRole(DIVIDEND_ROLE)
        returns (uint256, uint256)
    {
        _currentDividendId.increment();

        uint256 currentId = getCurrentDividendId();

        uint256 tokenCheckpointId = claimToken.createCheckpoint();
        dividendSnapshots.ids.push(currentId);
        dividendSnapshots.checkpoints.push(tokenCheckpointId);
        dividendSnapshots.values.push(
            totalDividendsClaimed + distributionToken.balanceOf(address(this))
        );
        return (tokenCheckpointId, currentId);
    }

    function getCurrentDividendId() public returns (uint256) {
        return _currentDividendId.current();
    }

    function dividendAmountAt(uint256 _dividendId)
        public
        view
        returns (uint256)
    {
        (bool snapshotted, uint256 currValue) = _valueAt(_dividendId);
        (, uint256 prevValue) = _dividendId == 1
            ? (false, 0)
            : _valueAt(_dividendId - 1);

        return
            snapshotted
                ? currValue - prevValue
                : totalDividendsClaimed +
                    distributionToken.balanceOf(address(this)) -
                    prevValue;
    }

    function _valueAt(uint256 _dividendId)
        private
        view
        returns (bool, uint256)
    {
        require(_dividendId > 0, "ERC20Snapshot: id is 0");
        // require(
        //     _dividendId <= getCurrentDividendId(),
        //     "ERC20Snapshot: nonexistent id"
        // );

        uint256 index = dividendSnapshots.ids.findUpperBound(_dividendId);

        if (index == dividendSnapshots.ids.length) return (false, 0);
        else return (true, dividendSnapshots.values[index]);
    }

    function claimDividend(uint256 _dividendId) public {
        require(
            !tokensClaimed[_dividendId][msg.sender],
            "Vault: Already claimed"
        );
        _payDividend(msg.sender, _dividendId);
    }

    function _payDividend(address _shareholder, uint256 _dividendId) internal {
        uint256 claim = calculateDividend(_dividendId, _shareholder);
        tokensClaimed[_dividendId][_shareholder] = true;
        totalDividendsClaimed += claim;
        ERC20(dividendTokens[_dividendId]).transfer(_shareholder, claim);
        emit ShareholderClaim(
            _shareholder,
            _dividendId,
            dividendTokens[_dividendId],
            claim
        );
    }

    function calculateDividend(uint256 _dividendId, address _shareholder)
        public
        view
        returns (uint256)
    {
        require(
            _dividendId < dividendSnapshots.ids.length,
            "Vault: Invalid dividend index"
        );
        if (tokensClaimed[_dividendId][_shareholder]) return 0;

        uint256 index = dividendSnapshots.ids.findUpperBound(_dividendId);

        uint256 snapshotBalance = claimToken.balanceOfAt(_shareholder, index);
        // Potentially storing this value in Dividend struct could save gas
        uint256 snapshotTotalSupply = claimToken.totalSupplyAt(_dividendId);
        uint256 claimBalance = (snapshotBalance *
            dividendAmountAt(_dividendId)) / snapshotTotalSupply;
        return claimBalance;
    }
}
