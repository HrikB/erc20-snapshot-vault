// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";

library RateLimit {
    function rateLimit(
        StorageSlot.Uint256Slot storage lastTime,
        StorageSlot.Uint256Slot storage _rateLimit
    ) internal {
        require(
            block.timestamp - lastTime.value > _rateLimit.value,
            "Vault: Rate limit exceeded"
        );
        lastTime.value = block.timestamp;
    }
}
