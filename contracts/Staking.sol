// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "./Pool.sol";

interface IERC202 {
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

contract Staking {
    address[] public pools;

    uint256 public fee = 0.1 ether;

    event CreatePool(address creator, address token, address indexed pool, uint256 duration, uint256 rewards);

    constructor() {}

    function createStakingPool(address token, string memory logo, uint256 duration, uint256 amount, uint256 _fee) payable public {
        require(msg.value >= fee, "Creation of a staking pool requires a fee of 0.1BNB.");

        IERC202 Token = IERC202(token);

        Token.approve(address(this), amount);

        Pool pool = new Pool(
            token,
            logo,
            msg.sender,
            duration,
            amount,
            _fee
        );

        pools.push(address(pool));

        emit CreatePool(msg.sender, token, address(pool), duration, amount);
    }

    function getPools() view public returns (address[] memory) {
        return pools;
    }
}