// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {Ownable, Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

/**
 * @title Llama Locker
 * @author sepyke.eth
 * @dev Lock LLAMA to claim share of the yield generated by the treasury
 */
contract LlamaLocker is ERC721Holder, Ownable2Step {
  using SafeERC20 for IERC20;
  using SafeCast for uint256;

  using Math for uint256;

  struct RewardState {
    uint32 endAt;
    uint32 updatedAt;
    uint256 rewardPerSecond;
    uint256 rewardPerTokenStored;
  }

  IERC20[] public rewardTokens;
  IERC721 public nft;
  mapping(IERC20 => RewardState) private rewardStates;
  mapping(uint256 tokenId => address owner) private nftOwners;
  uint256 public constant REWARD_DURATION = 7 days;

  error RenounceInvalid();
  error RewardTokenExists();
  error RewardTokenInvalid();
  error RewardAmountInvalid();
  error LockZeroToken();
  error UnlockOwnerInvalid();

  event RewardTokenAdded(IERC20 rewardToken);
  event RewardAdded(IERC20 rewardToken, uint256 rewardAmount);

  constructor(address owner_, address nft_) Ownable(owner_) {
    nft = IERC721(nft_);
  }

  /// @dev This contract ain't gonna work without its owner, ya know?
  function renounceOwnership() public virtual override onlyOwner {
    revert RenounceInvalid();
  }

  /**************************************************************/
  //                    Reward Token Manager                    //
  /**************************************************************/

  function getRewardTokenCount() external view returns (uint256 count_) {
    count_ = rewardTokens.length;
  }

  function getRewardState(IERC20 rewardToken_) external view returns (RewardState memory data_) {
    data_ = rewardStates[rewardToken_];
  }

  function addRewardToken(IERC20 token_) external onlyOwner {
    if (address(token_) == address(0)) revert RewardTokenInvalid();
    if (rewardStates[token_].updatedAt > 0) revert RewardTokenExists();

    rewardTokens.push(token_);
    rewardStates[token_].updatedAt = block.timestamp.toUint32();
    rewardStates[token_].endAt = block.timestamp.toUint32();

    emit RewardTokenAdded(token_);
  }

  // /// @notice Owner can add reward on weekly basis (vlCVX styles)
  // function addReward(IERC20 rewardToken_, uint256 amount_) external onlyOwner {
  //   if (amount_ == 0) revert RewardAmountInvalid();
  //   if (rewardStates[IERC20(rewardToken_)].lastUpdatedAt == 0) revert RewardTokenInvalid();

  //   RewardState storage data = rewardStates[rewardToken_];
  //   if (block.timestamp >= data.periodFinish) {
  //     data.rewardPerSecond = amount_ / REWARD_DURATION;
  //   } else {
  //     uint256 remainingSeconds = data.periodFinish - block.timestamp;
  //     uint256 leftoverAmount = remainingSeconds * data.rewardPerSecond;
  //     data.rewardPerSecond = (amount_ + leftoverAmount) / REWARD_DURATION;
  //   }
  //   data.lastUpdatedAt = block.timestamp;
  //   data.periodFinish = block.timestamp + REWARD_DURATION;

  //   rewardToken_.safeTransferFrom(msg.sender, address(this), amount_);
  //   emit RewardAdded(rewardToken_, amount_);
  // }

  function lock(uint256[] calldata tokenIds_) external {
    uint256 tokenCount = tokenIds_.length;
    if (tokenCount == 0) revert LockZeroToken();
    for (uint256 i = 0; i < tokenCount; ++i) {
      nft.safeTransferFrom(msg.sender, address(this), tokenIds_[i]);
      nftOwners[tokenIds_[i]] = msg.sender;
    }
  }

  function unlock(uint256[] calldata tokenIds_) external {
    uint256 tokenCount = tokenIds_.length;
    if (tokenCount == 0) revert LockZeroToken();
    for (uint256 i = 0; i < tokenCount; ++i) {
      if (nftOwners[tokenIds_[i]] != msg.sender) revert UnlockOwnerInvalid();
      nft.safeTransferFrom(address(this), msg.sender, tokenIds_[i]);
    }
  }
}
