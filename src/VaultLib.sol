// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

struct DividendSnapshots {
    uint256[] ids;
    uint256[] checkpoints;
    uint256[][] values;
}
