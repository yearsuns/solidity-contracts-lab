// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {StandardToken} from "../../../../src/token/erc20/oz/StandardToken.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract StandardTokenTest is Test {
    StandardToken token;

    address deployer = address(0xD00D);
    address alice = address(0xA11CE);
    address bob = address(0xB0B);
    address carol = address(0xCAFE);

    uint256 constant INITIAL_SUPPLY = 10000 ether;

    // Events (for expectEmit)
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function setUp() public {
        // Deploy with `deployer` so initial supply is owned by deployer
        vm.prank(deployer);
        token = new StandardToken();
    }

    /*//////////////////////////////////////////////////////////////
                      constructor / metadata / initial state
    //////////////////////////////////////////////////////////////*/

    function test_constructor_metadata_returnsExpectedValues() public view {
        assertEq(token.name(), "StandardToken");
        assertEq(token.symbol(), "ST");
        assertEq(token.decimals(), 18);
    }

    function test_constructor_initialSupply_mintedToDeployer() public view {
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.balanceOf(deployer), INITIAL_SUPPLY);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(address(0)), 0);
    }

    function test_totalSupply_transferAndApprove_doesNotChange() public {
        uint256 ts0 = token.totalSupply();

        vm.prank(deployer);
        /// forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(alice, 1 ether);

        vm.prank(deployer);
        token.approve(bob, 2 ether);

        assertEq(token.totalSupply(), ts0);
    }

    /*//////////////////////////////////////////////////////////////
                                transfer
    //////////////////////////////////////////////////////////////*/

    function test_transfer_success_emitsTransferAndUpdatesBalances() public {
        vm.prank(deployer);

        vm.expectEmit(true, true, false, true);
        emit Transfer(deployer, alice, 10 ether);

        bool ok = token.transfer(alice, 10 ether);
        assertTrue(ok);

        assertEq(token.balanceOf(deployer), INITIAL_SUPPLY - 10 ether);
        assertEq(token.balanceOf(alice), 10 ether);
    }

    function test_transfer_zeroAmount_succeeds() public {
        vm.prank(deployer);

        bool ok = token.transfer(alice, 0);
        assertTrue(ok);

        assertEq(token.balanceOf(deployer), INITIAL_SUPPLY);
        assertEq(token.balanceOf(alice), 0);
    }

    function test_transfer_toZeroAddress_revertsWithERC20InvalidReceiver() public {
        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        /// forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(address(0), 1);
    }

    function test_transfer_insufficientBalance_revertsWithERC20InsufficientBalance() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 0, 1));
        /// forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(bob, 1);
    }

    /*//////////////////////////////////////////////////////////////
                                approve
    //////////////////////////////////////////////////////////////*/

    function test_approve_success_emitsApprovalAndSetsAllowance() public {
        vm.prank(deployer);

        vm.expectEmit(true, true, false, true);
        emit Approval(deployer, alice, 100);

        bool ok = token.approve(alice, 100);
        assertTrue(ok);

        assertEq(token.allowance(deployer, alice), 100);
    }

    function test_approve_overwrite_succeedsAndUpdatesAllowance() public {
        vm.prank(deployer);
        token.approve(alice, 100);

        vm.prank(deployer);
        token.approve(alice, 20);

        assertEq(token.allowance(deployer, alice), 20);
    }

    function test_approve_spenderZeroAddress_revertsWithERC20InvalidSpender() public {
        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSpender.selector, address(0)));
        token.approve(address(0), 10);
    }

    /*//////////////////////////////////////////////////////////////
                              transferFrom
    //////////////////////////////////////////////////////////////*/

    function test_transferFrom_success_emitsTransferAndUpdatesBalancesAndAllowance() public {
        // Arrange: deployer approves alice
        vm.prank(deployer);
        token.approve(alice, 50);

        // Act: alice spends 20 from deployer to bob
        vm.prank(alice);

        vm.expectEmit(true, true, false, true);
        emit Transfer(deployer, bob, 20);

        bool ok = token.transferFrom(deployer, bob, 20);
        assertTrue(ok);

        // Assert
        assertEq(token.balanceOf(deployer), INITIAL_SUPPLY - 20);
        assertEq(token.balanceOf(bob), 20);
        assertEq(token.allowance(deployer, alice), 30);
    }

    function test_transferFrom_insufficientAllowance_revertsWithERC20InsufficientAllowance() public {
        vm.prank(deployer);
        token.approve(alice, 10);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, alice, 10, 20));
        /// forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transferFrom(deployer, bob, 20);
    }

    function test_transferFrom_fromInsufficientBalance_revertsWithERC20InsufficientBalance() public {
        // Arrange: alice approves bob, but alice has no balance
        vm.prank(alice);
        token.approve(bob, 10);

        // Act: bob tries to transfer 10 from alice to carol, should revert due to alice balance
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 0, 10));
        /// forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transferFrom(alice, carol, 10);
    }
}
