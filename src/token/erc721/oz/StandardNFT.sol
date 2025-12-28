// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract StandardNFT is ERC721 {
    uint256 public constant MAX_SUPPLY = 10;

    constructor() ERC721("StandardNFT", "SNFT") {
        for (uint256 tokenId = 1; tokenId <= MAX_SUPPLY; tokenId++) {
            _safeMint(msg.sender, tokenId);
        }
    }

    function _baseURI() internal pure override(ERC721) returns (string memory) {
        return "ipfs://QmXXX/";
    }
}
