// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IVault {
    event DividendCreate(
        uint256 indexed dividendId,
        uint256 indexed checkpointId
    );
    event ShareholderClaim(
        address indexed shareholder,
        uint256 indexed dividendId,
        address indexed token,
        uint256 amount
    );

    function createDividend() external returns (uint256, uint256);

    function getCurrentDividendId() external view returns (uint256);

    function claimDividend(uint256 _dividendId) external;

    function calculateClaim(
        address _shareholder,
        uint256 _dividendId,
        uint256 tokenIndex
    ) external view returns (uint256);

    function dividendAmountAt(uint256 _dividendId, uint256 tokenIndex)
        external
        view
        returns (uint256);
}
