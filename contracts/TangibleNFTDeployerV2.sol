// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.19;

import "./TangibleNFTV2.sol";
import "./interfaces/ITangibleNFTDeployer.sol";
import "./abstract/FactoryModifiers.sol";

/**
 * @title TangibleNFTDeployer
 * @author Veljko Mihailovic
 * @notice This contract is used to deploy new TangibleNFT contracts.
 */
contract TangibleNFTDeployerV2 is ITangibleNFTDeployer, FactoryModifiers {
    // ~ Constructor ~

    /**
     * @notice Initializes the TangibleNFTDeployer contract
     * @param _factoryProvider Address for the FactoryProvider contract.
     */
    constructor(address _factoryProvider) FactoryModifiers(_factoryProvider) {}

    // ~ Functions ~
    /**
     * @notice This method will deploy a new TangibleNFT contract.
     * @return Returns a reference to the new TangibleNFT contract.
     */
    function deployTnft(
        string calldata name,
        string calldata symbol,
        string calldata uri,
        bool isStoragePriceFixedAmount,
        bool storageRequired,
        bool _symbolInUri,
        uint256 _tnftType
    ) external returns (ITangibleNFT) {
        require(msg.sender == IFactoryProvider(factoryProvider).factory(), "NF");
        TangibleNFTV2 tangibleNFT = new TangibleNFTV2(
            factoryProvider,
            name,
            symbol,
            uri,
            isStoragePriceFixedAmount,
            storageRequired,
            _symbolInUri,
            _tnftType
        );

        return ITangibleNFT(address(tangibleNFT));
    }
}
