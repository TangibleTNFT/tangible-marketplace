// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.19;

import "./RentManager.sol";
import "./interfaces/IRentManager.sol";
import "./interfaces/IRentManagerDeployer.sol";
import "./interfaces/IOwnable.sol";
import "./interfaces/IFactoryProvider.sol";
import "./abstract/FactoryModifiers.sol";

/**
 * @title RentManagerDeployer
 * @author Veljko Mihailovic
 * @notice This contract is used to deploy new RentManager contracts.
 */
contract RentManagerDeployer is IRentManagerDeployer, FactoryModifiers {
    // ~ Constructor ~

    /**
     * @notice Initializes the RentManagerDeployer contract.
     * @param _factoryProvider Address for the FactoryProvider contract.
     */
    constructor(address _factoryProvider) FactoryModifiers(_factoryProvider) {}

    // ~ Functions ~

    /**
     * @notice This method will deploy a new RentManager contract.
     * @param tnft Address of TangibleNFT contract the new RentManager will manage rent for.
     * @return Returns a reference to the new RentManager.
     */
    function deployRentManager(address tnft) external returns (IRentManager) {
        require(msg.sender == IFactoryProvider(factoryProvider).factory(), "NF");
        RentManager rentManager = new RentManager(tnft, factoryProvider);

        return IRentManager(address(rentManager));
    }
}
