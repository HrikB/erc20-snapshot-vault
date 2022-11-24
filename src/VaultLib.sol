// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

struct Dividend {
    uint256 checkpointId;
    // Time at which the dividend was created
    uint256 created;
    // Total amount of dividend to be distributed to shareholders
    uint256 amount;
    // Amount of dividend claimed so far
    uint256 claimedAmount;
}
