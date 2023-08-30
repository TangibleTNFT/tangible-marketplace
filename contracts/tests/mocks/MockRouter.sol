// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ERC20Mintable {
    function mint(address _to, uint256 _amount) external;
}

interface IUniswapV2Router02 {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function getAmountsOut(
        uint256 amountIn,
        address[] calldata path
    ) external pure returns (uint256[] memory amounts);
}

contract MockRouter is IUniswapV2Router02 {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address /*to*/,
        uint256 /*deadline*/
    ) external override returns (uint256[] memory amounts) {
        uint256 length = path.length;
        uint256 l = length - 1;

        uint256 amountOut = amountOutMin;

        IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);
        ERC20Mintable(path[l]).mint(msg.sender, amountOut);

        amounts = new uint256[](length);
        amounts[0] = amountIn;
        amounts[l] = amountOut;
    }

    function getAmountsOut(
        uint256 amountIn,
        address[] calldata path
    ) external pure override returns (uint256[] memory amounts) {
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        amounts[path.length - 1] = (amountIn * 1e12) / 10;
    }
}
