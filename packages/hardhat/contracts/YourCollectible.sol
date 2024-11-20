// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2; // Do not change the solidity version as it negatively impacts submission grading

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol"; // 引入 ECDSA 库
contract YourCollectible is
	ERC721,
	ERC721Enumerable,
	ERC721URIStorage,
	Ownable
{
	using Counters for Counters.Counter;
	using ECDSA for bytes32;

	Counters.Counter public tokenIdCounter;
	mapping(uint256 => uint256) public tokenPrices;
	mapping(bytes32 => bool) private usedHashes;

	// 映射记录每个NFT的 nonce 值
	mapping(uint256 => uint256) public nonces;

	event PurchaseNFT(
		uint256 indexed tokenId,
		address indexed buyer,
		address indexed seller,
		uint256 price,
		uint256 timestamp
	);
	constructor() ERC721("YourCollectible", "YCB") {}


    // 使用多重签名和时间戳购买NFT
    function buyNFTWithMultiSig(
        uint256 tokenId,
        uint256 price,
        uint256 timestamp,
        bytes memory signatureSeller    //加一个授权
    ) public payable {
        require(tokenPrices[tokenId] == price, "Price does not match the listed price");
        require(block.timestamp <= timestamp + 10 minutes, "Transaction has expired");
        
        address seller = ownerOf(tokenId);
        bytes32 hash = keccak256(abi.encodePacked(tokenId, price, msg.sender, seller, timestamp));
        
        // 检查hash是否已被使用
        require(!usedHashes[hash], "Transaction already processed");
        
        // 验证卖家签名
        require(_verify(hash, signatureSeller, seller), "Invalid seller signature");
        
        require(msg.value == price, "Incorrect price sent");
        
        // 完成NFT转移
        _transfer(seller, msg.sender, tokenId);
        
        // 将交易资金发送给卖家
        payable(seller).transfer(msg.value);
        
        // 更新已使用的hash
        usedHashes[hash] = true;
        
        // 记录交易事件
        emit PurchaseNFT(tokenId, msg.sender, seller, price, block.timestamp);
    }

    // 验证签名
    function _verify(bytes32 hash, bytes memory signature, address signer) internal pure returns (bool) {
        return hash.toEthSignedMessageHash().recover(signature) == signer;
    }



	 // 使用随机数（nonce）和多重签名购买NFT
    function buyNFTWithNonce(
        uint256 tokenId,
        uint256 price,
        uint256 timestamp,
        uint256 nonce,
        bytes memory signatureSeller
    ) public payable {
        require(tokenPrices[tokenId] == price, "Price does not match the listed price");
        require(block.timestamp <= timestamp + 10 minutes, "Transaction has expired");
        
        address seller = ownerOf(tokenId);
        bytes32 hash = keccak256(abi.encodePacked(tokenId, price, msg.sender, seller, timestamp, nonce));

        // 检查hash是否已被使用
        require(!usedHashes[hash], "Transaction already processed");
        // 确保nonce匹配
        require(nonce == nonces[tokenId], "Nonce does not match");

        // 验证卖家签名
        require(_verify(hash, signatureSeller, seller), "Invalid seller signature");

        require(msg.value == price, "Incorrect price sent");

        // 完成NFT转移
        _transfer(seller, msg.sender, tokenId);

        // 将交易资金发送给卖家
        payable(seller).transfer(msg.value);

        // 更新nonce和hash
        nonces[tokenId]++; // 更新NFT的nonce
        usedHashes[hash] = true;

        // 记录交易事件
        emit PurchaseNFT(tokenId, msg.sender, seller, price, block.timestamp);
    }


    // 覆盖 ERC721 标准的部分函数
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function _burn(uint256 tokenId) internal override(ERC721URIStorage, ERC721) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721URIStorage, ERC721) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }


	function _baseURI() internal pure override returns (string memory) {
		return "https://gateway.pinata.cloud/ipfs/";
	}

	function mintItem(
		address to,
		string memory uri
	) public virtual returns (uint256) {
		tokenIdCounter.increment();
		uint256 tokenId = tokenIdCounter.current();
		_safeMint(to, tokenId);
		_setTokenURI(tokenId, uri);
		return tokenId;
	}

	// The following functions are overrides required by Solidity.


	function setTokenPrice(uint256 tokenId, uint256 price) public {
		require(
			ownerOf(tokenId) == msg.sender,
			"Only the owner can set the price"
		);
		tokenPrices[tokenId] = price;
	}

	function purchaseNFT(uint256 tokenId) public payable {
		uint256 price = tokenPrices[tokenId];
		address owner = ownerOf(tokenId);
		require(msg.value == price, "Incorrect value sent");

		_transfer(owner, msg.sender, tokenId);
		payable(owner).transfer(msg.value);
		tokenPrices[tokenId] = 0;

		emit Transfer(owner, msg.sender, tokenId);
	}
    



  // 存储每个 tokenId 的创作者地址
    mapping(uint256 => address) private _creators;
    
    // 存储每个 tokenId 的交易历史记录
    mapping(uint256 => TransactionHistory[]) public tokenTransactionHistory;
    
    // 版税百分比，默认5%
    uint256 public royaltyPercentage = 5;

    // 盲盒价格，默认为 0.1 ETH
    uint256 public mysteryBoxPrice = 0.1 ether;

    // 可供选择的NFT tokenId 列表
    uint256[] public availableTokens;

    // 持有NFT的开始时间
    mapping(uint256 => uint256) public holdingStartTime;

    // 标记某个NFT是否已领取忠诚度奖励
    mapping(uint256 => bool) public loyaltyRewardClaimed;

    // 收益分享地址
    address[] public profitSharingAddresses;

    // 收益分享比例（以百分比表示，100为最大）
    uint256[] public profitSharingPercentages;

    // 忠诚度奖励持有期，默认为30天
    uint256 public loyaltyPeriod = 30 days;

    // NFT的稀有度枚举类型
    enum Rarity {
        Common,
        Rare,
        Epic,
        Legendary
    }

    // 存储每个 tokenId 对应的稀有度
    mapping(uint256 => Rarity) public tokenRarities;

    // 交易历史记录结构体
    struct TransactionHistory {
        address seller;  // 卖家地址
        address buyer;   // 买家地址
        uint256 price;   // 交易价格
        uint256 timestamp;  // 交易时间戳
    }

    // 租赁信息结构体
    struct Rental {
        address renter;   // 租用者地址
        uint256 rentPrice;  // 租金价格
        uint256 startTime;  // 租赁开始时间
        uint256 duration;   // 租赁持续时间
        bool active;        // 租赁状态
    }

    // 存储每个 tokenId 对应的租赁信息
    mapping(uint256 => Rental) public rentals;

    // 拍卖信息结构体
    struct Auction {
        address seller;       // 卖家地址
        uint256 tokenId;      // NFT的tokenId
        uint256 minBid;       // 最低起拍价
        uint256 highestBid;   // 当前最高出价
        address highestBidder; // 当前最高出价者
        uint256 endTime;      // 拍卖结束时间
        bool active;          // 拍卖是否激活
    }

    // 存储每个 tokenId 对应的拍卖信息
    mapping(uint256 => Auction) public auctions;

    // NFT碎片化所有权结构体
    struct FractionalOwnership {
        uint256 totalShares;  // 总份额
        mapping(address => uint256) sharesOwned;  // 持有者地址与其持有的份额
    }

    // 存储每个 tokenId 对应的碎片化所有权
    mapping(uint256 => FractionalOwnership) public fractionalOwnerships;


    // 设置收益分享信息
    function setProfitSharing(address[] memory addresses, uint256[] memory percentages) public onlyOwner {
        require(addresses.length == percentages.length, "The address and scale length do not match");
        uint256 totalPercentage = 0;
        for (uint256 i = 0; i < percentages.length; i++) {
            totalPercentage += percentages[i];
        }
        require(totalPercentage <= 100, "The sum of the dividend percentage cannot exceed 100%");

        profitSharingAddresses = addresses;
        profitSharingPercentages = percentages;
    }

    // 分配利润给指定的地址
    function distributeProfits(uint256 amount) internal {
        for (uint256 i = 0; i < profitSharingAddresses.length; i++) {
            uint256 share = (amount * profitSharingPercentages[i]) / 100;
            payable(profitSharingAddresses[i]).transfer(share);
        }
    }

    // 购买NFT时增加版税支付逻辑
    function banshuibuyNFT(uint256 tokenId) public payable {
        uint256 price = tokenPrices[tokenId];
        require(price > 0, "The copyright has not been sold");
        require(msg.value == price, "The wrong price was sent");

        address seller = ownerOf(tokenId);
        address creator = _creators[tokenId];
        uint256 royaltyAmount = (msg.value * royaltyPercentage) / 100; // 计算版税金额
        uint256 sellerAmount = msg.value - royaltyAmount;

        _transfer(seller, msg.sender, tokenId);
        // 分配利润
        distributeProfits(msg.value);
        // 支付给创作者版税
        payable(creator).transfer(royaltyAmount);
        // 剩余金额支付给卖家
        payable(seller).transfer(sellerAmount);

        // 记录交易历史
        tokenTransactionHistory[tokenId].push(TransactionHistory({
            seller: seller,
            buyer: msg.sender,
            price: msg.value,
            timestamp: block.timestamp
        }));

        tokenPrices[tokenId] = 0;
    }

    // 查询指定NFT的交易历史记录
    function getTokenTransactionHistory(uint256 tokenId) public view returns (TransactionHistory[] memory) {
        return tokenTransactionHistory[tokenId];
    }

    // 修改版税百分比
    function setRoyaltyPercentage(uint256 percentage) public onlyOwner {
        royaltyPercentage = percentage;
    }

    // 创建拍卖
    function createAuction(uint256 tokenId, uint256 minBid, uint256 duration) public {
        require(ownerOf(tokenId) == msg.sender, "Only the owner can initiate an auction");
        require(!auctions[tokenId].active, "Only the owner can initiate an auction");

        auctions[tokenId] = Auction({
            seller: msg.sender,
            tokenId: tokenId,
            minBid: minBid,
            highestBid: 0,
            highestBidder: address(0),
            endTime: block.timestamp + duration,
            active: true
        });
    }

    // 开始拍卖
    function startAuction(uint256 tokenId, uint256 minBid, uint256 auctionDuration) public {
        require(ownerOf(tokenId) == msg.sender, "Only NFT owners can initiate auctions");
        require(!auctions[tokenId].active, "This NFT auction has been activated");

        auctions[tokenId] = Auction({
            seller: msg.sender,
            tokenId: tokenId,
            minBid: minBid,
            highestBid: 0,
            highestBidder: address(0),
            endTime: block.timestamp + auctionDuration,
            active: true
        });
    }

    // 出价
    function placeBid(uint256 tokenId) public payable {
        Auction storage auction = auctions[tokenId];
        require(auction.active, "The auction is inactive");
        require(block.timestamp < auction.endTime, "The auction has ended");
        require(msg.value > auction.highestBid, "The bid is lower than the current maximum bid");

        // 退还之前的最高出价者
        if (auction.highestBidder != address(0)) {
            payable(auction.highestBidder).transfer(auction.highestBid);
        }

        auction.highestBid = msg.value;
        auction.highestBidder = msg.sender;
    }

    // 结束拍卖并转移NFT
    function endAuction(uint256 tokenId) public {
        Auction storage auction = auctions[tokenId];
        require(auction.active, "The auction is not activated");
        require(block.timestamp >= auction.endTime, "The auction is not over yet");

        auction.active = false;
        if (auction.highestBidder != address(0)) {
            // 将NFT转移给最高出价者
            _transfer(ownerOf(tokenId), auction.highestBidder, tokenId);
            // 将拍卖款项转移给卖家
            payable(ownerOf(tokenId)).transfer(auction.highestBid);
        }
    }

    // 创建租赁
    function createRental(uint256 tokenId, uint256 rentPrice, uint256 duration) public {
        require(ownerOf(tokenId) == msg.sender, "Only NFT owners can rent out");
        require(!rentals[tokenId].active, "The NFT has been rented out");

        rentals[tokenId] = Rental({
            renter: address(0),
            rentPrice: rentPrice,
            startTime: 0,
            duration: duration,
            active: true
        });
    }

    // 租用NFT
    function rentNFT(uint256 tokenId) public payable {
        Rental storage rental = rentals[tokenId];
        require(rental.active, "The NFT is not rentable");
        require(msg.value == rental.rentPrice, "The rent paid is incorrect");

        rental.renter = msg.sender;
        rental.startTime = block.timestamp;

        // 临时转移NFT的所有权给租用者
        _transfer(ownerOf(tokenId), msg.sender, tokenId);

        // 支付租金给NFT持有者
        payable(ownerOf(tokenId)).transfer(msg.value);
    }

    // 结束租赁并归还NFT
    function endRental(uint256 tokenId) public {
        Rental storage rental = rentals[tokenId];
        require(rental.active, "The NFT is not rented");
        require(block.timestamp >= rental.startTime + rental.duration, "The lease period has not yet ended");
        require(rental.renter != address(0), "The NFT is not rented");

        // 归还NFT给所有者
        _transfer(rental.renter, ownerOf(tokenId), tokenId);

        // 重置租赁信息
        rental.renter = address(0);
        rental.startTime = 0;
        rental.active = false;
    }

    // 创建碎片化NFT
    function createFractionalNFT(uint256 tokenId, uint256 totalShares) public {
        require(ownerOf(tokenId) == msg.sender, "Only NFT owners can do fractionation");
        require(totalShares > 0, "The number of shares must be greater than 0");

        fractionalOwnerships[tokenId].totalShares = totalShares;
        fractionalOwnerships[tokenId].sharesOwned[msg.sender] = totalShares;
    }

    // 转移NFT份额
    function transferShares(uint256 tokenId, address to, uint256 shares) public {
        require(fractionalOwnerships[tokenId].sharesOwned[msg.sender] >= shares, "Holding shares not enough");

        fractionalOwnerships[tokenId].sharesOwned[msg.sender] -= shares;
        fractionalOwnerships[tokenId].sharesOwned[to] += shares;
    }

    // 查询某地址的份额
    function getShares(uint256 tokenId, address owner) public view returns (uint256) {
        return fractionalOwnerships[tokenId].sharesOwned[owner];
    }

    // 获取NFT的总份额
    function getTotalShares(uint256 tokenId) public view returns (uint256) {
        return fractionalOwnerships[tokenId].totalShares;
    }

    // 设置盲盒价格
    function setMysteryBoxPrice(uint256 price) public onlyOwner {
        mysteryBoxPrice = price;
    }

    // 添加可供选择的NFT
    function addAvailableToken(uint256 tokenId) public onlyOwner {
        availableTokens.push(tokenId);
    }

    // 随机从盲盒中获取NFT
    function buyMysteryBox() public payable returns (uint256) {
        require(msg.value == mysteryBoxPrice, "The price paid is incorrect");
        require(availableTokens.length > 0, "There are no NFTs available");

        // 随机选择一个NFT
        uint256 randomIndex = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender))) % availableTokens.length;
        uint256 tokenId = availableTokens[randomIndex];

        // 从可用列表中移除该NFT
        availableTokens[randomIndex] = availableTokens[availableTokens.length - 1];
        availableTokens.pop();

        // 将NFT转移给购买者
        _transfer(ownerOf(tokenId), msg.sender, tokenId);

        return tokenId;
    }

    // 批量铸造NFT
    function mintBatch(address to, string[] memory uris) public returns (uint256[] memory) {
        uint256[] memory tokenIds = new uint256[](uris.length);

        for (uint256 i = 0; i < uris.length; i++) {
            tokenIds[i] = mintItem(to, uris[i]);
        }

        return tokenIds;
    }

    // 销毁NFT
    function burnNFT(uint256 tokenId) public {
        require(ownerOf(tokenId) == msg.sender, "Only NFT holders can burn NFTs");
        _burn(tokenId);
    }

    // 将NFT作为礼物赠送
    function giftNFT(address to, uint256 tokenId) public {
        require(ownerOf(tokenId) == msg.sender, "Only NFT holders can transfer NFTs");
        _transfer(msg.sender, to, tokenId);
    }

    // 设置NFT的稀有度
    function setTokenRarity(uint256 tokenId, Rarity rarity) public onlyOwner {
        tokenRarities[tokenId] = rarity;
    }

    // 获取NFT的稀有度
    function getTokenRarity(uint256 tokenId) public view returns (Rarity) {
        return tokenRarities[tokenId];
    }

    // 空投NFT给多个地址
    function airdropNFT(address[] memory recipients, string memory uri) public onlyOwner {
        for (uint256 i = 0; i < recipients.length; i++) {
            mintItem(recipients[i], uri);
        }
    }

    // 持有NFT时记录开始时间
    function _transfer(address from, address to, uint256 tokenId) internal override {
        super._transfer(from, to, tokenId);
        holdingStartTime[tokenId] = block.timestamp;
        loyaltyRewardClaimed[tokenId] = false; // 转移时重置忠诚奖励领取状态
    }

    // 领取忠诚度奖励
    function claimLoyaltyReward(uint256 tokenId) public {
        require(ownerOf(tokenId) == msg.sender, "Only NFT owners can claim rewards");
        require(!loyaltyRewardClaimed[tokenId], "The loyalty reward has been claimed");
        require(block.timestamp >= holdingStartTime[tokenId] + loyaltyPeriod, "If you don't hold it for enough time, you can't claim the reward");

        // 发送忠诚度奖励 (例如：ERC20 代币或其他奖励)
        // 奖励逻辑可以在此处实现

        loyaltyRewardClaimed[tokenId] = true; // 标记为已领取
    }

    // 设置忠诚度奖励持有期
    function setLoyaltyPeriod(uint256 newPeriod) public onlyOwner {
        loyaltyPeriod = newPeriod;
    }


    
}
