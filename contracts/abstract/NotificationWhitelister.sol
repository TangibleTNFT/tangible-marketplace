// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "./FactoryModifiers.sol";
import "../interfaces/ITangibleNFT.sol";

abstract contract NotificationWhitelister is FactoryModifiers {

    // ~ State Variables ~
    /// @notice mapping of tnft tokenIds to addresses that are registered for notification
    mapping(address => mapping(uint256 => address)) public registeredForNotification;

    /// @notice mapping of whitelisted addresses that can register for notification
    mapping(address => bool) public whitelistedReceiver;

    /// @notice  tnft for which tokens are registered for notification
    ITangibleNFT public tnft;

    function __NotificationWhitelister_init(address _factory) internal onlyInitializing {
        __FactoryModifiers_init(_factory);
    }

    /**
     *
     * @param receiver Address that will be whitelisted
     */
    function whitelistAddressAndReceiver(
        address receiver
    ) external onlyCategoryOwner(ITangibleNFT(tnft)) {
        require(!whitelistedReceiver[receiver], "Already whitelisted");
        whitelistedReceiver[receiver] = true;
    }

    /**
     *
     * @param receiver Address that will be blacklisted
     */
    function blacklistAddress(address receiver) external onlyCategoryOwner(ITangibleNFT(tnft)) {
        require(whitelistedReceiver[receiver], "Not whitelisted");
        whitelistedReceiver[receiver] = false;
    }

    /**
     *
     * @param tokenId TokenId for which the address will be registered for notification
     */
    function registerForNotification(
        uint256 tokenId
    ) external {
        require(whitelistedReceiver[msg.sender], "Not whitelisted");
        require(tnft.ownerOf(tokenId) == msg.sender, "Not owner");
        registeredForNotification[address(tnft)][tokenId] = msg.sender;
    }

    /**
     *
     * @param tokenId TokenId for which the address will be unregistered for notification
     */
    function unregisterForNotification(
        uint256 tokenId
    ) external {
        require(whitelistedReceiver[msg.sender], "Not whitelisted");
        require(tnft.ownerOf(tokenId) == msg.sender, "Not owner");
        delete registeredForNotification[address(tnft)][tokenId];
    }

}