// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script} from "forge-std/Script.sol";
import {StandardToken} from "../src/token/erc20/oz/StandardToken.sol";
import {MintableToken} from "../src/token/erc20/oz/MintableToken.sol";

contract DeployScript is Script {
    uint256 pk = vm.envUint("PRIVATE_KEY");
    StandardToken public standardToken;
    MintableToken public mintableToken;

    function setUp() public {}

    function run() public {
        vm.startBroadcast(pk);

        standardToken = new StandardToken();
        mintableToken = new MintableToken();

        vm.stopBroadcast();
    }
}
