// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.19;

import "./interfaces/IOwnable.sol";
import "./interfaces/IRentManager.sol";
import "./interfaces/IFactoryProvider.sol";
import "./interfaces/ITangibleNFT.sol";

import "./abstract/FactoryModifiers.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title Rent Manager
 * @author Caesar LaVey
 * @dev This contract is a system for managing the deposit, vesting, and claiming of rent for NFTs.
 *
 * This contract allows users to deposit rent for specific NFTs, check how much rent is claimable for a token, claim the
 * rent for a token.
 *
 * The system supports regular NFTs (TNFTs).
 *
 * The contract uses a time-based linear vesting system. A user can deposit rent for a token for a specified period of
 * time. The rent then vests linearly over that period, and the owner of the token can claim the vested rent at any time.
 *
 * The contract keeps track of the deposited, claimed, and unclaimed amounts for each token.
 *
 * The contract also provides a function to calculate the claimable rent for a token.
 *
 *
 * The contract emits events for rent deposits.
 *
 * @custom:tester Milica Mihailovic
 */
contract RentManager is IRentManager, FactoryModifiers {
    using EnumerableSet for EnumerableSet.UintSet;
    using Math for uint256;
    using SafeERC20 for IERC20;

    // ~ State Variables ~

    /// @notice Used to store the contract address of the TangibleNFT contract address(this) manages rent for.
    address public immutable TNFT_ADDRESS;

    /// @notice Used to store the address that deposits rent into this contract.
    address public depositor;

    // Mapping: tokenId => RentInfo
    mapping(uint256 => RentInfo) public rentInfo;

    // ~ Events ~

    /**
     * @dev Emitted when rent is deposited for a token.
     *
     * @param depositor The address of the user who deposited the rent.
     * @param tokenId The ID of the token for which rent was deposited.
     * @param rentToken The address of the token used to pay the rent.
     * @param amount The amount of rent deposited.
     */
    event RentDeposited(
        address depositor,
        uint256 indexed tokenId,
        address rentToken,
        uint256 amount
    );

    /**
     * @dev Emitted when rent is claimed for a token.
     *
     * @param claimer The address of the user who claimed the rent.
     * @param nft The address of the NFT contract.
     * @param tokenId The ID of the token for which rent was claimed.
     * @param rentToken The address of the token used to pay the rent.
     * @param amount The amount of rent claimed.
     */
    event RentClaimed(
        address indexed claimer,
        address indexed nft,
        uint256 indexed tokenId,
        address rentToken,
        uint256 amount
    );

    // ~ Constructor ~

    /**
     * @dev Constructor that initializes the TNFT contract address.
     * @param _tnftAddress The address of the TNFT contract.
     */
    constructor(address _tnftAddress, address _factoryProvider) FactoryModifiers(_factoryProvider) {
        require(_tnftAddress != address(0), "TNFT address cannot be 0");
        TNFT_ADDRESS = _tnftAddress;
    }

    // ~ Functions ~

    /**
     * @dev Function to update the address of the rent depositor.
     * Only callable by the owner of the contract.
     * @param _newDepositor The address of the new rent depositor.
     */
    function updateDepositor(
        address _newDepositor
    ) external onlyCategoryOwner(ITangibleNFT(TNFT_ADDRESS)) {
        require(_newDepositor != address(0), "Depositor address cannot be 0");
        depositor = _newDepositor;
    }

    /**
     * @dev Allows the rent depositor to deposit rent for a specific token.
     *
     * This function requires the caller to be the current rent depositor.
     * It also checks whether the specified end time is in the future.
     * If the token's current rent token is either the zero address or the same as the provided token address,
     * the function allows the deposit.
     *
     * The function first transfers the specified amount of the rent token from the depositor to the contract.
     * If the token's rent token is the zero address, it sets the rent token to the provided token address.
     *
     * The function then calculates the token's vested amount.

     * The function then calculates the token's unvested amount, updates the token's unclaimed amount,
     * resets the token's claimed amount, adds the deposit amount to the token's unvested amount,
     * updates the deposit time, and sets the end time.
     *
     * Finally, the function emits a `RentDeposited` event.
     *
     * @param tokenId The ID of the token for which to deposit rent.
     * @param tokenAddress The address of the rent token to deposit.
     * @param amount The amount of the rent token to deposit.
     * @param endTime The end time of the rent deposit.
     */
    function deposit(
        uint256 tokenId,
        address tokenAddress,
        uint256 amount,
        uint256 endTime
    ) external {
        require(msg.sender == depositor, "Only the rent depositor can call this function");
        require(endTime > block.timestamp, "End time must be in the future");
        RentInfo storage rent = rentInfo[tokenId];
        require(
            rent.rentToken == address(0) || rent.rentToken == tokenAddress,
            "Invalid rent token"
        );

        IERC20(tokenAddress).safeTransferFrom(msg.sender, address(this), amount);

        if (rent.rentToken == address(0)) {
            rent.rentToken = tokenAddress;
        }

        uint256 vestedAmount = _vestedAmount(rent);

        uint256 unvestedAmount = rent.depositAmount - vestedAmount;
        rent.unclaimedAmount = vestedAmount - rent.claimedAmount;
        rent.claimedAmount = 0;
        rent.depositAmount = unvestedAmount + amount;
        rent.depositTime = block.timestamp;
        rent.endTime = endTime;

        emit RentDeposited(msg.sender, tokenId, tokenAddress, amount);
    }

    /**
     * @dev Returns the amount of rent that can be claimed for a given token.
     *
     * The function calculates the claimable rent based on the rent info of the token.
     *
     * @param tokenId The ID of the token.
     * @return The amount of claimable rent for the token.
     */
    function claimableRentForToken(uint256 tokenId) public view returns (uint256) {
        RentInfo storage rent = rentInfo[tokenId];
        return rent.unclaimedAmount + _vestedAmount(rent) - rent.claimedAmount;
    }

    /**
     * @dev Allows the owner of a token to claim their rent.
     *
     * The function first checks that the caller is the owner of the token.
     * It then retrieves the amount of claimable rent for the token and requires that the amount is greater than zero,
     * and that the token is either not a TNFT.
     *
     * In both cases, the function updates the claimed and unclaimed amounts of the rent info of the corresponding TNFT
     * token.
     *
     * The function then transfers the claimable rent to the caller and emits a `RentClaimed` event.
     *
     * @param tokenId The ID of the token.
     */
    function claimRentForToken(uint256 tokenId) external {
        IERC721 nftContract = IERC721(TNFT_ADDRESS);
        require(nftContract.ownerOf(tokenId) == msg.sender, "Caller is not the owner of the token");

        uint256 claimableRent = claimableRentForToken(tokenId);
        require(claimableRent > 0, "No rent to claim");

        RentInfo storage rent;

        rent = rentInfo[tokenId];

        if (rent.unclaimedAmount > 0) {
            if (rent.unclaimedAmount < claimableRent) {
                unchecked {
                    rent.claimedAmount += claimableRent - rent.unclaimedAmount;
                    rent.unclaimedAmount = 0;
                }
            } else {
                unchecked {
                    rent.unclaimedAmount -= claimableRent;
                }
            }
        } else {
            rent.claimedAmount += claimableRent;
        }
        IERC20(rent.rentToken).safeTransfer(msg.sender, claimableRent);

        emit RentClaimed(msg.sender, TNFT_ADDRESS, tokenId, rent.rentToken, claimableRent);
    }

    /**
     * @dev Calculates the vested amount for a rent deposit.
     *
     * If the current time is past the end time of the rent period, the function returns the deposit amount.
     * If the current time is before the end time of the rent period, the function calculates the vested amount based on
     * the elapsed time and the vesting duration.
     *
     * @param rent The storage pointer to the rent info of a token.
     * @return The vested amount for the rent deposit.
     */
    function _vestedAmount(RentInfo storage rent) private view returns (uint256) {
        if (block.timestamp >= rent.endTime) {
            return rent.depositAmount;
        } else {
            uint256 elapsedTime = block.timestamp - rent.depositTime;
            uint256 vestingDuration = rent.endTime - rent.depositTime;
            return rent.depositAmount.mulDiv(elapsedTime, vestingDuration);
        }
    }
}
