// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.19;

import "./interfaces/ITangibleMarketplace.sol";
import "./interfaces/IWETH9.sol";
import "./interfaces/ISellFeeDistributor.sol";
import "./interfaces/IOwnable.sol";
import "./interfaces/IOnSaleTracker.sol";
import "./interfaces/IVoucher.sol";

import "./interfaces/IFactoryProvider.sol";
import "./interfaces/IOwnable.sol";
import "./abstract/FactoryModifiers.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

/**
 * @title Marketplace
 * @author Tangible.store
 * @notice This smart contract facilitates the buying and selling of Tangible NFTs.
 */
contract TNFTMarketplaceV2 is ITangibleMarketplace, IERC721Receiver, FactoryModifiers {
    using SafeERC20 for IERC20;

    // ~ State Variables ~

    /// @notice This constant stores the default sell fee of 2.5% (2 basis points).
    uint256 public constant DEFAULT_SELL_FEE = 250;

    /// @notice This mapping is used to store Lot data for each token listed on the marketplace.
    mapping(address => mapping(uint256 => Lot)) public marketplaceLot;

    /// @notice This stores the address where sell fees are allocated to.
    address public sellFeeAddress;

    /// @notice OnSaleTracker contract reference.
    IOnSaleTracker public onSaleTracker;

    /// @notice This mapping is used to store the marketplace fees attached to each category of TNFTs.
    /// @dev The fees use 2 basis points for precision (i.e. 15% == 1500 // 2.5% == 250).
    mapping(ITangibleNFT => uint256) public feesPerCategory;

    // ~ Events ~

    /**
     * @notice This event is emitted when the marketplace fee is paid by a buyer.
     * @param nft Address of TangibleNFT contract.
     * @param tokenId TNFT identifier.
     * @param feeAmount Fee amount paid.
     */
    event MarketplaceFeePaid(address indexed nft, uint256 indexed tokenId, uint256 feeAmount);

    /**
     * @notice This event is emitted when a TNFT is listed for sale.
     * @param seller The original owner of the token.
     * @param nft Address of TangibleNFT contract.
     * @param tokenId TNFT identifier.
     * @param price Price TNFT is listed at.
     */
    event Selling(
        address indexed seller,
        address indexed nft,
        uint256 indexed tokenId,
        uint256 price
    );

    /**
     * @notice This event is emitted when a token that was listed for sale is stopped by the owner.
     * @param seller The owner of the token.
     * @param nft Address of TangibleNFT contract.
     * @param tokenId TNFT identifier.
     */
    event StopSelling(address indexed seller, address indexed nft, uint256 indexed tokenId);

    /**
     * @notice This event is emitted when a TNFT has been purchased from the marketplace.
     * @param buyer Address of EOA that purchased the TNFT
     * @param nft Address of TangibleNFT contract.
     * @param tokenId TNFT identifier.
     * @param price Price at which the token was purchased.
     */
    event TnftSold(
        address indexed buyer,
        address indexed nft,
        uint256 indexed tokenId,
        address seller,
        uint256 price
    );

    /**
     * @notice This event is emitted when `sellFeeAddress` is updated.
     * @param oldFeeAddress The previous `sellFeeAddress`.
     * @param newFeeAddress The new `sellFeeAddress`.
     */
    event SellFeeAddressSet(address indexed oldFeeAddress, address indexed newFeeAddress);

    /**
     * @notice This event is emitted when the value stored in `onSaleTracker` is updated
     * @param oldSaleTracker The previous address stored in `onSaleTracker`.
     * @param newSaleTracker The new address stored in `onSaleTracker`.
     */
    event SaleTrackerSet(address indexed oldSaleTracker, address indexed newSaleTracker);

    /**
     * @notice This event is emitted when there is an update to `feesPerCategory`.
     * @param nft TangibleNFT contract reference.
     * @param oldFee Previous fee.
     * @param newFee New fee.
     */
    event SellFeeChanged(ITangibleNFT indexed nft, uint256 oldFee, uint256 newFee);

    /**
     * @notice This event is emitted when the `factory` global variable is updated.
     * @param oldFactory Previous `factory` address.
     * @param newFactory New `factory` address.
     */
    event FactorySet(address indexed oldFactory, address indexed newFactory);

    /**
     * @notice This event is emitted when we have a successful execution of `_payStorage`.
     * @param payer Address of account that paid for storage.
     * @param nft Address of TangibleNFT contract.
     * @param tokenId NFT identifier.
     * @param paymentToken Address of Erc20 token that was accepted as payment.
     * @param amount Amount quoted for storage.
     */
    event StorageFeePaid(
        address indexed payer,
        address indexed nft,
        uint256 indexed tokenId,
        address paymentToken,
        uint256 amount
    );

    // ~ Constructor ~
    /**
     * @notice Initializes Marketplace contract.
     * @param _factoryProvider Address of Factory provider contract
     */
    constructor(address _factoryProvider) FactoryModifiers(_factoryProvider) {}

    // ~ Functions ~

    /**
     * @notice This function is used to list a batch of TNFTs at once instead of one at a time.
     * @dev This function allows anyone to sell a batch of TNFTs they own.
     *      If `price` is 0, refer to the Pricing Oracle for the price.
     * @param nft TangibleNFT contract reference.
     * @param paymentToken Erc20 token being used as payment.
     * @param tokenIds Array of tokenIds to sell.
     * @param price Price per token.
     */
    function sellBatch(
        ITangibleNFT nft,
        IERC20 paymentToken,
        uint256[] calldata tokenIds,
        uint256[] calldata price
    ) external {
        IFactory factory = IFactory(IFactoryProvider(factoryProvider).factory());
        require(factory.paymentTokens(paymentToken), "NAT");
        uint256 length = tokenIds.length;
        for (uint256 i; i < length; ) {
            _sell(nft, paymentToken, tokenIds[i], price[i]);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice This function is used to update the `onSaleTracker::tnftSalePlaced()` tracker state.
     * @param tnft TangibleNFT contract reference.
     * @param tokenId TNFT identifier.
     * @param placed If true, the token is being listed for sale, otherwise false.
     */
    function _updateTrackerTnft(ITangibleNFT tnft, uint256 tokenId, bool placed) internal {
        onSaleTracker.tnftSalePlaced(tnft, tokenId, placed);
    }

    /**
     * @notice This internal function is called when a TNFT is listed for sale on the marketplace.
     * @param nft TangibleNFT contract reference.
     * @param paymentToken Erc20 token being accepted as payment by seller.
     * @param tokenId TNFT token identifier.
     * @param price Price the token is being listed for.
     */
    function _sell(ITangibleNFT nft, IERC20 paymentToken, uint256 tokenId, uint256 price) internal {
        //check who is the owner
        address ownerOfNft = nft.ownerOf(tokenId);
        //if marketplace is owner and seller wants to update price
        if (
            (address(this) == ownerOfNft) &&
            (msg.sender == marketplaceLot[address(nft)][tokenId].seller)
        ) {
            marketplaceLot[address(nft)][tokenId].price = price;
        } else {
            //here we don't need to check, if not approved trx will fail
            nft.safeTransferFrom(msg.sender, address(this), tokenId, abi.encode(price));

            // set the desired payment token
            marketplaceLot[address(nft)][tokenId].paymentToken = paymentToken;
        }
    }

    /**
     * @notice This is a restricted function for updating the `onSaleTracker` contract reference.
     * @param _onSaleTracker The new OnSaleTracker contract.
     */
    function setOnSaleTracker(IOnSaleTracker _onSaleTracker) external onlyFactoryOwner {
        emit SaleTrackerSet(address(onSaleTracker), address(_onSaleTracker));
        onSaleTracker = _onSaleTracker;
    }

    /**
     * @notice This is a restricted function to update the `feesPerCategory` mapping.
     * @param tnft TangibleNFT contract reference aka category of TNFTs.
     * @param fee New fee to charge for category.
     */
    function setFeeForCategory(ITangibleNFT tnft, uint256 fee) external onlyCategoryOwner(tnft) {
        emit SellFeeChanged(tnft, feesPerCategory[tnft], fee);
        feesPerCategory[tnft] = fee;
    }

    /**
     * @notice This function allows a TNFT owner to stop the sale of their TNFTs batch.
     * @param nft TangibleNFT contract reference.
     * @param tokenIds Array of tokenIds.
     */
    function stopBatchSale(ITangibleNFT nft, uint256[] calldata tokenIds) external {
        uint256 length = tokenIds.length;

        for (uint256 i; i < length; ) {
            _stopSale(nft, tokenIds[i]);

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice This function stops the sale of a TNFT and transfers it back to it's original owner.
     * @param nft TangibleNFT contract reference.
     * @param tokenId Array of tokenIds.
     */
    function _stopSale(ITangibleNFT nft, uint256 tokenId) internal {
        address seller = msg.sender;
        // gas saving
        Lot memory _lot = marketplaceLot[address(nft)][tokenId];
        require(_lot.seller == seller, "NOS");

        emit StopSelling(seller, address(nft), tokenId);
        delete marketplaceLot[address(nft)][tokenId];
        //update tracker
        _updateTrackerTnft(nft, tokenId, false);

        IERC721(nft).safeTransferFrom(address(this), _lot.seller, _lot.tokenId);
    }

    /**
     * @notice This function allows the user to buy any TangibleNFT that is listed on Marketplace.
     * @param nft TangibleNFT contract reference.
     * @param tokenId TNFT identifier.
     * @param _years Num of years to pay for storage.
     */
    function buy(ITangibleNFT nft, uint256 tokenId, uint256 _years) external {
        //pay for storage
        if ((!nft.isStorageFeePaid(tokenId) || _years > 0) && nft.storageRequired()) {
            require(_years > 0, "YZ");
            _payStorage(
                nft,
                IERC20Metadata(address(marketplaceLot[address(nft)][tokenId].paymentToken)),
                tokenId,
                _years
            );
        }
        //buy the token
        _buy(nft, tokenId, true);
    }

    /**
     * @notice The function which buys additional storage for the token.
     * @param nft TangibleNFT contract reference.
     * @param paymentToken Erc20 token being used to pay for storage.
     * @param tokenId TNFT identifier.
     * @param _years Num of years to pay for storage.
     */
    function payStorage(
        ITangibleNFT nft,
        IERC20Metadata paymentToken,
        uint256 tokenId,
        uint256 _years
    ) external {
        _payStorage(nft, paymentToken, tokenId, _years);
    }

    /**
     * @notice This internal function updates the storage tracker on the factory and charges the owner for quoted storage.
     * @param nft TangibleNFT contract reference.
     * @param paymentToken Erc20 token reference being used as payement for storage.
     * @param tokenId TNFT identifier.
     * @param _years Num of years to extend storage for.
     */
    function _payStorage(
        ITangibleNFT nft,
        IERC20Metadata paymentToken,
        uint256 tokenId,
        uint256 _years
    ) internal {
        require(nft.storageRequired(), "STNR");
        require(_years > 0, "YZ");

        IFactory factory = IFactory(IFactoryProvider(factoryProvider).factory());

        uint256 amount = factory.adjustStorageAndGetAmount(nft, paymentToken, tokenId, _years);
        //we take in default USD token
        IERC20(address(paymentToken)).safeTransferFrom(
            msg.sender,
            factory.categoryOwner(nft),
            amount
        );
        emit StorageFeePaid(msg.sender, address(nft), tokenId, address(paymentToken), amount);
    }

    /**
     * @notice This funcion allows accounts to purchase whitelisted tokens or receive vouchers for unminted tokens.
     * @param nft TangibleNFT contract reference.
     * @param paymentToken Erc20 token being used as payment.
     * @param _fingerprint Fingerprint of token.
     * @param _years Num of years to store item in advance.
     */
    function buyUnminted(
        ITangibleNFT nft,
        IERC20 paymentToken,
        uint256 _fingerprint,
        uint256 _years
    ) external returns (uint256 tokenId) {
        IFactory factory = IFactory(IFactoryProvider(factoryProvider).factory());
        if (factory.onlyWhitelistedForUnmintedCategory(nft)) {
            require(factory.whitelistForBuyUnminted(nft, msg.sender), "NW");
        }

        if (address(paymentToken) == address(0)) {
            paymentToken = factory.defUSD();
        }
        require(factory.paymentTokens(paymentToken), "TNAPP");
        //buy unminted is always initial sale!!
        // need to also fetch stock here!! and remove remainingMintsForVendor
        (uint256 tokenPrice, uint256 stock, uint256 tokenizationCost) = _itemPrice(
            nft,
            IERC20Metadata(address(paymentToken)),
            _fingerprint,
            true
        );

        require(((tokenPrice + tokenizationCost) > 0) && (stock > 0), "!0S");

        MintVoucher memory voucher = MintVoucher({
            token: nft,
            mintCount: 1,
            price: 0,
            vendor: factory.categoryOwner(nft),
            buyer: msg.sender,
            fingerprint: _fingerprint,
            sendToVendor: false
        });
        uint256[] memory tokenIds = factory.mint(voucher);
        tokenId = tokenIds[0];
        //pay for storage
        if (nft.storageRequired()) {
            _payStorage(nft, IERC20Metadata(address(paymentToken)), tokenId, _years);
        }

        marketplaceLot[address(nft)][tokenId].paymentToken = paymentToken;
        //pricing should be handled from oracle
        _buy(voucher.token, tokenIds[0], false);
    }

    /**
     * @notice This function is used to return the price for the `data` item provided.
     * @param nft TangibleNFT contract reference.
     * @param paymentUSDToken Erc20 token being used as payment.
     * @param data Token identifier, will be a fingerprint or a tokenId.
     * @param fromFingerprints If true, `data` will be a fingerprint, othwise it'll be a tokenId.
     * @return weSellAt -> Price of item in oracle, market price.
     * @return weSellAtStock -> Stock of the item.
     * @return tokenizationCost -> Tokenization costs for tokenizing asset. Real Estate will never be 0.
     */
    function _itemPrice(
        ITangibleNFT nft,
        IERC20Metadata paymentUSDToken,
        uint256 data,
        bool fromFingerprints
    ) internal view returns (uint256 weSellAt, uint256 weSellAtStock, uint256 tokenizationCost) {
        IFactory factory = IFactory(IFactoryProvider(factoryProvider).factory());
        return
            fromFingerprints
                ? factory.priceManager().oracleForCategory(nft).usdPrice(
                    nft,
                    paymentUSDToken,
                    data,
                    0
                )
                : factory.priceManager().oracleForCategory(nft).usdPrice(
                    nft,
                    paymentUSDToken,
                    0,
                    data
                );
    }

    /**
     * @notice This internal function is used to update marketplace state when an account buys a listed TNFT.
     * @param nft TangibleNFT contract reference.
     * @param tokenId TNFT identifier to buy.
     * @param chargeFee If true, a fee will be charged from buyer.
     */
    function _buy(ITangibleNFT nft, uint256 tokenId, bool chargeFee) internal {
        // gas saving
        address buyer = msg.sender;

        Lot memory _lot = marketplaceLot[address(nft)][tokenId];
        require(_lot.seller != address(0), "NLO");
        IERC20 pToken = _lot.paymentToken;

        // if lot.price == 0 it means vendor minted it, we must take price from oracle
        // if lot.price != 0 means some seller posted it and didn't want to use oracle
        uint256 cost = _lot.price;
        uint256 tokenizationCost;
        if (cost == 0) {
            (cost, , tokenizationCost) = _itemPrice(
                nft,
                IERC20Metadata(address(pToken)),
                tokenId,
                false
            );
            cost += tokenizationCost;
            tokenizationCost = 0;
        }

        require(cost != 0, "Price0");

        //take the fee
        uint256 toPaySeller = cost;
        uint256 _sellFee = feesPerCategory[nft] == 0 ? DEFAULT_SELL_FEE : feesPerCategory[nft];
        if ((_sellFee > 0) && chargeFee) {
            // if there is fee set, decrease amount by the fee and send fee
            uint256 fee = ((toPaySeller * _sellFee) / 10000);
            toPaySeller = toPaySeller - fee;
            pToken.safeTransferFrom(buyer, sellFeeAddress, fee);
            ISellFeeDistributor(sellFeeAddress).distributeFee(pToken, fee);
            emit MarketplaceFeePaid(address(nft), tokenId, fee);
        }

        pToken.safeTransferFrom(buyer, _lot.seller, toPaySeller);

        emit TnftSold(buyer, address(nft), tokenId, _lot.seller, cost);
        delete marketplaceLot[address(nft)][tokenId];
        //update tracker
        _updateTrackerTnft(nft, tokenId, false);

        nft.safeTransferFrom(address(this), buyer, tokenId);
    }

    /**
     * @notice Sets the sellFeeAddress
     * @dev Will emit SellFeeAddressSet on change.
     * @param _sellFeeAddress A new address for fee storage.
     */
    function setSellFeeAddress(address _sellFeeAddress) external onlyFactoryOwner {
        emit SellFeeAddressSet(sellFeeAddress, _sellFeeAddress);
        sellFeeAddress = _sellFeeAddress;
    }

    /**
     * @notice Needed to receive Erc721 tokens.
     * @dev The ERC721 smart contract calls this function on the recipient
     *      after a `transfer`. This function MAY throw to revert and reject the
     *      transfer. Return of other than the magic value MUST result in the
     *      transaction being reverted.
     *      Note: the contract address is always the message sender.
     * @param operator The address which called `safeTransferFrom` function (not used), but here to support interface.
     * @param seller Seller EOA address.
     * @param tokenId Unique token identifier that is being transferred.
     * @param data Additional data with no specified format.
     * @return A bytes4 `selector` is returned to the caller to verify contract is an ERC721Receiver implementer.
     */
    function onERC721Received(
        address operator,
        address seller,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        return _onERC721Received(operator, seller, tokenId, data);
    }

    /**
     * @notice Needed to receive Erc721 tokens.
     * @param seller Seller EOA address.
     * @param tokenId Unique token identifier that is being transferred.
     * @param data Additional data with no specified format.
     * @return A bytes4 `selector` is returned to the caller to verify contract is an ERC721Receiver implementer.
     */
    function _onERC721Received(
        address /*operator*/,
        address seller,
        uint256 tokenId,
        bytes calldata data
    ) private returns (bytes4) {
        IFactory factory = IFactory(IFactoryProvider(factoryProvider).factory());
        address nft = msg.sender;
        uint256 price = abi.decode(data, (uint256));
        IERC20 defUSD = factory.defUSD();
        require(address(factory.category(ITangibleNFT(nft).name())) != address(0), "Not TNFT");

        marketplaceLot[nft][tokenId] = Lot(ITangibleNFT(nft), defUSD, tokenId, seller, price);
        emit Selling(seller, nft, tokenId, price);
        _updateTrackerTnft(ITangibleNFT(nft), tokenId, true);

        return IERC721Receiver.onERC721Received.selector;
    }
}
