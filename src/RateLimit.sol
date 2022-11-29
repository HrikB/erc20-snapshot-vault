// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

library RateLimit {
    modifier rateLimit(uint256 lastTime, uint256 _rateLimit) {
        require(
            block.timestamp - lastTime > _rateLimit,
            "Vault: Rate limit exceeded"
        );
        lastTime = block.timestamp;
        _;
    }
}
