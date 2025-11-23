// SPDX-License-Identifier: LicenseRef-Degensoft-Aqua-Source-1.1
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import {Aqua} from "aqua/Aqua.sol";
import {IAqua} from "aqua/interfaces/IAqua.sol";
import {ConcentratedLiquiditySwap} from "../src/ConcentratedLiquiditySwap.sol";
import {StableswapAMM} from "../src/StableswapAMM.sol";

/// @title DeployStrategies
/// @notice Deploys trading strategies using existing AquaRouter
/// @dev Requires AQUA_ROUTER env variable to be set
contract DeployStrategies is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying Strategies...");
        console.log("Deployer:", deployer);

        // Use existing AquaRouter (required)
        address aquaAddress = vm.envAddress("AQUA_ROUTER");
        console.log("Using existing AquaRouter at:", aquaAddress);

        IAqua aqua = IAqua(aquaAddress);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy ConcentratedLiquiditySwap strategy
        ConcentratedLiquiditySwap clSwap = new ConcentratedLiquiditySwap(aqua);
        console.log("ConcentratedLiquiditySwap deployed at:", address(clSwap));

        // Deploy StableswapAMM strategy
        StableswapAMM stableswap = new StableswapAMM(aqua);
        console.log("StableswapAMM deployed at:", address(stableswap));

        vm.stopBroadcast();

        // Save addresses to file
        string memory output = string.concat(
            "AQUA=",
            vm.toString(aquaAddress),
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
