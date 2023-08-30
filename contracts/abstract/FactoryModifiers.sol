// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.19;

import "../interfaces/IFactory.sol";
import "../interfaces/IOwnable.sol";
import "../interfaces/IFactoryProvider.sol";
import "../interfaces/ITangibleNFT.sol";

/**
 * @title FactoryModifiers
 * @author Tangible.store
 * @notice This contract offers permissioned modifiers for contracts that have factory permissioned functions.
 */
abstract contract FactoryModifiers {
    // ~ State Variables ~

    /// @notice Address of FactoryProvider contract.
    address public factoryProvider;

    // ~ Modifiers ~

    /// @notice This modifier is used to verify msg.sender is the factory contract owner.
    modifier onlyFactoryOwner() {
        _checkFactoryOwner();
        _;
    }

    /// @notice This modifier is used to verify msg.sender is the Factory contract.
    modifier onlyFactory() {
        _checkFactory();
        _;
    }

    /// @notice This modifier is used to verify msg.sender is the category owner.
    modifier onlyCategoryOwner(ITangibleNFT tnft) {
        _checkCategoryOwner(tnft);
        _;
    }

    /// @notice This modifier is used to verify msg.sender is approval manager.
    modifier onlyFingerprintApprover() {
        _checkFingerprintApprover();
        _;
    }

    /// @notice This modifier is used to verify msg.sender is the tangible labs multisig.
    modifier onlyTangibleLabs() {
        _checkTangibleLabs();
        _;
    }

    // ~ Constructor ~

    constructor(address _factoryProvider) {
        require(_factoryProvider != address(0), "FP zero");
        factoryProvider = _factoryProvider;
    }

    // ~ Functions ~

    /**
     * @notice This internal method is used to check if msg.sender is the Factory owner.
     * @dev Only called by modifier `onlyFactoryOwner`. Meant to reduce bytecode size
     */
    function _checkFactoryOwner() internal view {
        require(
            IOwnable(IFactoryProvider(factoryProvider).factory()).contractOwner() == msg.sender,
            "NFO"
        );
    }

    /**
     * @notice This internal method is used to check if msg.sender is the Factory contract.
     * @dev Only called by modifier `onlyFactory`. Meant to reduce bytecode size
     */
    function _checkFactory() internal view {
        require(IFactoryProvider(factoryProvider).factory() == msg.sender, "NFA");
    }

    /**
     * @notice This internal method is used to check if msg.sender is the category owner.
     * @dev Only called by modifier `onlyCategoryOwner`. Meant to reduce bytecode size
     */
    function _checkCategoryOwner(ITangibleNFT tnft) internal view {
        require(
            IFactory(IFactoryProvider(factoryProvider).factory()).categoryOwner(tnft) == msg.sender,
            "NCO"
        );
    }

    /**
     * @notice This internal method is used to check if msg.sender is the fingerprint approval manager.
     * @dev Only called by modifier `onlyFingerprintApprover`. Meant to reduce bytecode size
     */
    function _checkFingerprintApprover() internal view {
        require(
            IFactory(IFactoryProvider(factoryProvider).factory()).fingerprintApprovalManager(
                ITangibleNFT(address(this))
            ) == msg.sender,
            "NFAP"
        );
    }

    /**
     * @notice This internal method is used to check if msg.sender is the Tangible Labs multisig.
     * @dev Only called by modifier `onlyTangibleLabs`. Meant to reduce bytecode size
     */
    function _checkTangibleLabs() internal view {
        require(
            IFactory(IFactoryProvider(factoryProvider).factory()).tangibleLabs() == msg.sender,
            "NLABS"
        );
    }
}
