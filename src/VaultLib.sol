// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

struct DividendSnapshots {
    uint256 claimCheckpoint;
    uint256[] values;
}
