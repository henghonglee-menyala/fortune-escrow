// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.0 <0.9.0;
import "lib/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "lib/v3-periphery/contracts/libraries/TransferHelper.sol";


import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract UnownedEscrowV1 {
    using SafeERC20 for IERC20;
    address payable public src;
    address payable public dest;
    IERC20 public srcToken;
    IERC20 public destToken;
    ISwapRouter public immutable swapRouter;
    // For this example, we will set the pool fee to 0.3%.
    uint24 public constant poolFee = 3000;

    event SrcTokenDeposited();
    event DestTokenWithdrawn(uint256 amountOut);
    event Refunded();

    constructor(
        address payable _src,
        address payable _dest,
        IERC20 _srcToken,
        IERC20 _destToken,
        ISwapRouter _swapRouter
    ) {
        swapRouter = _swapRouter;
        src = _src;
        dest = _dest;
        srcToken = _srcToken;
        destToken = _destToken;
    }

    // this assumes the srcToken has already been deposited
    function fixedSrcSwapAndSend(uint256 amountIn, uint256 amountOut) public returns (uint256) {
        emit SrcTokenDeposited();
        TransferHelper.safeApprove(address(srcToken), address(swapRouter), amountIn);
        uint256 actualOut = swapRouter.exactInputSingle(ISwapRouter.ExactInputSingleParams({
                tokenIn: address(srcToken),
                tokenOut: address(destToken),
                fee: poolFee,
                recipient: dest,
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: amountOut,
                sqrtPriceLimitX96: 0
            }));
        // actual out might be MORE than amountOut
        emit DestTokenWithdrawn(actualOut);
        return actualOut;
    }

    // this assumes the srcToken has already been deposited
    function fixedDestSwapAndSend(uint256 amountIn, uint256 amountOut) public returns (uint256) {
        emit SrcTokenDeposited();
        TransferHelper.safeApprove(address(srcToken), address(swapRouter), amountIn);
        uint256 actualOut = swapRouter.exactOutputSingle(ISwapRouter.ExactOutputSingleParams({
                tokenIn: address(srcToken),
                tokenOut: address(destToken),
                fee: poolFee,
                recipient: dest,
                deadline: block.timestamp,
                amountOut: amountOut,
                amountInMaximum: amountIn,
                sqrtPriceLimitX96: 0
            }));
        // actual out might be MORE than amountOut
        emit DestTokenWithdrawn(actualOut);
        return actualOut;
    }
    

    function refund() public returns (bool) {
        uint256 balance = srcToken.balanceOf(address(this));
        srcToken.safeTransfer(src, balance);
        emit Refunded();
        return true;
    }
}
