// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract DeflationaryToken is ERC20, Ownable {
    uint256 public constant INITIAL_SUPPLY = 10000 * 10 ** 18;

    // ====== 固定税率（万分比 bps） ======
    uint256 public constant BURN_BPS = 200; // 2.00%
    uint256 public constant TREASURY_BPS = 300; // 3.00%
    uint256 public constant BPS_DENOM = 10_000;

    address public treasury;

    mapping(address => bool) public isAMMPair;
    mapping(address => bool) public isExcludedFromFee;

    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event PairUpdated(address indexed pair, bool enabled);
    event ExcludedFromFee(address indexed account, bool excluded);

    error ZeroAddress();

    constructor(address initial_treasury) ERC20("DeflationaryToken", "DT") Ownable(msg.sender) {
        if (initial_treasury == address(0)) revert ZeroAddress();
        treasury = initial_treasury;

        // 常见免税：owner、treasury、合约自身
        isExcludedFromFee[msg.sender] = true;
        isExcludedFromFee[initial_treasury] = true;
        isExcludedFromFee[address(this)] = true;

        _mint(msg.sender, INITIAL_SUPPLY);
    }

    // ====== 管理函数（不包含税率调整） ======
    function setTreasury(address newTreasury) external onlyOwner {
        if (newTreasury == address(0)) revert ZeroAddress();
        address old = treasury;
        treasury = newTreasury;

        // 新旧 treasury 都免税，避免迁移资产时被扣税
        isExcludedFromFee[newTreasury] = true;

        emit TreasuryUpdated(old, newTreasury);
    }

    function setPair(address pair, bool enabled) external onlyOwner {
        if (pair == address(0)) revert ZeroAddress();
        if (enabled == false) {
            delete isAMMPair[pair];
        } else {
            isAMMPair[pair] = enabled;
        }

        emit PairUpdated(pair, enabled);
    }

    function setExcludedFromFee(address account, bool excluded) external onlyOwner {
        isExcludedFromFee[account] = excluded;
        emit ExcludedFromFee(account, excluded);
    }

    // ====== 核心：只对买卖收税（与 pair 交互） ======
    function _update(address from, address to, uint256 value) internal override(ERC20) {
        // 1) mint 或 burn：不收税
        if (from == address(0) || to == address(0)) {
            super._update(from, to, value);
            return;
        }

        // 2) 免税地址 or 非swap：不收税
        bool isFeeExempt = isExcludedFromFee[from] || isExcludedFromFee[to];
        if (isFeeExempt) {
            super._update(from, to, value);
            return;
        }

        bool isSwap = isAMMPair[from] || isAMMPair[to];
        if (!isSwap) {
            super._update(from, to, value);
            return;
        }

        // 3) 买卖收税：拆分为 net + burn + treasury 三次 update
        uint256 burnAmt = value * BURN_BPS / BPS_DENOM;
        uint256 treasAmt = value * TREASURY_BPS / BPS_DENOM;
        uint256 net = value - burnAmt - treasAmt;

        super._update(from, to, net);
        if (burnAmt > 0) super._update(from, address(0), burnAmt);
        if (treasAmt > 0) super._update(from, treasury, treasAmt);
    }
}
