// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

interface IERC20 {
    function decimals() external view returns (uint8);

    function symbol() external view returns (string memory);

    function name() external view returns (string memory);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract Pool {
    enum Status {
        ACTIVE,
        INACTIVE
    }

    IERC20 public Token;

    address public Creator;

    string public Logo;

    uint256 public PoolTime;

    uint256 public PoolDuration;

    Status public PoolStatus;

    uint256 public EarlyWithdrawalFee;

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
        uint256 balance;
        Status stake_status;
    }

    Stake[] public stakes;

    mapping (address => Stake) public _stakes;

    event Staked(address indexed _user, uint256 amount);

    event Withdrawal(address indexed _user, uint256 amount);

    constructor(address _token, string memory logo, address creator, uint256 duration, uint256 rewards, uint256 fee) {
        Token = IERC20(_token);

        Creator = creator;

        Logo = logo;

        PoolTime = block.timestamp;

        PoolDuration = duration;

        PoolStatus = Status.ACTIVE;

        EarlyWithdrawalFee = fee;

        TotalStaked = 0;

        RewardsBalance = rewards;
    }

    modifier onlyCreator {
        require(msg.sender == Creator, "Only the creator of this pool can call this function.");
        _;
    }

    function staking(uint256 _amount, uint256 duration) public payable {
        require(PoolStatus == Status.ACTIVE, "This Pool is not active at the moment.");

        require(!userStakeExists(), "A user cannot stake while he/she has an active staking position.");

        require(_amount > 0, "Not enough tokens required for staking.");

        require(duration < PoolDuration && duration >= 1, "Inappriopate lock duration.");

        Token.transferFrom(msg.sender, address(this), _amount);

        uint256 prevBalance = RewardsBalance + TotalStaked + _amount;

        require(Token.balanceOf(address(this)) >= prevBalance, "Transfer of tokens for staking failed.");

        TotalStaked += _amount;

        uint256 poolTimeElapsed = (block.timestamp - PoolTime) / 86400;

        uint256 poolTimeLeft = PoolDuration - poolTimeElapsed;

        uint256 lockratio = (duration * 1000) / poolTimeLeft;

        uint256 stakeratio = (_amount * 1000) / TotalStaked;

        uint256 rewardratio = 0;

        if(lockratio == 0 && stakeratio != 0) {
            rewardratio = 1 * stakeratio;
        } else if(stakeratio == 0 && lockratio != 0) {
            rewardratio = 1 * lockratio;
        } else if(stakeratio == 0 && lockratio == 0) {
            rewardratio = 1 * 1;
        } else {
            rewardratio = lockratio * stakeratio;
        }

        require(rewardratio != 0, "Rewards cannot be zero.");
        
        Stake memory stake = Stake({
            user : msg.sender,
            amount : _amount,
            locktime : block.timestamp,
            lockduration : duration,
            lock_ratio : lockratio,
            stake_ratio : stakeratio,
            reward_ratio : rewardratio,
            balance : 0,
            stake_status : Status.ACTIVE
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

        if(count == 0) {
            count = 1;
        }

        return count;
    }

    function userStakeExists() internal view returns (bool) {
        bool exists = false;

        for(uint256 i = 0; i < stakes.length; i++) {
            Stake storage _stake = stakes[i];

            if(_stake.user == msg.sender && _stake.stake_status == Status.ACTIVE) {
                exists = true;

                break;
            }
        }

        return exists;
    }

    function calculateStakingYield() public view returns (uint256, uint256) {
        Stake storage stake01 = _stakes[msg.sender];

        uint256 poolTimeElapsed = (block.timestamp - PoolTime) / 86400;

        uint256 poolTimeLeft = PoolDuration - poolTimeElapsed;

        uint256 maxRewardsPerDay = RewardsBalance / poolTimeLeft;

        uint256 withdrawals = possibleWithdrawals();

        uint256 maxRewardsPerUser = maxRewardsPerDay / withdrawals;

        uint256 rewards = (stake01.reward_ratio * RewardsBalance) / 1000000;

        return (rewards, maxRewardsPerUser);
    }

    function withdrawal() public payable {
        require(PoolStatus == Status.ACTIVE, "This Pool is not active at the moment.");

        Stake storage stake02 = _stakes[msg.sender];

        require(stake02.stake_status == Status.ACTIVE, "You are ineligible for withdrawal.");

        uint256 timeElapsed = (block.timestamp - stake02.locktime) / 86400;

        require(timeElapsed >= stake02.lockduration, "Withdrawal is not available at this time.");

        (uint256 rewards, uint256 maxRewardsPerUser) = calculateStakingYield();

        if(rewards > maxRewardsPerUser) {
            uint256 amount = maxRewardsPerUser + stake02.amount;

            Token.transferFrom(address(this), msg.sender, amount);

            uint256 newBalance = RewardsBalance + TotalStaked - amount;

            require(Token.balanceOf(address(this)) <= newBalance, "Transfer of tokens from staking yield failed.");
        
            stake02.balance = rewards - maxRewardsPerUser;

            emit Withdrawal(msg.sender, amount);
        } else {
            uint256 amount = rewards + stake02.amount;

            Token.transferFrom(address(this), msg.sender, amount);

            uint256 newBalance = RewardsBalance + TotalStaked - amount;

            require(Token.balanceOf(address(this)) <= newBalance, "Transfer of tokens from staking yield failed.");

            stake02.stake_status = Status.INACTIVE;

            emit Withdrawal(msg.sender, amount);
        }
    }

    function earlyWithdrawal() public payable {
        require(PoolStatus == Status.ACTIVE, "This Pool is not active at the moment.");

        Stake storage stake03 = _stakes[msg.sender];

        require(stake03.stake_status == Status.ACTIVE, "You are ineligible for withdrawal.");

        // uint256 stakeTimeElapsed = (block.timestamp - stake03.locktime) / 86400;

        // uint256 stakeTimeLeft = stake03.lockduration - stakeTimeElapsed;

        (uint256 rewards, uint256 maxRewardsPerUser) = calculateStakingYield();

        uint256 fee = (rewards * EarlyWithdrawalFee) / 100;

        rewards = rewards - fee;

        if(rewards > maxRewardsPerUser) {
            uint256 amount = maxRewardsPerUser + stake03.amount;

            Token.transferFrom(address(this), msg.sender, amount);

            uint256 newBalance = RewardsBalance + TotalStaked - amount;

            require(Token.balanceOf(address(this)) <= newBalance, "Transfer of tokens from staking yield failed.");
        
            stake03.balance = rewards - maxRewardsPerUser;

            emit Withdrawal(msg.sender, amount);
        } else {
            uint256 amount = rewards + stake03.amount;

            Token.transferFrom(address(this), msg.sender, amount);

            uint256 newBalance = RewardsBalance + TotalStaked - amount;

            require(Token.balanceOf(address(this)) <= newBalance, "Transfer of tokens from staking yield failed.");

            stake03.stake_status = Status.INACTIVE;

            emit Withdrawal(msg.sender, amount);
        }
    }

    function withdrawBalance() public payable {
        require(PoolStatus == Status.ACTIVE, "This Pool is not active at the moment.");

        Stake storage stake04 = _stakes[msg.sender];

        uint256 balance = stake04.balance;

        require(stake04.stake_status == Status.ACTIVE && balance > 0, "You are ineligible for withdrawal.");
    
        ( , uint256 maxRewardsPerUser) = calculateStakingYield();

        if(balance > maxRewardsPerUser) {
            Token.transferFrom(address(this), msg.sender, maxRewardsPerUser);

            uint256 newBalance = RewardsBalance + TotalStaked - maxRewardsPerUser;

            require(Token.balanceOf(address(this)) <= newBalance, "Transfer of tokens from staking yield failed.");
        
            stake04.balance = balance - maxRewardsPerUser;

            emit Withdrawal(msg.sender, maxRewardsPerUser);
        } else {
            Token.transferFrom(address(this), msg.sender, balance);

            uint256 newBalance = RewardsBalance + TotalStaked - balance;

            require(Token.balanceOf(address(this)) <= newBalance, "Transfer of tokens from staking yield failed.");

            stake04.stake_status = Status.INACTIVE;

            emit Withdrawal(msg.sender, balance);
        }
    }

    function changePoolTime(uint256 time) onlyCreator public {
        PoolTime = time;
    }

    function changePoolDuration(uint256 duration) onlyCreator public {
        PoolDuration = duration;
    }

    function changeEarlyWithdrawalFee(uint256 fee) onlyCreator public {
        EarlyWithdrawalFee = fee;
    }

    function deactivatePool() onlyCreator public {
        uint256 poolTimeElapsed = (block.timestamp - PoolTime) / 86400;

        require(poolTimeElapsed >= PoolDuration, "Cannot deactivate the pool at the moment.");

        PoolStatus = Status.INACTIVE;
    }

    function increaseRewardsBalance(uint256 _amount) onlyCreator public {
        Token.transferFrom(msg.sender, address(this), _amount);

        uint256 prevBalance = RewardsBalance + TotalStaked + _amount;

        require(Token.balanceOf(address(this)) >= prevBalance, "Transfer of tokens for staking failed.");

        RewardsBalance += _amount;
    }
}