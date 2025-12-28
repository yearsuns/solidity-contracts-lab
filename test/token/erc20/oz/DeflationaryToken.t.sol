// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {DeflationaryToken} from "../../../../src/token/erc20/oz/DeflationaryToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract DeflationaryTokenTest is Test {
    DeflationaryToken token;

    address owner = address(0xAAAA);
    address treasury = address(0xBBBB);
    address pair = address(0xCCCC);
    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    // 事件签名要和合约一致，才能 expectEmit
    event Transfer(address indexed from, address indexed to, uint256 value);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event PairUpdated(address indexed pair, bool enabled);
    event ExcludedFromFee(address indexed account, bool excluded);

    function setUp() public {
        vm.startPrank(owner);
        token = new DeflationaryToken(treasury);
        vm.stopPrank();

        // 默认 owner 有 INITIAL_SUPPLY
        assertEq(token.balanceOf(owner), token.INITIAL_SUPPLY());
    }

    // -------------------------
    // Constructor / init tests
    // -------------------------

    function test_constructor_revertOnZeroTreasury() public {
        vm.expectRevert(DeflationaryToken.ZeroAddress.selector);
        new DeflationaryToken(address(0));
    }

    function test_constructor_setsExcluded() public view {
        assertTrue(token.isExcludedFromFee(owner));
        assertTrue(token.isExcludedFromFee(treasury));
        assertTrue(token.isExcludedFromFee(address(token)));
    }

    // -------------------------
    // Admin function tests
    // -------------------------

    function test_setTreasury_onlyOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        token.setTreasury(address(0x1234));
    }

    function test_setTreasury_revertOnZero() public {
        vm.prank(owner);
        vm.expectRevert(DeflationaryToken.ZeroAddress.selector);
        token.setTreasury(address(0));
    }

    function test_setTreasury_updatesAndEmitsAndExcluded() public {
        address newTreasury = address(0xCAFE);

        vm.prank(owner);
        vm.expectEmit(true, true, false, true);
        emit TreasuryUpdated(treasury, newTreasury);
        token.setTreasury(newTreasury);

        assertEq(token.treasury(), newTreasury);
        assertTrue(token.isExcludedFromFee(newTreasury));
    }

    function test_setPair_onlyOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        token.setPair(pair, true);
    }

    function test_setPair_revertOnZero() public {
        vm.prank(owner);
        vm.expectRevert(DeflationaryToken.ZeroAddress.selector);
        token.setPair(address(0), true);
    }

    function test_setPair_updatesAndEmits() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit PairUpdated(pair, true);
        token.setPair(pair, true);

        assertTrue(token.isAMMPair(pair));
    }

    function test_setExcludedFromFee_onlyOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        token.setExcludedFromFee(bob, true);
    }

    function test_setExcludedFromFee_updatesAndEmits() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit ExcludedFromFee(bob, true);
        token.setExcludedFromFee(bob, true);

        assertTrue(token.isExcludedFromFee(bob));
    }

    // -------------------------
    // Fee logic tests
    // -------------------------

    function _enablePair(address p) internal {
        vm.prank(owner);
        token.setPair(p, true);
    }

    function test_walletToWallet_noFee() public {
        uint256 amount = 100e18;

        vm.prank(owner);
        token.transfer(alice, amount);

        // owner 是免税，但即便不免税，wallet->wallet 也不该收税
        assertEq(token.balanceOf(alice), amount);
    }

    function test_buy_fromPair_takesFee_burnAndTreasuryAndEmits() public {
        _enablePair(pair);

        // 金额避开整百，可以覆盖计算时的小数问题
        uint256 amount = 123456789123456789;

        // 给 pair 先一些币，模拟池子有库存
        vm.prank(owner);
        token.transfer(pair, amount);

        // owner 免税，pair 不是免税；这里的 buy 是 pair -> alice
        uint256 supplyBefore = token.totalSupply();
        uint256 treasuryBefore = token.balanceOf(treasury);
        uint256 aliceBefore = token.balanceOf(alice);

        uint256 burnAmt = amount * token.BURN_BPS() / token.BPS_DENOM(); // 2
        uint256 treasAmt = amount * token.TREASURY_BPS() / token.BPS_DENOM(); // 3
        uint256 net = amount - burnAmt - treasAmt; // 95

        vm.prank(pair);
        vm.expectEmit(true, true, false, true);
        emit Transfer(pair, address(0), burnAmt);
        emit Transfer(pair, treasury, treasAmt);
        emit Transfer(pair, alice, net);
        token.transfer(alice, amount);

        assertEq(token.balanceOf(alice), aliceBefore + net);
        assertEq(token.balanceOf(treasury), treasuryBefore + treasAmt);
        assertEq(token.totalSupply(), supplyBefore - burnAmt);
    }

    function test_sell_toPair_takesFee_burnAndTreasuryAndEmits() public {
        _enablePair(pair);

        // 金额避开整百，可以覆盖计算时的小数问题
        uint256 amount = 123456789123456789;

        // 给 alice 一些币（从 owner 转，owner 免税，不影响）
        vm.prank(owner);
        token.transfer(alice, amount);

        uint256 supplyBefore = token.totalSupply();
        uint256 treasuryBefore = token.balanceOf(treasury);
        uint256 pairBefore = token.balanceOf(pair);

        uint256 burnAmt = amount * token.BURN_BPS() / token.BPS_DENOM();
        uint256 treasAmt = amount * token.TREASURY_BPS() / token.BPS_DENOM();
        uint256 net = amount - burnAmt - treasAmt;

        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit Transfer(alice, address(0), burnAmt);
        emit Transfer(alice, treasury, treasAmt);
        emit Transfer(alice, pair, net);
        token.transfer(pair, amount);

        assertEq(token.balanceOf(pair), pairBefore + net);
        assertEq(token.balanceOf(treasury), treasuryBefore + treasAmt);
        assertEq(token.totalSupply(), supplyBefore - burnAmt);
    }

    function test_smallAmount_33_buyFromPair_noFeeBecauseBothFeesRoundToZero() public {
        _enablePair(pair);

        uint256 amount = 33; // 最小单位（wei-like），确保 burn=0 且 treasury=0

        // 给 pair 一些币，模拟池子有库存
        vm.prank(owner);
        token.transfer(pair, amount);

        uint256 supplyBefore = token.totalSupply();
        uint256 treasuryBefore = token.balanceOf(treasury);
        uint256 aliceBefore = token.balanceOf(alice);

        // buy: pair -> alice
        vm.prank(pair);
        vm.expectEmit(true, true, false, true);
        emit Transfer(pair, alice, amount);
        token.transfer(alice, amount);

        // 因为 burnAmt=0 且 treasAmt=0，所以 alice 应拿到全额，totalSupply 不变，treasury 不变
        assertEq(token.balanceOf(alice), aliceBefore + amount);
        assertEq(token.balanceOf(treasury), treasuryBefore);
        assertEq(token.totalSupply(), supplyBefore);
    }

    function test_smallAmount_34_sellToPair_onlyTreasuryFeeRoundsToOne() public {
        _enablePair(pair);

        uint256 amount = 34; // treas=1, burn=0 的最小值

        // 给 alice 一些币（从 owner 转，owner 免税）
        vm.prank(owner);
        token.transfer(alice, amount);

        uint256 supplyBefore = token.totalSupply();
        uint256 treasuryBefore = token.balanceOf(treasury);
        uint256 pairBefore = token.balanceOf(pair);

        uint256 burnAmt = amount * token.BURN_BPS() / token.BPS_DENOM(); // 0
        uint256 treasAmt = amount * token.TREASURY_BPS() / token.BPS_DENOM(); // 1
        uint256 net = amount - burnAmt - treasAmt; // 33

        // sell: alice -> pair
        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit Transfer(alice, treasury, treasAmt);
        emit Transfer(alice, pair, net);
        token.transfer(pair, amount);

        assertEq(burnAmt, 0);
        assertEq(treasAmt, 1);

        // burn 不发生，所以 totalSupply 不变；treasury +1；pair 收到 net=33
        assertEq(token.balanceOf(pair), pairBefore + net);
        assertEq(token.balanceOf(treasury), treasuryBefore + treasAmt);
        assertEq(token.totalSupply(), supplyBefore);
    }

    function test_excludedAddress_noFee_evenIfAMMTransfer() public {
        _enablePair(pair);

        uint256 amount = 100e18;

        // 给 pair 一些币
        vm.prank(owner);
        token.transfer(pair, amount);

        // 把 alice 设为免税：pair -> alice 应该不扣
        vm.prank(owner);
        token.setExcludedFromFee(alice, true);

        uint256 supplyBefore = token.totalSupply();
        uint256 treasuryBefore = token.balanceOf(treasury);

        vm.prank(pair);
        token.transfer(alice, amount);

        assertEq(token.balanceOf(alice), amount);
        assertEq(token.balanceOf(treasury), treasuryBefore); // 没进金库
        assertEq(token.totalSupply(), supplyBefore); // 没 burn
    }

    function test_disablePair_stopsFee() public {
        _enablePair(pair);

        // 金额避开整百，可以覆盖计算时的小数问题
        uint256 amount = 123456789123456789;
        vm.prank(owner);
        token.transfer(alice, amount);

        // 先开启时卖出会扣税
        vm.prank(alice);
        token.transfer(pair, amount);

        // 关闭 AMM pair
        vm.prank(owner);
        token.setPair(pair, false);

        // 再给 alice 一次币
        vm.prank(owner);
        token.transfer(alice, amount);

        uint256 supplyBefore = token.totalSupply();
        uint256 treasuryBefore = token.balanceOf(treasury);
        uint256 pairBefore = token.balanceOf(pair);

        // 此时卖出不应扣税（因为 isAMMPair[to]=false）
        vm.prank(alice);
        token.transfer(pair, amount);

        assertEq(token.balanceOf(pair), pairBefore + amount);
        assertEq(token.balanceOf(treasury), treasuryBefore);
        assertEq(token.totalSupply(), supplyBefore);
    }

    // -------------------------
    // transferFrom path
    // -------------------------

    function test_transferFrom_sellToPair_takesFee() public {
        _enablePair(pair);

        // 金额避开整百，可以覆盖计算时的小数问题
        uint256 amount = 123456789123456789;
        vm.prank(owner);
        token.transfer(alice, amount);

        // alice approve bob，然后 bob 代卖到 pair
        vm.prank(alice);
        token.approve(bob, amount);

        uint256 supplyBefore = token.totalSupply();
        uint256 treasuryBefore = token.balanceOf(treasury);
        uint256 pairBefore = token.balanceOf(pair);

        vm.prank(bob);
        token.transferFrom(alice, pair, amount);

        uint256 burnAmt = amount * token.BURN_BPS() / token.BPS_DENOM();
        uint256 treasAmt = amount * token.TREASURY_BPS() / token.BPS_DENOM();
        uint256 net = amount - burnAmt - treasAmt;

        assertEq(token.balanceOf(pair), pairBefore + net);
        assertEq(token.balanceOf(treasury), treasuryBefore + treasAmt);
        assertEq(token.totalSupply(), supplyBefore - burnAmt);
    }
}
