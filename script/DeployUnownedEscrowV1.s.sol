// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "lib/forge-std/src/Script.sol";
import "../src/UnownedEscrowV1.sol";
import "lib/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract DeployUnownedEscrowV1 is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Replace these with your actual addresses
        address payable src = payable(address(0x426eA107af61245bD833293C0D180D35330b772E)); // src just for refunds
        address payable dest = payable(address(0x9B23aa450c8cac9955eaecD1B52A4e5244f6f220));
        IERC20 srcToken = IERC20(address(0xDC3326e71D45186F113a2F448984CA0e8D201995));  // Source token address
        IERC20 destToken = IERC20(address(0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359)); // Destination token address
        ISwapRouter swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564); // Uniswap V3 SwapRouter
        UnownedEscrowV1 escrow = new UnownedEscrowV1(
            src,
            dest,
            srcToken,
            destToken,
            swapRouter
        );
        console.log("UnownedEscrowV1 deployed to:", address(escrow));

        vm.stopBroadcast();
    }
}