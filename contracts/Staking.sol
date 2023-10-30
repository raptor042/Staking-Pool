// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "./Pool.sol";

contract Staking {
    Pool[] public pools;

    mapping (string => Pool) public _pools;

    event CreatePool(address creator, address token, address indexed pool, string indexed poolID, uint256 duration, uint256 rewards);

    constructor() {}

    function createStakingPool(string memory name, address token, uint256 duration, uint256 amount) public {
        Pool pool = new Pool(
            token,
            msg.sender,
            duration,
            amount
        );

        string memory poolID = string(abi.encodePacked(name, "#", block.timestamp));

        pools.push(pool);

        _pools[poolID] = pool;

        emit CreatePool(msg.sender, token, address(pool), poolID, duration, amount);
    }
}