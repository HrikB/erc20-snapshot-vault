// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20Snapshot, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Checkpoint} from "./ClaimTokenLib.sol";

contract ClaimToken is ERC20Snapshot, Ownable {
    mapping(address => Checkpoint[]) public checkpointBalances;

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function createCheckpoint() external onlyOwner returns (uint256) {
        return _snapshot();
    }

    function getCurrentCheckpointId() external returns (uint256) {
        return _getCurrentSnapshotId();
    }
}
