// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IBondingCurve {
    function calculatePurchaseReturn(
        uint256 _supply,
        uint256 _reserveBalance,
        uint32 _reserveRatio,
        uint256 _depositAmount
    ) external view returns (uint256);
    function calculateSaleReturn(uint256 _supply, uint256 _reserveBalance, uint32 _reserveRatio, uint256 _sellAmount)
        external
        view
        returns (uint256);
}

interface IEminenceCurrency is IERC20 {
    function award(address _to, uint256 _amount) external;
    function claim(address _from, uint256 _amount) external;
    function addGM(address _gm) external;
    function buy(uint256 _amount, uint256 _min) external returns (uint256 _bought);
    function sell(uint256 _amount, uint256 _min) external returns (uint256 _bought);
}
