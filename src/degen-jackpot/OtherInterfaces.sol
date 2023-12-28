// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// for FNFTHandler
interface IFNFTHandler {
    function getSupply(uint256 fnftId) external view returns (uint256);
    function getBalance(address tokenHolder, uint256 id) external view returns (uint256);
    function getNextId() external view returns (uint256);
    function mint(address account, uint256 id, uint256 amount, bytes memory data) external;
    function burn(address account, uint256 id, uint256 amount) external;
    function mintBatchRec(
        address[] memory recipients,
        uint256[] memory quantities,
        uint256 id,
        uint256 newSupply,
        bytes memory data
    ) external;
    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) external;
    function burnBatch(address account, uint256[] memory ids, uint256[] memory amounts) external;
}

// for LockManager
interface ILockManager {
    function createLock(uint256 fnftId, IRevest.LockParam memory lock) external returns (uint256);
    function getLock(uint256 lockId) external view returns (IRevest.Lock memory);
    function fnftIdToLockId(uint256 fnftId) external view returns (uint256);
    function fnftIdToLock(uint256 fnftId) external view returns (IRevest.Lock memory);
    function lockTypes(uint256 tokenId) external view returns (IRevest.LockType);
    function unlockFNFT(uint256 fnftId, address sender) external returns (bool);
    function getLockMaturity(uint256 fnftId) external view returns (bool);
    function pointFNFTToLock(uint256 fnftId, uint256 lockId) external;
}

// for Revest
interface IRevest {
    struct FNFTConfig {
        address asset; // The token being stored
        uint256 depositAmount; // How many tokens
        uint256 depositMul; // Deposit multiplier
    }

    enum LockType {
        DoesNotExist,
        AddressLock
    }

    struct LockParam {
        address addressLock;
        LockType lockType;
    }

    struct Lock {
        address addressLock;
        LockType lockType;
        bool unlocked;
    }
    // Refers to the global balance for an ERC20, encompassing possibly many FNFTs

    struct TokenTracker {
        uint256 lastBalance;
        uint256 lastMul;
    }

    function mintAddressLock(
        address trigger,
        bytes memory arguments,
        address[] memory recipients,
        uint256[] memory quantities,
        IRevest.FNFTConfig memory fnftConfig
    ) external returns (uint256);
    function withdrawFNFT(uint256 tokenUID, uint256 quantity) external;
    function unlockFNFT(uint256 tokenUID) external;
    function depositAdditionalToFNFT(uint256 fnftId, uint256 amount, uint256 quantity) external returns (uint256);
}

// for TokenVault
interface ITokenVault {
    function createFNFT(uint256 fnftId, IRevest.FNFTConfig memory fnftConfig, uint256 quantity, address from)
        external;
    function withdrawToken(uint256 fnftId, uint256 quantity, address user) external;
    function depositToken(uint256 fnftId, uint256 amount, uint256 quantity) external;
    function mapFNFTToToken(uint256 fnftId, IRevest.FNFTConfig memory fnftConfig) external;
    function handleMultipleDeposits(uint256 fnftId, uint256 newFNFTId, uint256 amount) external;
    function getFNFT(uint256 fnftId) external view returns (IRevest.FNFTConfig memory);
}

// functionality to get addresses for all relevant contracts & admin
interface IAddressRegistry {
    function getAdmin() external view returns (address); // setAdmin done with Ownable
    function getLockManager() external view returns (address);
    function setLockManager(address manager) external;
    function getTokenVault() external view returns (address);
    function setTokenVault(address vault) external;
    function getRevestFNFT() external view returns (address);
    function setRevestFNFT(address fnft) external;
    function getRevest() external view returns (address);
    function setRevest(address revest) external;
}
