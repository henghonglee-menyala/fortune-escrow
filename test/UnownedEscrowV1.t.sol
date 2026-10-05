// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;
import "lib/forge-std/src/Test.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "lib/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "src/UnownedEscrowV1.sol";

contract MockToken is ERC20 {
    constructor(string memory name) ERC20(name, name) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

// Local stand-in for the Uniswap V3 SwapRouter: swaps at a fixed 2:1 rate.
contract MockSwapRouter {
    uint256 public constant RATE = 2;

    function exactInputSingle(ISwapRouter.ExactInputSingleParams calldata p) external returns (uint256 amountOut) {
        amountOut = p.amountIn * RATE;
        require(amountOut >= p.amountOutMinimum, "Too little received");
        IERC20(p.tokenIn).transferFrom(msg.sender, address(this), p.amountIn);
        MockToken(p.tokenOut).mint(p.recipient, amountOut);
    }

    function exactOutputSingle(ISwapRouter.ExactOutputSingleParams calldata p) external returns (uint256 amountIn) {
        amountIn = (p.amountOut + RATE - 1) / RATE;
        require(amountIn <= p.amountInMaximum, "Too much requested");
        IERC20(p.tokenIn).transferFrom(msg.sender, address(this), amountIn);
        MockToken(p.tokenOut).mint(p.recipient, p.amountOut);
    }
}

contract UnownedEscrowV1Test is Test {
    address payable src = payable(makeAddr("src"));
    address payable dest = payable(makeAddr("dest"));
    MockToken srcToken;
    MockToken destToken;
    MockSwapRouter router;
    UnownedEscrowV1 escrow;

    function setUp() public {
        srcToken = new MockToken("SRC");
        destToken = new MockToken("DEST");
        router = new MockSwapRouter();
        escrow = new UnownedEscrowV1(src, dest, srcToken, destToken, ISwapRouter(address(router)));
        srcToken.mint(address(escrow), 100e18);
    }

    function test_FixedSrcSwapThenWithdraw() public {
        uint256 out = escrow.fixedSrcSwap(40e18, 80e18);
        assertEq(out, 80e18);
        assertEq(srcToken.balanceOf(address(escrow)), 60e18);
        assertEq(destToken.balanceOf(address(escrow)), 80e18);

        escrow.withdraw(80e18);
        assertEq(destToken.balanceOf(dest), 80e18);
    }

    function test_FixedSrcSwapRevertsBelowMinimum() public {
        vm.expectRevert("Too little received");
        escrow.fixedSrcSwap(40e18, 81e18);
    }

    function test_FixedDestSwap() public {
        escrow.fixedDestSwap(50e18, 30e18);
        assertEq(srcToken.balanceOf(address(escrow)), 85e18);
        assertEq(destToken.balanceOf(address(escrow)), 30e18);
    }

    function test_RefundReturnsBothBalances() public {
        escrow.fixedSrcSwap(10e18, 20e18);
        escrow.refund();
        assertEq(srcToken.balanceOf(src), 90e18);
        assertEq(destToken.balanceOf(dest), 20e18);
        assertEq(srcToken.balanceOf(address(escrow)), 0);
        assertEq(destToken.balanceOf(address(escrow)), 0);
    }
}
