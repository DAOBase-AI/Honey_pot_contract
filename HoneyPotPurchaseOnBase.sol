// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}
interface IERC721 {
    function balanceOf(address owner) external view returns (uint256 balance);
}

contract HoneyPotPurchaseOnBase is Ownable {
    address public treasuryAddress;
    address public usdcAddress;
    uint256 public commissionRate = 10;
    uint256 public maxPurchaseLimit = 20;
    uint256 public usdcPrice = 500 * 10**6;
    uint256 public ethPrice = 0.25 ether;

    bool public paused = false;

    mapping(address => uint256) public purchases;
    IERC721 public nftContract;
    mapping(address => address) public userReferrer;

    event ReferrerUpdated(address indexed user, address indexed newReferrer);
    event CommissionRateUpdated(uint256 newCommissionRate);
    event PurchaseMade(address indexed buyer, uint256 quantity, uint256 totalPrice,address indexed referrer, address indexed effectiveReferrer, string tokenType);

    constructor(address _usdcAddress, address _treasuryAddress,address _nftAddress) Ownable(msg.sender) {
        usdcAddress = _usdcAddress;
        treasuryAddress = _treasuryAddress;
        nftContract = IERC721(_nftAddress);
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    modifier checkPurchaseLimit(uint256 quantity) {
        require(purchases[msg.sender] + quantity <= maxPurchaseLimit, "Purchase limit exceeded");
        _;
    }

    function setNftAddress(address _nftAddress) external onlyOwner {

        require(_nftAddress != address(0), "Invalid address: cannot be zero address");
        nftContract = IERC721(_nftAddress);
    }

    function setEthPrice(uint256 _ethPrice) external onlyOwner {
        ethPrice = _ethPrice;
    }

    function setUsdcPrice(uint256 _price) external onlyOwner {
        usdcPrice = _price;
    }

    function updateReferrer(address user, address newReferrer) public onlyOwner {

        require(newReferrer != address(0), "New referrer cannot be the zero address");
        require(user != address(0), "User cannot be the zero address");
        require(user != newReferrer, "User cannot be their own referrer");
        require(userReferrer[user] == address(0), "User already has a referrer");

        userReferrer[user] = newReferrer;

        emit ReferrerUpdated(user, newReferrer);

    }

    function setCommissionRate(uint256 _commissionRate) external onlyOwner {
        commissionRate = _commissionRate;
        emit CommissionRateUpdated(_commissionRate);
    }

    function pause() external onlyOwner {
        paused = true;
    }

    function unpause() external onlyOwner {
        paused = false;
    }

    function buyWithETH(uint256 quantity, address payable referrer) external payable whenNotPaused checkPurchaseLimit(quantity) {

        uint256 totalPrice = ethPrice * quantity;
        require(msg.value >= totalPrice, "Insufficient ETH sent");

        address payable effectiveReferrer = payable(address(0));
        if (userReferrer[msg.sender] != address(0)) {
            effectiveReferrer = payable(userReferrer[msg.sender]);
        } else if (referrer != address(0) && nftContract.balanceOf(referrer) > 0 && msg.sender != referrer) {
            effectiveReferrer = referrer;
            userReferrer[msg.sender] = referrer;
        }

        uint256 commission = 0;
        if (effectiveReferrer != address(0)) {
            commission = (totalPrice * commissionRate) / 100;
            effectiveReferrer.transfer(commission);
        }

        payable(treasuryAddress).transfer(totalPrice - commission);
        purchases[msg.sender] += quantity;

        if (msg.value > totalPrice) {
            payable(msg.sender).transfer(msg.value - totalPrice);
        }

        emit PurchaseMade(msg.sender, quantity, totalPrice, referrer, effectiveReferrer, "ETH");
    }

    function buyWithUSDC(uint256 quantity, address referrer) external whenNotPaused checkPurchaseLimit(quantity) {

        uint256 totalPrice = usdcPrice * quantity;
        IERC20 token = IERC20(usdcAddress);

        address effectiveReferrer = address(0);
        if (userReferrer[msg.sender] != address(0)) {
            effectiveReferrer = userReferrer[msg.sender];
        } else if (referrer != address(0) && nftContract.balanceOf(referrer) > 0 && msg.sender != referrer) {
            effectiveReferrer = referrer;
            userReferrer[msg.sender] = referrer;
        }

        uint256 commission = 0;
        if (effectiveReferrer != address(0)) {
            commission = (totalPrice * commissionRate) / 100;
            require(token.transferFrom(msg.sender, effectiveReferrer, commission), "Commission transfer failed");
        }

        require(token.transferFrom(msg.sender, treasuryAddress, totalPrice - commission), "Transfer failed");
        purchases[msg.sender] += quantity;

        emit PurchaseMade(msg.sender, quantity, totalPrice, referrer, effectiveReferrer, "USDC");
    }

}