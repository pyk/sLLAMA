// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "@openzeppelin/token/ERC721/ERC721.sol";
import {ERC721Holder} from "@openzeppelin/token/ERC721/utils/ERC721Holder.sol";
import {Ownable, Ownable2Step} from "@openzeppelin/access/Ownable2Step.sol";
import {Math} from "@openzeppelin/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/utils/math/SafeCast.sol";

/**
 * @title Llama Locker
 * @author sepyke.eth
 * @dev Lock LLAMA to claim share of the yield generated by the treasury
 */
contract LlamaLocker is ERC721Holder, Ownable2Step {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;
    using Math for uint256;

    //************************************************************//
    //                 Storage for Reward Tokens                  //
    //************************************************************//

    // TODO(pyk): explain these fields
    struct RewardState {
        uint48 periodEndAt;
        uint208 rewardPerSecond;
        uint48 updatedAt;
        uint208 rewardPerNFTStored;
    }

    IERC20[] public rewardTokens;
    mapping(IERC20 => RewardState) private rewardStates;

    IERC721 public nft;
    mapping(uint256 tokenId => address owner) private nftOwners;
    uint256 public constant REWARD_DURATION = 7 days;
    uint256 public totalLockedNFT;

    error RenounceInvalid();
    error RewardTokenExists();
    error RewardTokenNotExists();
    error RewardAmountInvalid();
    error LockZeroToken();
    error UnlockOwnerInvalid();
    error NoLockers();

    event RewardTokenAdded(IERC20 token);
    event RewardDistributed(IERC20 token, uint256 amount);

    constructor(address owner_, address nft_) Ownable(owner_) {
        nft = IERC721(nft_);
    }

    /// @dev This contract ain't gonna work without its owner, ya know?
    function renounceOwnership() public virtual override onlyOwner {
        revert RenounceInvalid();
    }

    //************************************************************//
    //                    Reward Token Manager                    //
    //************************************************************//

    function getRewardTokenCount() external view returns (uint256 count_) {
        count_ = rewardTokens.length;
    }

    function getRewardState(IERC20 token_) external view returns (RewardState memory data_) {
        data_ = rewardStates[token_];
    }

    /// @notice Add new reward token
    /// @param _token New reward token address
    function addRewardToken(IERC20 _token) external onlyOwner {
        if (rewardStates[_token].updatedAt > 0) revert RewardTokenExists();

        rewardTokens.push(_token);
        rewardStates[_token].updatedAt = block.timestamp.toUint48();
        rewardStates[_token].periodEndAt = block.timestamp.toUint48();

        emit RewardTokenAdded(_token);
    }

    /// @dev Calc ulate reward per locked NFT
    function _rewardPerNFT(IERC20 _token) internal view returns (uint256 amount) {
        RewardState memory rewardState = rewardStates[_token];
        uint256 prevRewardPerNFT = uint256(rewardState.rewardPerNFTStored);
        uint256 periodEndAt = Math.min(uint256(rewardState.periodEndAt), block.timestamp);
        uint256 timeDelta = periodEndAt - uint256(rewardState.updatedAt);
        uint256 rewardPerNFT = (timeDelta * rewardState.rewardPerSecond) / totalLockedNFT;
        return prevRewardPerNFT + rewardPerNFT;
    }

    /// @dev Update reward states
    function _updateRewardStates() internal {
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            IERC20 token = rewardTokens[i];
            rewardStates[token].rewardPerNFTStored = _rewardPerNFT(token).toUint208();
            rewardStates[token].updatedAt = Math.min(rewardStates[token].periodEndAt, block.timestamp).toUint48();
        }
    }

    /// @notice Distribute rewards to lockers
    /// @param _token The reward token address
    /// @param _amount The amount of reward token
    function distribute(IERC20 _token, uint256 _amount) external onlyOwner {
        if (rewardStates[_token].updatedAt == 0) revert RewardTokenNotExists();
        if (_amount == 0) revert RewardAmountInvalid();
        if (totalLockedNFT == 0) revert NoLockers();

        _updateRewardStates();

        RewardState storage rewardState = rewardStates[_token];
        if (block.timestamp >= rewardState.periodEndAt) {
            rewardState.rewardPerSecond = (_amount / REWARD_DURATION).toUint208();
        } else {
            uint256 remaining = rewardState.periodEndAt - block.timestamp;
            uint256 leftover = remaining * rewardState.rewardPerSecond;
            rewardState.rewardPerSecond = ((_amount + leftover) / REWARD_DURATION).toUint208();
        }

        rewardState.updatedAt = block.timestamp.toUint48();
        rewardState.periodEndAt = (block.timestamp + REWARD_DURATION).toUint48();

        _token.safeTransferFrom(msg.sender, address(this), _amount);
        emit RewardDistributed(_token, _amount);
    }

    function lock(uint256[] calldata tokenIds_) external {
        uint256 tokenCount = tokenIds_.length;
        if (tokenCount == 0) revert LockZeroToken();
        for (uint256 i = 0; i < tokenCount; ++i) {
            nft.safeTransferFrom(msg.sender, address(this), tokenIds_[i]);
            nftOwners[tokenIds_[i]] = msg.sender;
        }

        // Increase total locked NFT
        totalLockedNFT += tokenCount;
    }

    function unlock(uint256[] calldata tokenIds_) external {
        uint256 tokenCount = tokenIds_.length;
        if (tokenCount == 0) revert LockZeroToken();

        // Decrease total locked NFT
        totalLockedNFT -= tokenCount;

        for (uint256 i = 0; i < tokenCount; ++i) {
            if (nftOwners[tokenIds_[i]] != msg.sender) revert UnlockOwnerInvalid();
            nft.safeTransferFrom(address(this), msg.sender, tokenIds_[i]);
        }
    }
}
