// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script} from "forge-std/Script.sol";
import {XAAIAO} from "../../src/XAAIAO.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";

import {console} from "forge-std/Test.sol";

contract Deploy is Script {
    function run() external returns (address proxy, address logic) {
        string memory privateKeyString = vm.envString("PRIVATE_KEY");
        uint256 deployerPrivateKey;

        if (
            bytes(privateKeyString).length > 0 &&
            bytes(privateKeyString)[0] == "0" &&
            bytes(privateKeyString)[1] == "x"
        ) {
            deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        } else {
            deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        }

        vm.startBroadcast(deployerPrivateKey);

        (proxy, logic) = deploy();
        vm.stopBroadcast();
        console.log("Proxy Contract deployed at:", proxy);
        console.log("Logic Contract deployed at:", logic);
        return (proxy, logic);
    }

    function deploy() public returns (address proxy, address logic) {
        //        Options memory opts;

        address owner = vm.envAddress("XAAIAO_OWNER");
        console.log("owner Address:", owner);

        address tokenInContract = vm.envAddress("XAAIAO_TOKEN_IN_CONTRACT");
        console.log(" tokenInContract Address:",  tokenInContract);

        address rewardTokenContract = vm.envAddress("XAAIAO_REWARD_TOKEN_CONTRACT");
        console.log("rewardTokenContract Address:", rewardTokenContract);

        int256 startTimestamp = vm.envInt("XAAIAO_START_TIMESTAMP");
        console.log("startTimestamp:", startTimestamp);

        int256 periodHours = vm.envInt("XAAIAO_PERIOD_HOURS");
        console.log("periodHours:", periodHours);

        int256 rewardAmount = vm.envInt("XAAIAO_REWARD_AMOUNT");
        console.log("rewardAmount:", rewardAmount);

        proxy = Upgrades.deployUUPSProxy(
            "XAAIAO.sol:XAAIAO",
            abi.encodeCall(XAAIAO.initialize, (owner, tokenInContract,rewardTokenContract, uint256(startTimestamp), uint256(periodHours), uint256(rewardAmount)))
        );
        return (proxy, logic);
    }
}
