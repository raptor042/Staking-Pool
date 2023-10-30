// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Pool {
    IERC20 public Token;

    address public Creator;

    uint256 public PoolTime;

    uint256 public PoolDuration;

    uint256 public RewardsBalance;

    uint256 public TotalStaked;

    struct Stake {
        address user;
        uint256 amount;
        uint256 locktime;
        uint256 lockduration;
        uint256 lock_ratio;
        uint256 stake_ratio;
        uint256 reward_ratio;
    }

    Stake[] public stakes;

    mapping (address => Stake) public _stakes;

    event Staked(address indexed _user, uint256 amount);

    event Withdrawal(address indexed _user, uint256 amount);

    constructor(address _token, address creator, uint256 duration, uint256 rewards) {
        Token = IERC20(_token);

        require(Token.transferFrom(msg.sender, address(this), rewards), "Transfer of token rewards for staking failed.");

        Creator = creator;

        PoolTime = block.timestamp;

        PoolDuration = duration;

        TotalStaked = 0;

        RewardsBalance = rewards;
    }

    modifier onlyCreator {
        require(msg.sender == Creator, "Only the creator of this pool can call this function.");
        _;
    }

    function staking(uint256 _amount, uint256 duration) public payable {
        require(_amount > 0, "Not enough tokens required for staking.");

        require(duration > PoolDuration, "You cannot stake beyond the duration of the Pool.");

        require(Token.transferFrom(msg.sender, address(this), _amount), "Transfer of tokens for staking failed.");

        TotalStaked += _amount;

        uint256 poolTimeElapsed = (block.timestamp - PoolTime) / 86400;

        uint256 poolTimeLeft = PoolDuration - poolTimeElapsed;
        
        Stake memory stake = Stake({
            user : msg.sender,
            amount : _amount,
            locktime : block.timestamp,
            lockduration : duration,
            lock_ratio : duration / poolTimeLeft,
            stake_ratio : _amount / TotalStaked,
            reward_ratio : (duration / poolTimeLeft) * (_amount / TotalStaked)
        });

        stakes.push(stake);

        _stakes[msg.sender] = stake;

        emit Staked(msg.sender, _amount);
    }

    function possibleWithdrawals() internal view returns (uint256) {
        uint256 count = 0;

        for(uint256 i = 0; i < stakes.length; i++) {
            Stake storage _stake = stakes[i];

            uint256 timeElapsed = (block.timestamp - _stake.locktime) / 86400;

            if(timeElapsed >= _stake.lockduration) {
                count += 1;
            }
        }

        return count;
    }

    function calculateStakingYield() public view returns (uint256, uint256, uint256, uint256) {
        Stake storage stake01 = _stakes[msg.sender];

        uint256 poolTimeElapsed = (block.timestamp - PoolTime) / 86400;

        uint256 poolTimeLeft = PoolDuration - poolTimeElapsed;

        uint256 maxRewardsPerDay = RewardsBalance / poolTimeLeft;

        uint256 withdrawals = possibleWithdrawals();

        uint256 maxRewardsPerUser = maxRewardsPerDay / withdrawals;

        uint256 amountStaked = stake01.amount;

        uint256 accumulated = stake01.reward_ratio * RewardsBalance;

        return (accumulated, amountStaked, maxRewardsPerUser, maxRewardsPerDay);
    }

    function withdrawal() public payable {
        Stake storage stake02 = _stakes[msg.sender];

        uint256 timeElapsed = (block.timestamp - stake02.locktime) / 86400;

        require(timeElapsed >= stake02.lockduration, "Withdrawal is not available at this time.");

        (uint256 yield, , , ) = calculateStakingYield();

        require(Token.transferFrom(address(this), msg.sender, yield), "Transfer of tokens from staking yield failed.");

        emit Withdrawal(msg.sender, yield);
    }

    function earlyWithdrawal() public payable {
        Stake storage stake03 = _stakes[msg.sender];

        uint256 stakeTimeElapsed = (block.timestamp - stake03.locktime) / 86400;

        uint256 stakeTimeLeft = stake03.lockduration - stakeTimeElapsed;

        (uint256 yield, , , ) = calculateStakingYield();

        uint256 amount = yield / stakeTimeLeft;

        require(Token.transferFrom(address(this), msg.sender, amount), "Transfer of tokens from staking yield failed.");

        emit Withdrawal(msg.sender, yield);
    }

    function changePoolTime(uint256 time) onlyCreator public {
        PoolTime = time;
    }

    function changePoolDuration(uint256 duration) onlyCreator public {
        PoolDuration = duration;
    }

    function increaseRewardsBalance(uint256 _amount) onlyCreator public {
        require(Token.transferFrom(msg.sender, address(this), _amount), "Transfer of token rewards for staking failed.");
        
        RewardsBalance += _amount;
    }
}