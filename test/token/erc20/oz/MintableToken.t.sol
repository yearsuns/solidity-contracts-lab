// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {MintableToken} from "../../../../src/token/erc20/oz/MintableToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MintableTokenTest is Test {
    MintableToken token;

    address owner = address(this);
    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    function setUp() public {
        token = new MintableToken();
    }

    /*//////////////////////////////////////////////////////////////
                        constructor / initial state
    //////////////////////////////////////////////////////////////*/

    function test_constructor_mintsInitialSupplyToOwner() public view {
        assertEq(token.totalSupply(), token.INITIAL_SUPPLY());
        assertEq(token.balanceOf(owner), token.INITIAL_SUPPLY());
    }

    function test_constructor_setsOwnerToDeployer() public view {
        assertEq(token.owner(), owner);
    }

    /*//////////////////////////////////////////////////////////////
                                mint
    //////////////////////////////////////////////////////////////*/

    function test_mint_onlyOwner_succeeds() public {
        uint256 amount = 100 ether;

        uint256 supplyBefore = token.totalSupply();
        uint256 balanceBefore = token.balanceOf(alice);

        token.mint(alice, amount);

        assertEq(token.totalSupply(), supplyBefore + amount);
        assertEq(token.balanceOf(alice), balanceBefore + amount);
    }

    function test_mint_nonOwner_revertsWithOwnableUnauthorizedAccount() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        token.mint(alice, 1 ether);
    }

    function test_mint_overflow_revertsWithERC20TotalSupplyOverflow() public {
        uint256 currentSupply = token.totalSupply();
        uint256 overflowAmount = type(uint256).max - currentSupply + 1;

        vm.expectRevert(
            abi.encodeWithSelector(MintableToken.ERC20TotalSupplyOverflow.selector, currentSupply, overflowAmount)
        );

        token.mint(alice, overflowAmount);
    }

    /*//////////////////////////////////////////////////////////////
                                burn
    //////////////////////////////////////////////////////////////*/

    function test_burn_self_reducesBalanceAndSupply() public {
        uint256 burnAmount = 50 ether;

        uint256 supplyBefore = token.totalSupply();
        uint256 balanceBefore = token.balanceOf(owner);

        token.burn(burnAmount);

        assertEq(token.totalSupply(), supplyBefore - burnAmount);
        assertEq(token.balanceOf(owner), balanceBefore - burnAmount);
    }

    function test_burnFrom_withAllowance_succeedsAndDecreasesAllowance() public {
        uint256 amount = 100 ether;

        // Arrange: owner transfers to alice, alice approves bob
        /// forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(alice, amount);

        vm.prank(alice);
        token.approve(bob, amount);

        uint256 supplyBefore = token.totalSupply();

        // Act: bob burns alice's tokens
        vm.prank(bob);
        token.burnFrom(alice, amount);

        // Assert: supply/balance/allowance updated
        assertEq(token.totalSupply(), supplyBefore - amount);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.allowance(alice, bob), 0);
    }
}
