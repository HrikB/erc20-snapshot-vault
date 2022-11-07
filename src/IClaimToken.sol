// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IClaimToken {
    function grantCheckpoint(address _newAddress) external;

    function createCheckpoint() external returns (uint256);

    function getCurrentCheckpointId() external returns (uint256);

    function mint(address _to, uint256 _amount) external;
}
