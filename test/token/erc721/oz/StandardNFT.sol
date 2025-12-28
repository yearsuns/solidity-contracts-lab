// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {StandardNFT} from "../../../../src/token/erc721/oz/StandardNFT.sol";

contract StandardNFTTest is Test {
    StandardNFT nft;

    address deployer = address(0xAAAA);
    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    /*//////////////////////////////////////////////////////////////
                                setup
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        vm.prank(deployer);
        nft = new StandardNFT();
    }

    /*//////////////////////////////////////////////////////////////
                        constructor / initial state
    //////////////////////////////////////////////////////////////*/

    function test_constructor_setsNameAndSymbol() public view {
        assertEq(nft.name(), "StandardNFT");
        assertEq(nft.symbol(), "SNFT");
    }

    function test_constructor_mintsAllTokensToDeployer() public view {
        // tokenId starts at 1 and ends at MAX_SUPPLY (10)
        assertEq(nft.balanceOf(deployer), nft.MAX_SUPPLY());

        // Spot-check ownership and token existence across the range
        assertEq(nft.ownerOf(1), deployer);
        assertEq(nft.ownerOf(5), deployer);
        assertEq(nft.ownerOf(nft.MAX_SUPPLY()), deployer);
    }

    function test_constructor_emitsTransferEvents_forAllMints() public {
        // Redeploy and record logs so we can validate mint Transfer events
        vm.recordLogs();
        vm.prank(deployer);
        StandardNFT fresh = new StandardNFT();

        Vm.Log[] memory entries = vm.getRecordedLogs();

        // ERC721 Transfer event signature:
        // Transfer(address indexed from, address indexed to, uint256 indexed tokenId)
        bytes32 transferSig = keccak256("Transfer(address,address,uint256)");

        uint256 transferCount;
        uint256 max = fresh.MAX_SUPPLY();

        for (uint256 i = 0; i < entries.length; i++) {
            Vm.Log memory logEntry = entries[i];
            if (logEntry.topics.length == 4 && logEntry.topics[0] == transferSig) {
                // from (indexed)
                address from = address(uint160(uint256(logEntry.topics[1])));
                // to (indexed)
                address to = address(uint160(uint256(logEntry.topics[2])));
                // tokenId (indexed)
                uint256 tokenId = uint256(logEntry.topics[3]);

                // Only count constructor mints: from == address(0), to == deployer, tokenId in range
                if (from == address(0) && to == deployer && tokenId >= 1 && tokenId <= max) {
                    transferCount++;
                }
            }
        }

        assertEq(transferCount, max);
    }

    /*//////////////////////////////////////////////////////////////
                                metadata
    //////////////////////////////////////////////////////////////*/

    function test_baseURI_isExpected() public view {
        // OZ's ERC721.tokenURI() returns baseURI + tokenId (as decimal string).
        assertEq(nft.tokenURI(1), "ipfs://QmXXX/1");
        assertEq(nft.tokenURI(4), "ipfs://QmXXX/4");
        assertEq(nft.tokenURI(nft.MAX_SUPPLY()), "ipfs://QmXXX/10");
    }

    function test_tokenURI_nonexistent_reverts() public {
        uint256 nonexistent = nft.MAX_SUPPLY() + 1;
        vm.expectRevert(); // OZ reverts for nonexistent token ID (error type may vary by OZ version)
        nft.tokenURI(nonexistent);
    }

    /*//////////////////////////////////////////////////////////////
                                transfer
    //////////////////////////////////////////////////////////////*/

    function test_transferFrom_deployerToAlice_succeeds() public {
        uint256 tokenId = 1;

        vm.prank(deployer);
        nft.transferFrom(deployer, alice, tokenId);

        assertEq(nft.ownerOf(tokenId), alice);
        assertEq(nft.balanceOf(deployer), nft.MAX_SUPPLY() - 1);
        assertEq(nft.balanceOf(alice), 1);
    }

    function test_transferFrom_nonOwnerNotApproved_reverts() public {
        uint256 tokenId = 1;

        vm.prank(alice);
        vm.expectRevert(); // OZ reverts when caller is not owner nor approved
        nft.transferFrom(deployer, bob, tokenId);
    }

    function test_approve_then_transferFrom_byApproved_succeeds() public {
        uint256 tokenId = 2;

        vm.prank(deployer);
        nft.approve(bob, tokenId);

        vm.prank(bob);
        nft.transferFrom(deployer, alice, tokenId);

        assertEq(nft.ownerOf(tokenId), alice);
        assertEq(nft.getApproved(tokenId), address(0)); // approval cleared after transfer
    }

    function test_setApprovalForAll_then_transferFrom_byOperator_succeeds() public {
        uint256 tokenId = 3;

        vm.prank(deployer);
        nft.setApprovalForAll(bob, true);
        assertTrue(nft.isApprovedForAll(deployer, bob));

        vm.prank(bob);
        nft.transferFrom(deployer, alice, tokenId);

        assertEq(nft.ownerOf(tokenId), alice);
    }
}
