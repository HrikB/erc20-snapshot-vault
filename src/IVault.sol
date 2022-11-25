// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IVault {
    event ShareholderClaim(
        address indexed shareholder,
        uint256 indexed dividendIndex,
        address indexed token,
        uint256 amount
    );

    function createDividend() external returns (uint256, uint256);

    function claimDividend(uint256 _dividendIndex) external;

    function calculateDividend(uint256 _dividendIndex, address _shareholder)
        external
        view
        returns (uint256[] memory);
}
