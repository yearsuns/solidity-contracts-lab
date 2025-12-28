// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MintableToken is ERC20, ERC20Burnable, Ownable {
    uint256 public constant INITIAL_SUPPLY = 10000 * 10 ** 18;

    constructor() ERC20("MintableToken", "MT") Ownable(msg.sender) {
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    error ERC20TotalSupplyOverflow(uint256 currentSupply, uint256 value);

    function mint(address to, uint256 value) external onlyOwner {
        uint256 supply = totalSupply();
        uint256 newSupply;

        unchecked {
            newSupply = supply + value;
        }

        if (newSupply < supply) {
            revert ERC20TotalSupplyOverflow(supply, value);
        }

        _mint(to, value);
    }
}
