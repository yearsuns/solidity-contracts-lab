// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract StandardToken is ERC20 {
    uint256 public constant INITIAL_SUPPLY = 10000 * 10 ** 18;

    constructor() ERC20("StandardToken", "ST") {
        _mint(msg.sender, INITIAL_SUPPLY);
    }
}
