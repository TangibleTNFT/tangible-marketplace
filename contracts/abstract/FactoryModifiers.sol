// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "../interfaces/IFactory.sol";
import "../interfaces/IOwnable.sol";
import "../interfaces/ITangibleNFT.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title FactoryModifiers
 * @author Veljko Mihailovic
 * @notice This contract offers permissioned modifiers for contracts that have factory permissioned functions.
 */
abstract contract FactoryModifiers is Initializable, ContextUpgradeable {
    // ~ State Variables ~

    /// @notice Address of  Factory contract.
    address public factory;

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

    // ~ Initialize ~

    function __FactoryModifiers_init(address _factory) internal onlyInitializing {
        require(_factory != address(0), "FP zero");
        factory = _factory;
    }

    // ~ Functions ~

    /**
     * @notice This internal method is used to check if msg.sender is the Factory owner.
     * @dev Only called by modifier `onlyFactoryOwner`. Meant to reduce bytecode size
     */
    function _checkFactoryOwner() internal view {
        require(IOwnable(factory).owner() == msg.sender, "NFO");
    }

    /**
     * @notice This internal method is used to check if msg.sender is the Factory contract.
     * @dev Only called by modifier `onlyFactory`. Meant to reduce bytecode size
     */
    function _checkFactory() internal view {
        require(factory == msg.sender, "NFA");
    }

    /**
     * @notice This internal method is used to check if msg.sender is the category owner.
     * @dev Only called by modifier `onlyCategoryOwner`. Meant to reduce bytecode size
     */
    function _checkCategoryOwner(ITangibleNFT tnft) internal view {
        require(IFactory(factory).categoryOwner(tnft) == msg.sender, "NCO");
    }

    /**
     * @notice This internal method is used to check if msg.sender is the fingerprint approval manager.
     * @dev Only called by modifier `onlyFingerprintApprover`. Meant to reduce bytecode size
     */
    function _checkFingerprintApprover() internal view {
        require(
            IFactory(factory).fingerprintApprovalManager(ITangibleNFT(address(this))) == msg.sender,
            "NFAP"
        );
    }

    /**
     * @notice This internal method is used to check if msg.sender is the Tangible Labs multisig.
     * @dev Only called by modifier `onlyTangibleLabs`. Meant to reduce bytecode size
     */
    function _checkTangibleLabs() internal view {
        require(IFactory(factory).tangibleLabs() == msg.sender, "NLABS");
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}
