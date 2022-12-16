// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {OnlyAdminAccessControl} from "onchain/remote-access-control/src/OnlyAdminAccessControl.sol";

contract DeployCore is Script {

    function setUp() public {}

    function run() public {

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        new OnlyAdminAccessControl();        

        vm.stopBroadcast();
    }
}

// ======= DEPLOY SCRIPTS =====

// source .env
// forge script script/AccessControlArch.s.sol:DeployCore --rpc-url $GOERLI_RPC_URL --broadcast --verify  -vvvv
// forge script script/AccessControlArch.s.sol:DeployCore --rpc-url $MAINNET_RPC_URL --broadcast --verify  -vvvv