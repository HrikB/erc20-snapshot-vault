// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IVault {
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

    function grantDividend(address _newAddress) external;

    function createDividend(
        uint256 _expiry,
        address _token,
        uint256 _amount
    ) external returns (uint256, uint256);

    function claimDividend(uint256 _dividendIndex) external;

    function reclaimDividend(uint256 _dividendIndex) external;

    function calculateDividend(uint256 _dividendIndex, address _shareholder)
        external
        view
        returns (uint256);
}
