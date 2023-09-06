// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title FactoryProvider
 * @author Veljko Mihailovic
 * @notice This contract is used to store the Factory address.
 */
contract FactoryProvider is OwnableUpgradeable {
    // ~ State Variables ~

    /// @notice Stores address of factory contract.
    address public factory;

    // ~ Events ~

    /// @notice This event is emitted when the `factory` variable is updated.
    event FactorySet(address oldFactory, address newFactory);

    // ~ Functions

    /**
     * @notice This function is used to initialize the contract.
     * @param _factory Factory address.
     */
    function initialize(address _factory) external initializer {
        __Ownable_init();
        factory = _factory;
    }

    /**
     * @notice This function is used to update the `factory` variable.
     * @param _factory Factory address to set.
     */
    function setFactory(address _factory) external onlyOwner {
        require(_factory != address(0), "Fac 0");
        emit FactorySet(factory, _factory);
        factory = _factory;
    }
}
