# `ClaimToken.sol`

This is the ERC-20 compatible token that represents a holder's claim to a share of the Vault's distribution. It uses OpenZeppelin's `ERC20Snapshot` internally to keep track of historical token balances at certain points in time.

# `Vault.sol`

This is the contract in which the distributions are stored. It also stores interally an address of a deployed `ClaimToken.sol` whose proportional balances of the token supply will represent the proportional right to claim distributions from the Vault.

## Dividend Creation

When a dividend is created a in the Vault, the full distribution is transferred into the contract. Also, a snapshot within the `ClaimToken.sol` is created and mapped to recent dividend.

## Dividend Claiming

Dividends will need to be claimed by the appropriate shareholder. If someone is not a shareholder, their transaction won't be rejected, but rather it will simply send an amount of 0 of the distribution token to `msg.sender`. The creator of the dividend can create an `expiry` period after which shareholders attempting to claim that specific dividend will be denied.

## Dividend Reclaiming

This is only for expired dividends. Once a dividend has expired, `DIVIDEND_ROLE` has the ability to reclaim whatever is left of the distribution. Enabling expiry/reclaiming into the spec allows for flexibility around unclaimed funds. It is highly likely that not all of the funds from the distribution will be claimed by the appropriate shareholders. It is futile not to unlock that liquidity to `DIVIDEND_ROLE`.

# Permissions

One address with `DIVIDEND_ROLE` has the permission to create a dividend and reclaim dividend after the expiry. Either an EOA can call the `createDividend()` function or it can be called by a contract.
