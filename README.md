# `ClaimToken.sol`

This is the ERC-20 compatible token that represents a holder's claim to a share of the Vault's distribution. It uses OpenZeppelin's `ERC20Snapshot` internally to keep track of historical token balances at certain points in time.

# `Vault.sol`

This is the contract in which the distributions are stored. It also stores internally an address of a deployed `ClaimToken.sol` whose proportional balances of the token supply will represent the proportional right to claim distributions from the Vault. The vault supports distribution of multiple tokens that must be designated at *deploy-time*. This is unalterable once the contract has been launched. 

## Dividend Creation

When a dividend is created in the Vault (by calling `createDividend()`), a snapshot of the `Vault`'s token supplies (designated at contract deployment) and the `ClaimToken`'s balances are taken. With this data, each shareholder's rightful share can be calculated when said shareholder goes to make a claim.

## Dividend Claiming

Dividends will need to be claimed by the appropriate shareholder. If someone is not a shareholder, their transaction won't be reverted, but rather it will simply send an amount of 0 tokens of the distribution token(s) to `msg.sender`. Shareholders must claim their rightful share for each dividend individually. Each dividend's full value will be distributed at once. There is no option to make a partial claim of one dividend.

## Permissions

The Vault has no special privledging. However, the `createDividend()` function is rate-limited to prevent spamming as OpenZeppelin's `ERC20Snapshot` does incur an overhead as snapshot total grows (although its growth is logarthmic).

# `RateLimiter.sol`
A general-purpose library that can be used create a rate limiter. It takes two storage pointers (supported by OpenZeppelin's `StorageSlot.sol`) so that it can read/write to the consuming contract's storage.
