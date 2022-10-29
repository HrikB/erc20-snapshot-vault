// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

struct Dividend {
    uint256 checkpointId;
    // Time at which the dividend was created
    uint256 created;
    // Time until which dividend can be claimed - after this
    // time any remaining amount can be withdrawn by issuer -
    // set to very high value to bypass
    uint256 expiry;
    // Total amount of dividend to be distributed to shareholders
    uint256 amount;
    // Amount of dividend claimed so far
    uint256 claimedAmount;
    // Total supply at the associated checkpoint (avoids recalculating this)
    bool reclaimed;
}
