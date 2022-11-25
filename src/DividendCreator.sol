// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./Vault.sol";

contract DividendCreator {
    address public vault;

    uint256 rateLimit;
    uint256 lastTime;

    constructor(Vault _vault, uint256 _rateLimit) {
        // vault = _vault;
        rateLimit = _rateLimit;
    }

    function tryCreateDividend() external {
        require(
            block.timestamp - lastTime > rateLimit,
            "DividendCreator: Rate limit exceeded"
        );
        lastTime = block.timestamp;
        // vault.createDividend();
    }
}
