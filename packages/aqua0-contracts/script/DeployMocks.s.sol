// SPDX-License-Identifier: LicenseRef-Degensoft-Aqua-Source-1.1
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice Mock ERC20 token for testing
contract MockToken is ERC20 {
    uint8 private _decimals;

    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals_
    ) ERC20(name, symbol) {
        _decimals = decimals_;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @title DeployMocks
/// @notice Deploys mock tokens (USDC, USDT, ETH) for testnet testing
contract DeployMocks is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying mock tokens...");
        console.log("Deployer:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy mock USDC (6 decimals)
        MockToken usdc = new MockToken("USD Coin", "USDC", 6);
        console.log("Mock USDC deployed at:", address(usdc));

        // Deploy mock USDT (6 decimals)
        MockToken usdt = new MockToken("Tether USD", "USDT", 6);
        console.log("Mock USDT deployed at:", address(usdt));

        // Deploy mock WETH (18 decimals)
        MockToken weth = new MockToken("Wrapped Ether", "WETH", 18);
        console.log("Mock WETH deployed at:", address(weth));

        // Mint initial supply to deployer
        uint256 initialSupply = 1_000_000; // 1M tokens
        usdc.mint(deployer, initialSupply * 10 ** 6);
        usdt.mint(deployer, initialSupply * 10 ** 6);
        weth.mint(deployer, initialSupply * 10 ** 18);

        console.log("\nMinted to deployer:");
        console.log("- 1M USDC");
        console.log("- 1M USDT");
        console.log("- 1M WETH");

        vm.stopBroadcast();

        // Save addresses to file for later use
        string memory output = string.concat(
            "USDC=",
            vm.toString(address(usdc)),
            "\n",
            "USDT=",
            vm.toString(address(usdt)),
            "\n",
            "WETH=",
            vm.toString(address(weth)),
            "\n"
        );

        vm.writeFile("./script/deployed-mocks.txt", output);
        console.log("\nAddresses saved to script/deployed-mocks.txt");
    }
}

