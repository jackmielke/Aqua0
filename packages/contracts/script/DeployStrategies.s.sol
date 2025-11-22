// SPDX-License-Identifier: LicenseRef-Degensoft-Aqua-Source-1.1
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import {Aqua} from "aqua/Aqua.sol";
import {ConcentratedLiquiditySwap} from "../src/ConcentratedLiquiditySwap.sol";
import {StableswapAMM} from "../src/StableswapAMM.sol";

/// @title DeployStrategies
/// @notice Deploys Aqua protocol and trading strategies
contract DeployStrategies is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying Aqua and Strategies...");
        console.log("Deployer:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy Aqua core protocol
        Aqua aqua = new Aqua();
        console.log("Aqua deployed at:", address(aqua));

        // Deploy ConcentratedLiquiditySwap strategy
        ConcentratedLiquiditySwap clSwap = new ConcentratedLiquiditySwap(aqua);
        console.log(
            "ConcentratedLiquiditySwap deployed at:",
            address(clSwap)
        );

        // Deploy StableswapAMM strategy
        StableswapAMM stableswap = new StableswapAMM(aqua);
        console.log("StableswapAMM deployed at:", address(stableswap));

        vm.stopBroadcast();

        // Save addresses to file
        string memory output = string.concat(
            "AQUA=",
            vm.toString(address(aqua)),
            "\n",
            "CONCENTRATED_LIQUIDITY=",
            vm.toString(address(clSwap)),
            "\n",
            "STABLESWAP=",
            vm.toString(address(stableswap)),
            "\n"
        );

        vm.writeFile("./script/deployed-strategies.txt", output);
        console.log("\nAddresses saved to script/deployed-strategies.txt");
    }
}

