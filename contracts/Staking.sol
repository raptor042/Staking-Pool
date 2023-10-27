// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "./Pool.sol";

contract Staking {
    Pool[] public pools;

    mapping (string => Pool) public _pools;

    event CreatePool(address creator, address indexed token, string indexed poolID, uint256 apy, uint256 time, uint256 fee);

    constructor() {}

    function createStakingPool(string memory name, address token, uint256 apy, uint256 time, uint256 fee) public returns (string memory, address) {
        Pool pool = new Pool(
            token,
            msg.sender,
            apy,
            time,
            fee
        );

        string memory poolID = string(abi.encodePacked(name, "#", block.timestamp));

        pools.push(pool);

        _pools[poolID] = pool;

        emit CreatePool(msg.sender, token, poolID, apy, time, fee);

        return (poolID, address(pool));
    }
}