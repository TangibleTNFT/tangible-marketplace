// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.19;

import "./interfaces/ITangiblePriceManager.sol";
import "./abstract/FactoryModifiers.sol";

/**
 * @title TangiblePriceManager
 * @author Veljko Mihailovic
 * @notice This contract is used to facilitate the fetching/response of TangibleNFT prices
 */
contract TangiblePriceManagerV2 is ITangiblePriceManager, FactoryModifiers {
    // ~ State Variables ~

    /// @notice This maps TangibleNFT contracts to it's corresponding oracle.
    mapping(ITangibleNFT => IPriceOracle) public oracleForCategory;

    // ~ Events ~

    /// @notice This event is emitted when the `oracleForCategory` variable is updated.
    event CategoryPriceOracleAdded(address indexed category, address indexed priceOracle);

    /**
     * @notice Initialized TangiblePriceManager.
     * @param _factoryProvider Factory provider contract address.
     */
    constructor(address _factoryProvider) FactoryModifiers(_factoryProvider) {}

    /**
     * @notice The function is used to set oracle contracts in the `oracleForCategory` mapping.
     * @param category TangibleNFT contract.
     * @param oracle PriceOracle contract.
     */
    function setOracleForCategory(
        ITangibleNFT category,
        IPriceOracle oracle
    ) external override onlyFactory {
        require(address(category) != address(0), "Zero category");
        require(address(oracle) != address(0), "Zero oracle");

        oracleForCategory[category] = oracle;
        emit CategoryPriceOracleAdded(address(category), address(oracle));
    }

    /**
     * @notice This function fetches pricing data for an array of products.
     * @param nft TangibleNFT contract reference.
     * @param paymentUSDToken Token being used as payment.
     * @param fingerprints Array of token fingerprints data.
     * @return weSellAt -> Price of item in oracle, market price.
     * @return weSellAtStock -> Stock of the item.
     * @return tokenizationCost -> Tokenization costs for tokenizing asset. Real Estate will never be 0.
     */
    function itemPriceBatchFingerprints(
        ITangibleNFT nft,
        IERC20Metadata paymentUSDToken,
        uint256[] calldata fingerprints
    )
        external
        view
        returns (
            uint256[] memory weSellAt,
            uint256[] memory weSellAtStock,
            uint256[] memory tokenizationCost
        )
    {
        (weSellAt, weSellAtStock, tokenizationCost) = _itemBatchPrices(
            nft,
            paymentUSDToken,
            fingerprints,
            true
        );
    }

    /**
     * @notice This function fetches pricing data for an array of tokenIds.
     * @param nft TangibleNFT contract reference.
     * @param paymentUSDToken Token being used as payment.
     * @param tokenIds Array of tokenIds.
     * @return weSellAt -> Price of item in oracle, market price.
     * @return weSellAtStock -> Stock of the item.
     * @return tokenizationCost -> Tokenization costs for tokenizing asset. Real Estate will never be 0.
     */
    function itemPriceBatchTokenIds(
        ITangibleNFT nft,
        IERC20Metadata paymentUSDToken,
        uint256[] calldata tokenIds
    )
        external
        view
        returns (
            uint256[] memory weSellAt,
            uint256[] memory weSellAtStock,
            uint256[] memory tokenizationCost
        )
    {
        (weSellAt, weSellAtStock, tokenizationCost) = _itemBatchPrices(
            nft,
            paymentUSDToken,
            tokenIds,
            false
        );
    }

    /**
     * @notice This internal function fetches pricing data for an array of tokens or products from the designated oracle.
     * @param nft TangibleNFT contract reference.
     * @param paymentUSDToken Token being used as payment -> Will be used to depict USD quote.
     * @param data Array of token data. Can be tokenIds or fingerprints.
     * @param fromFingerprints If true, `data` will be an array of fingerprints, otherwise it'll be tokenIds.
     * @return weSellAtArr -> Array of market prices per item in `data`.
     * @return weSellAtStockArr -> Array of stock per item in `data`.
     * @return tokenizationCostArr -> Array of tokenization costs per item in `data`.
     */
    function _itemBatchPrices(
        ITangibleNFT nft,
        IERC20Metadata paymentUSDToken,
        uint256[] calldata data,
        bool fromFingerprints
    )
        internal
        view
        returns (
            uint256[] memory weSellAtArr,
            uint256[] memory weSellAtStockArr,
            uint256[] memory tokenizationCostArr
        )
    {
        uint256 length = data.length;
        weSellAtArr = new uint256[](length);
        weSellAtStockArr = new uint256[](length);
        tokenizationCostArr = new uint256[](length);
        for (uint256 i; i < length; ) {
            (
                uint256 _weSellAt,
                uint256 _weSellAtStock,
                uint256 _tokenizationCost
            ) = fromFingerprints
                    ? oracleForCategory[nft].usdPrice(nft, paymentUSDToken, data[i], 0)
                    : oracleForCategory[nft].usdPrice(nft, paymentUSDToken, 0, data[i]);

            weSellAtArr[i] = _weSellAt;
            weSellAtStockArr[i] = _weSellAtStock;
            tokenizationCostArr[i] = _tokenizationCost;

            unchecked {
                ++i;
            }
        }
    }
}
