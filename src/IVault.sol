// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IVault {
    event ShareholderClaim(
        address indexed shareholder,
        uint256 indexed dividendId,
        address indexed token,
        uint256 amount
    );

    function createDividend() external returns (uint256, uint256);

    function claimDividend(uint256 _dividendId) external;

    function dividendAmountsAt(uint256 _dividendId)
        external
        view
        returns (uint256[] memory);

    function calculateDividend(uint256 _dividendId, address _shareholder)
        external
        view
        returns (uint256[] memory);
}
