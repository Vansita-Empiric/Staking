// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.2 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "hardhat/console.sol";

contract Staking is ReentrancyGuard {
    IERC20 public s_stakingToken;

    enum Category {
        Bronze,
        Silver,
        Gold
    }

    struct StakeInfo {
        uint256 amount;
        uint256 startTime;
        Category category;
    }

    uint256 constant FEE_PERCENTAGE = 2;
    uint256 constant PENALTY_PERCENTAGE = 10;

    uint256 constant LOW_TIME_DURATION = 15;
    uint256 constant MEDIUM_TIME_DURATION = 20;
    uint256 constant HIGH_TIME_DURATION = 25;

    uint256 constant LOW_DURATION_PERCENTAGE = 5;
    uint256 constant MEDIUM_DURATION_PERCENTAGE = 10;
    uint256 constant HIGH_DURATION_PERCENTAGE = 15;

    address owner;

    mapping(address => StakeInfo) stakers;

    constructor(address _stakingTokenAddress) {
        s_stakingToken = IERC20(_stakingTokenAddress);
        owner = msg.sender;
    }

    function stake(uint256 _amount, Category _category) public nonReentrant {
        require(msg.sender != owner, "Owner can not participate in staking");
        require(
            _category == Category.Bronze && _amount < 1000,
            "Stake amount should be minimum 1000 in Bronze"
        );
        require(
            _category == Category.Silver && _amount < 5000,
            "Stake amount should be minimum 5000 in Silver"
        );
        require(
            _category == Category.Gold && _amount < 10000,
            "Stake amount should be minimum 10000 in Gold"
        );

        // 2% fees calculation for owner
        uint256 fee = (_amount * FEE_PERCENTAGE) / 100;

        // Calculating actual amount of stake after deducting fees for owner
        uint256 stakingAmountAfterFee = _amount - fee;

        // Assigning actual amount of stake
        // Storing informatin in mapping
        StakeInfo memory stakeInfoInstance = StakeInfo(
            stakingAmountAfterFee,
            block.timestamp,
            _category
        );
        stakers[msg.sender] = stakeInfoInstance;

        // Transfering actual staking amount to contract
        bool success = s_stakingToken.transferFrom(
            msg.sender,
            address(this),
            stakingAmountAfterFee
        );
        require(success, "Token transfer failed");

        // Transfering fee to owner
        bool feeTransfer = s_stakingToken.transfer(owner, fee);
        require(feeTransfer, "Fee transfer failed");
    }

    function withdrawal() public nonReentrant {
        // Retriving all info of stake
        StakeInfo storage stakeInfoInstance = stakers[msg.sender];
        require(stakeInfoInstance.amount > 0, "You haven't staked any token");

        // Calculating stake ending time
        uint256 endTime = block.timestamp - stakeInfoInstance.startTime;
        uint256 reward = 0;

        // Checking category wise minumum stake ending time
        if (
            endTime >= LOW_TIME_DURATION && 
            (endTime < MEDIUM_TIME_DURATION && endTime < HIGH_TIME_DURATION) 
        ) {
            reward =
                (stakeInfoInstance.amount * LOW_DURATION_PERCENTAGE * endTime) /
                100; // Calculating 5% reward for ending time
        } else if (
            endTime < HIGH_TIME_DURATION && endTime >= MEDIUM_TIME_DURATION
        ) {
            reward =
                (stakeInfoInstance.amount *
                    MEDIUM_DURATION_PERCENTAGE *
                    endTime) /
                100; // Calculating 10% reward for ending time
        } else if (endTime >= HIGH_TIME_DURATION) {
            reward =
                (stakeInfoInstance.amount *
                    HIGH_DURATION_PERCENTAGE *
                    endTime) /
                100; // Calculating 15% reward for end time
        } else {
            // Calculating penalty for ending stake before time
            uint256 penalty = (stakeInfoInstance.amount * PENALTY_PERCENTAGE) /
                100;
            stakers[msg.sender].amount -= penalty;

            // Transfering penalty amount to contract
            bool penaltyTransfer = s_stakingToken.transfer(owner, penalty);
            require(penaltyTransfer, "Penalty transfer failed");
        }

        // Transfering actual staking amount to staker
        bool success = s_stakingToken.transfer(
            msg.sender,
            stakeInfoInstance.amount
        );
        require(success, "Staked amount transfer failed");

        // Transfering reward amount to staker
        if (reward > 0) {
            require(
                s_stakingToken.balanceOf(owner) >= reward,
                "Insufficient reward balance"
            );
            bool rewardTransfer = s_stakingToken.transferFrom(
                owner,
                msg.sender,
                reward
            );
            require(rewardTransfer, "Reward transfer failed");
        }

        // Clearing stakers' info
        delete stakers[msg.sender];
    }
}
