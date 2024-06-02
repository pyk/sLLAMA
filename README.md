# Llama Locker

Llama Locker allows users to lock their LLAMA tokens and earn a share of the
yield generated by the treasury over time. It manages epochs, reward token
distribution, and token locking/unlocking, ensuring fair and transparent reward
distribution.

## Lock Mechanism

- Locked NFTs cannot be withdrawn for 4 epochs (4 weeks) and are eligible to
  receive a proportionate share of yields during this period.
- Unlike the CVX Lock style, which requires active kicking out of tokens after
  the lock duration ends, LlamaLocker offers a more user-friendly approach.
- NFT owners can withdraw their NFTs in the epoch after the lock duration ends.
  If not withdrawn, the NFTs will automatically re-lock for the subsequent lock
  duration, streamlining the process and saving users on gas costs.

### Example of Lock Mechanism

1. Alice locks Llama #1 on January 28, 2024, at 22:49:42 GMT.
2. Llama #1 starts accruing yields from February 1, 2024, at 00:00:00 GMT (next epoch).
3. Withdrawal of Llama #1 is possible anytime from February 29, 2024, at 00:00:00 GMT to March 7, 2024, at 00:00:00 GMT (one-week epoch).
4. If Llama #1 remains unwithdrawn during this window, it will automatically re-lock starting March 7, 2024, at 00:00:00 GMT.

## Getting Started

Ensure you are using the latest version of Foundry:

```shell
foundryup
```

Install dependencies:

```shell
forge install
```

Run the tests:

```shell
forge test --rpc-url https://ethereum.publicnode.com
```

## Front End Integration

There are two main actions for users:

1. **Lock NFT:** Users can lock their NFT via `lock`.
2. **Unlock NFT:** Users can unlock their NFT via `unlock`.

Additional information:

- Claimable rewards are available via `claimables(account)`.
- Claimed rewards are available via `getClaimedRewards(account)`.
- Lock information can be retrieved via `locks(nftId)`.

To compute the next unlock for the specified NFT, use the following formula:

```shell
lockedDuration = currentTimestamp - lockedAt
lockedDurationInEpoch = lockedDuration / EPOCH_DURATION
modulo = lockedDurationInEpoch % LOCK_DURATION_IN_EPOCH
unlockNextEpoch = LOCK_DURATION_IN_EPOCH - modulo
unlockStart = currentTimestamp + (unlockNextEpoch * EPOCH_DURATION)
unlockEnd = unlockStart + EPOCH_DURATION
```

`unlockStart` and `unlockEnd` define a time window in Unix timestamp when users can unlock their locked NFTs.

## Admin Chores

- Admins can add a new reward token via `addRewardToken`.
- Admins can distribute weekly rewards via `distributeRewardToken`.
- Admins need to approve the LlamaLocker contract before executing `distributeRewardToken`.
