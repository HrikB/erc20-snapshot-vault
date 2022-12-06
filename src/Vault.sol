// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";
import {StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";

import {ClaimToken} from "./ClaimToken.sol";
import {IVault} from "./IVault.sol";
import {DividendSnapshots} from "./VaultLib.sol";
import {RateLimit} from "./RateLimit.sol";

/**
 * @title Vault
 * A Vault contract that can be configured to accept any set of ERC20 tokens whose
 * balances can than be distributed according to the holdings of a specificied
 * `ClaimToken`. The `ClaimToken` is a ERC20Snapshot token that can be used to
 * create checkpoints of the token balances at any point in time. The `Vault`
 * contract can then be used to distribute the ERC20 token according to the
 * balances of the `ClaimToken` at a specific checkpoint.
 *
 * This is a permissionless contract whose dividend creation process can be
 * triggered by anyone. In order to prevent spamming, a rate limit is enforced.
 */
contract Vault is IVault {
    using Counters for Counters.Counter;
    using StorageSlot for bytes32;

    ClaimToken claimToken;
    address[] internal distributionTokens;

    DividendSnapshots[] dividendSnapshots;
    uint256[] public totalDividendsClaimed;
    Counters.Counter public _currentDividendId;

    bytes32 internal constant RATE_LIMIT_SLOT = keccak256("RATE_LIMIT_SLOT");
    bytes32 internal constant LAST_TIME_SLOT = keccak256("LAST_TIME_SLOT");

    // DividendId => Shareholder address => claim bool
    mapping(uint256 => mapping(address => bool)) public tokensClaimed;

    modifier rateLimit(
        StorageSlot.Uint256Slot storage lastTimeSlot,
        StorageSlot.Uint256Slot storage rateLimitSlot
    ) {
        RateLimit.rateLimit(lastTimeSlot, rateLimitSlot);
        _;
    }

    constructor(
        ClaimToken _claimToken,
        address[] memory _distributionTokens,
        uint256 rateLimit_
    ) {
        claimToken = _claimToken;
        distributionTokens = _distributionTokens;

        totalDividendsClaimed = new uint256[](_distributionTokens.length);

        RATE_LIMIT_SLOT.getUint256Slot().value = rateLimit_;
    }

    /**
     * @dev Creates a dividend that can claimed by shareholders. This function
     * can be called by anyone but is rate limited to prevent spam.
     */
    function createDividend()
        external
        rateLimit(
            LAST_TIME_SLOT.getUint256Slot(),
            RATE_LIMIT_SLOT.getUint256Slot()
        )
        returns (uint256, uint256)
    {
        _currentDividendId.increment();

        uint256 currentId = getCurrentDividendId();

        uint256 tokenCheckpointId = claimToken.createCheckpoint();

        dividendSnapshots.push(
            DividendSnapshots(
                tokenCheckpointId,
                new uint256[](distributionTokens.length)
            )
        );

        for (uint256 i = 0; i < distributionTokens.length; i++) {
            dividendSnapshots[dividendSnapshots.length - 1].values[i] =
                totalDividendsClaimed[i] +
                ERC20(distributionTokens[i]).balanceOf(address(this));
        }

        emit DividendCreate(currentId, tokenCheckpointId);

        return (tokenCheckpointId, currentId);
    }

    /**
     * @dev Returns the current dividend id
     */
    function getCurrentDividendId() public view returns (uint256) {
        return _currentDividendId.current();
    }

    /**
     * @dev Allows a shareholder to claim their tokens
     * @param _dividendId The id of the dividend to claim
     */
    function claimDividend(uint256 _dividendId) external {
        require(
            !tokensClaimed[_dividendId][msg.sender],
            "Vault: Already claimed"
        );
        _payDividend(msg.sender, _dividendId);
    }

    /**
     * @dev Calculates the amount of dividends a shareholder is entitled to and
     * transfers it to them. If the shareholder has already claimed their
     * dividend, this function will revert. Non-shareholders will be transferred
     * 0 tokens. Their transactions will NOT revert.
     * @param _shareholder The address of the shareholder to pay.
     * @param _dividendId The id of the dividend to pay.
     */
    function _payDividend(address _shareholder, uint256 _dividendId) internal {
        require(
            _dividendId > 0 && _dividendId <= dividendSnapshots.length,
            "Vault: Invalid dividend index"
        );
        uint256 index = _dividendId - 1;

        uint256 snapshotBalance = claimToken.balanceOfAt(
            _shareholder,
            dividendSnapshots[index].claimCheckpoint
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

    /**
     * @dev Public function to calculate the claim amount of one of the tokens
     * for a shareholder
     * @param _shareholder The address of the shareholder
     * @param _dividendId The index of the dividend
     * @param tokenIndex The index of the token
     */
    function calculateClaim(
        address _shareholder,
        uint256 _dividendId,
        uint256 tokenIndex
    ) external view returns (uint256) {
        require(
            _dividendId > 0 && _dividendId <= dividendSnapshots.length,
            "Vault: Invalid dividend index"
        );
        if (tokensClaimed[_dividendId][_shareholder]) return 0;

        uint256 index = _dividendId - 1;

        uint256 snapshotBalance = claimToken.balanceOfAt(
            _shareholder,
            dividendSnapshots[index].claimCheckpoint
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

    /**
     * @dev Helper function to calculate the claim amount
     * @param snapshotBalance Shareholder's balance of the `claimToken` at the
     * checkpoint
     * @param snapshotTotalSupply The total supply of the `claimToken` at the
     * checkpoint
     * @param _dividendId The dividend id
     * @param tokenIndex The index of the token in the `distributionTokens`
     * array
     */
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

    /**
     * @dev Returns the total amount of dividends allocated for a given
     * dividendId and tokenIndex. This function performs the required
     * calculations to determine the allocation amount. To find the amount at
     * given `dividendId` you have to find (the total amount at the provided
     * `dividendId` - the total amount at the previous `dividendId`). If the
     * function is called on the current `dividendId` (not yet snapshotted) then
     * the calculation is done on how much has been allocated for it so far.
     * @param _dividendId associated dividendId
     * @param tokenIndex The index of the token
     */
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

    /**
     * @dev Returns the value associated with a given dividendId and tokenIndex.
     * Values within one `dividendSnapshots` represent the different allocation
     * amounts for each token for that dividend. Values across multuple
     * `dividendSnapshots` represent the history of the total amount of
     * dividends allocated for a given token with the assumption there were no
     * claims ever made. This function simply reads the state of the contract.
     * @param _dividendId associated dividendId
     * @param tokenIndex The index of the token
     */
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

        if (index == dividendSnapshots.length) return (false, 0);

        return (true, dividendSnapshots[index].values[tokenIndex]);
    }
}
