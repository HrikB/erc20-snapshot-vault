// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/console.sol";

import {ERC20Snapshot, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Checkpoint} from "./ClaimTokenLib.sol";
import {IClaimToken} from "./IClaimToken.sol";

contract ClaimToken is ERC20Snapshot, AccessControl, IClaimToken {
    bytes32 internal constant CHECKPOINT_ROLE = keccak256("CHECKPOINT_ROLE");
    bytes32 internal constant MINTER_ROLE = keccak256("MINTER_ROLE");

    mapping(address => Checkpoint[]) public checkpointBalances;

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(CHECKPOINT_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }

    function grantCheckpoint(address _newAddress)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _grantRole(CHECKPOINT_ROLE, _newAddress);
    }

    function createCheckpoint()
        external
        onlyRole(CHECKPOINT_ROLE)
        returns (uint256)
    {
        return _snapshot();
    }

    function getCurrentCheckpointId() external returns (uint256) {
        return _getCurrentSnapshotId();
    }

    function mint(address _to, uint256 _amount) external onlyRole(MINTER_ROLE) {
        _mint(_to, _amount);
    }
}
