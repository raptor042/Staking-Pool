// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Pool {
    IERC20 public token;

    enum Status { ACTIVE, INACTIVE }

    address public creator;

    Status public status;

    uint256 public APY;

    uint256 public lock_time;

    uint256 public early_withdrawal_fee;

    uint256 public totalStaked;

    struct Stake {
        address user;
        uint256 amount;
        uint256 _locktime;
        Status _status;
    }

    Stake[] public stakes;

    mapping (address => Stake) public _stakes;

    event Staked(address indexed _user, uint256 amount);

    event Withdrawal(address indexed _user, uint256 amount);

    constructor(address _token, address _creator, uint256 apy, uint256 time, uint256 fee) {
        token = IERC20(_token);

        creator = _creator;

        status = Status.ACTIVE;

        APY = apy;

        lock_time = time * 1 days;

        early_withdrawal_fee = fee;
    }

    modifier onlyCreator {
        require(msg.sender == creator, "Only the creator of this pool can call this function.");
        _;
    }

    function staking(uint256 _amount) public payable {
        require(_amount > 0, "Not enough tokens required for staking.");

        require(token.transferFrom(msg.sender, address(this), _amount), "Transfer of tokens for staking failed.");

        Stake memory stake = Stake({
            user : msg.sender,
            amount : _amount,
            _locktime : block.timestamp,
            _status : Status.ACTIVE
        });

        stakes.push(stake);

        _stakes[msg.sender] = stake;

        emit Staked(msg.sender, _amount);
    }

    function calculateStakingYield() public view returns (uint256) {
        Stake storage stake01 = _stakes[msg.sender];

        uint256 timeElapsed = (block.timestamp - stake01._locktime) / 86400;

        uint256 accumulated = (((APY * timeElapsed) * stake01.amount) / 100) + stake01.amount;

        return accumulated;
    }

    function withdrawal() public payable {
        Stake storage stake02 = _stakes[msg.sender];

        uint256 timeElapsed = (block.timestamp - stake02._locktime) / 86400;

        require(timeElapsed >= lock_time * 86400, "Withdrawal is not available at this time.");

        uint256 yield = calculateStakingYield();

        require(token.transferFrom(address(this), msg.sender, yield), "Transfer of tokens from staking yield failed.");

        Stake storage stake = _stakes[msg.sender];

        stake._status = Status.INACTIVE;

        emit Withdrawal(msg.sender, yield);
    }

    function earlyWithdrawal() public payable {
        uint256 yield = calculateStakingYield() - early_withdrawal_fee;

        require(token.transferFrom(address(this), msg.sender, yield), "Transfer of tokens from staking yield failed.");

        Stake storage stake03 = _stakes[msg.sender];

        stake03._status = Status.INACTIVE;

        emit Withdrawal(msg.sender, yield);
    }

    function deactivatePool() onlyCreator public {
        status = Status.INACTIVE;
    }

    function changeAPY(uint256 apy) onlyCreator public {
        APY = apy;
    }

    function changeLockTime(uint256 time) onlyCreator public {
        lock_time = time;
    }

    function changeEarlyWithdrawalFee(uint256 fee) onlyCreator public {
        early_withdrawal_fee = fee;
    }
}