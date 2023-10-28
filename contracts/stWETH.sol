// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract stWETH is ERC20 {
	constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {
		_mint(address(this), 100000000*10**18);
	}
}