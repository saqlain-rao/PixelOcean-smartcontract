// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

error AlreadyListed(address nftAddress, uint256 tokenId);
error NotApprovedForMarketplace();
error NotListed(address nftAddress, uint256 tokenId);
error NotOwner();
error PriceMustBeAboveZero();
error PriceNotMet(address nftAddress, uint256 tokenId, uint256 price);
error TransferFailed();

contract NFTMarketplace is ReentrancyGuard, Ownable {
    struct Listing {
        uint256 price;
        address seller;
    }

    event ItemListed(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );

    event ItemCanceled(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId
    );

    event ItemBought(
        address indexed buyer,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );

    // State Variables
    mapping(address => mapping(uint256 => Listing)) public listings;
    uint256 public constant MARKETPLACE_FEE_PERCENT = 2; // 2% fee

    // Modifiers
    modifier notListed(address nftAddress, uint256 tokenId) {
        Listing memory listing = listings[nftAddress][tokenId];
        if (listing.price > 0) revert AlreadyListed(nftAddress, tokenId);
        _;
    }

    modifier isListed(address nftAddress, uint256 tokenId) {
        Listing memory listing = listings[nftAddress][tokenId];
        if (listing.price <= 0) revert NotListed(nftAddress, tokenId);
        _;
    }

    modifier isOwner(address nftAddress, uint256 tokenId, address spender) {
        IERC721 nft = IERC721(nftAddress);
        address owner = nft.ownerOf(tokenId);
        if (spender != owner) revert NotOwner();
        _;
    }

    constructor() Ownable(msg.sender) {}

    function listToken(address nftAddress, uint256 tokenId, uint256 price)
        external
        notListed(nftAddress, tokenId)
        isOwner(nftAddress, tokenId, msg.sender)
    {
        if (price <= 0) revert PriceMustBeAboveZero();
        
        IERC721 nft = IERC721(nftAddress);
        if (nft.getApproved(tokenId) != address(this) && !nft.isApprovedForAll(msg.sender, address(this))) {
            revert NotApprovedForMarketplace();
        }

        listings[nftAddress][tokenId] = Listing(price, msg.sender);
        emit ItemListed(msg.sender, nftAddress, tokenId, price);
    }

    function cancelListing(address nftAddress, uint256 tokenId)
        external
        isOwner(nftAddress, tokenId, msg.sender)
        isListed(nftAddress, tokenId)
    {
        delete listings[nftAddress][tokenId];
        emit ItemCanceled(msg.sender, nftAddress, tokenId);
    }

    function buyToken(address nftAddress, uint256 tokenId)
        external
        payable
        isListed(nftAddress, tokenId)
        nonReentrant
    {
        Listing memory listedItem = listings[nftAddress][tokenId];
        if (msg.value < listedItem.price) revert PriceNotMet(nftAddress, tokenId, listedItem.price);

        // Update state first
        delete listings[nftAddress][tokenId];

        // Send NFT
        IERC721(nftAddress).safeTransferFrom(listedItem.seller, msg.sender, tokenId);

        // Handle fee and payment
        uint256 fee = (listedItem.price * MARKETPLACE_FEE_PERCENT) / 100;
        uint256 sellerProceeds = listedItem.price - fee;

        (bool success, ) = payable(listedItem.seller).call{value: sellerProceeds}("");
        if (!success) revert TransferFailed();

        emit ItemBought(msg.sender, nftAddress, tokenId, listedItem.price);
    }

    function withdrawFees() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        (bool success, ) = payable(owner()).call{value: balance}("");
        if (!success) revert TransferFailed();
    }
}
