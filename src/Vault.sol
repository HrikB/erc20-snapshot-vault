// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ClaimToken} from "./ClaimToken.sol";
import {Dividend} from "./VaultLib.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Vault is AccessControl {
    event DividendDeposit(
        uint256 indexed checkpointId,
        uint256 indexed dividendIndex,
        address indexed token,
        uint256 amount,
        uint256 expiry
    );
    event ShareholderClaim(
        address indexed shareholder,
        uint256 indexed dividendIndex,
        address indexed token,
        uint256 amount
    );

    ClaimToken claimToken;

    Dividend[] public dividends;

    mapping(uint256 => address) public dividendTokens;
    // CheckpointId => Shareholder address => claim bool
    mapping(uint256 => mapping(address => bool)) public tokensClaimed;

    bytes32 internal constant DIVIDEND_ROLE = keccak256("DIVIDEND_ROLE");

    constructor(ClaimToken _claimToken) {
        claimToken = _claimToken;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(DIVIDEND_ROLE, msg.sender);
    }

    function grantDividend(address _newAddress)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _grantRole(DIVIDEND_ROLE, _newAddress);
    }

    function createDividend(
        uint256 _expiry,
        address _token,
        uint256 _amount
    ) public onlyRole(DIVIDEND_ROLE) returns (uint256, uint256) {
        uint256 checkpointId = claimToken.createCheckpoint();
        uint256 dividendIndex = _createDividend(
            checkpointId,
            _expiry,
            _token,
            _amount
        );
        return (checkpointId, dividendIndex);
    }

    function _createDividend(
        uint256 _checkpointId,
        uint256 _expiry,
        address _token,
        uint256 _amount
    ) internal returns (uint256) {
        require(
            _expiry > block.timestamp,
            "Vault: Expiry must be in the future"
        );
        require(_amount > 0, "Vault: Amount must be greater than 0");
        require(_token != address(0), "Vault: Token must be valid address");
        require(
            _checkpointId <= claimToken.getCurrentCheckpointId(),
            "Vault: Checkpoint must be valid"
        );

        // Transfer total dividend value to vault for distribution
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);

        uint256 dividendIndex = dividends.length;

        dividends.push(
            Dividend(_checkpointId, block.timestamp, _expiry, _amount, 0, false)
        );
        dividendTokens[dividendIndex] = _token;

        emit DividendDeposit(
            _checkpointId,
            dividendIndex,
            _token,
            _amount,
            _expiry
        );

        return dividendIndex;
    }

    function claimDividend(uint256 _dividendIndex) public {
        require(
            _dividendIndex < dividends.length,
            "Vault: Invalid dividend index"
        );
        require(
            !dividends[_dividendIndex].reclaimed,
            "Vault: Dividend already reclaimed"
        );
        require(
            block.timestamp < dividends[_dividendIndex].expiry,
            "Vault: Dividend expired"
        );

        Dividend storage dividend = dividends[_dividendIndex];
        require(
            !tokensClaimed[dividend.checkpointId][msg.sender],
            "Vault: Already claimed"
        );
        _payDividend(msg.sender, dividend, _dividendIndex);
    }

    function reclaimDividend(uint256 _dividendIndex)
        external
        onlyRole(DIVIDEND_ROLE)
    {
        require(
            _dividendIndex < dividends.length,
            "Vault: Invalid dividend index"
        );
        require(
            block.timestamp >= dividends[_dividendIndex].expiry,
            "Vault: Dividend not expired"
        );
        require(
            !dividends[_dividendIndex].reclaimed,
            "Vault: Dividend already reclaimed"
        );
        Dividend storage dividend = dividends[_dividendIndex];
        dividend.reclaimed = true;
        uint256 remainingAmount = dividend.amount - dividend.claimedAmount;

        IERC20(dividendTokens[_dividendIndex]).transfer(
            msg.sender,
            remainingAmount
        );
    }

    function _payDividend(
        address _shareholder,
        Dividend storage _dividend,
        uint256 _dividendIndex
    ) internal {
        uint256 claim = calculateDividend(_dividendIndex, _shareholder);
        tokensClaimed[_dividend.checkpointId][_shareholder] = true;
        _dividend.claimedAmount = claim + _dividend.claimedAmount;

        IERC20(dividendTokens[_dividendIndex]).transfer(_shareholder, claim);

        emit ShareholderClaim(
            _shareholder,
            _dividendIndex,
            dividendTokens[_dividendIndex],
            claim
        );
    }

    function calculateDividend(uint256 _dividendIndex, address _shareholder)
        public
        view
        returns (uint256)
    {
        require(
            _dividendIndex < dividends.length,
            "Vault: Invalid dividend index"
        );

        Dividend storage dividend = dividends[_dividendIndex];
        if (tokensClaimed[dividend.checkpointId][_shareholder]) return 0;

        uint256 snapshotBalance = claimToken.balanceOfAt(
            _shareholder,
            dividend.checkpointId
        );
        // Potentially storing this value in Dividend struct could save gas
        uint256 snapshotTotalSupply = claimToken.totalSupplyAt(
            dividend.checkpointId
        );
        uint256 claimBalance = (snapshotBalance * dividend.amount) /
            snapshotTotalSupply;

        return claimBalance;
    }
}
