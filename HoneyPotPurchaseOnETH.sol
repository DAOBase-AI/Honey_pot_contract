// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}


contract HoneyPotPurchaseOnETH is Ownable {
    address public treasuryAddress;
    address public usdtAddress;
    address public usdcAddress;
    uint256 public commissionRate = 10;
    uint256 public maxPurchaseLimit = 20;
    uint256 public usdtPrice = 500 * 10**6;
    uint256 public usdcPrice = 500 * 10**6;
    uint256 public ethPrice = 0.25 ether;

    bool public paused = false;

    mapping(address => bool) public mintedAddress;
    mapping(address => uint256) public purchases;

    mapping(address => address) public userReferrer;

    event ReferrerUpdated(address indexed user, address indexed newReferrer);
    event CommissionRateUpdated(uint256 newCommissionRate);
    event PurchaseMade(address indexed buyer, uint256 quantity, uint256 totalPrice,address indexed referrer, address indexed effectiveReferrer, string tokenType);

    constructor(address _usdtAddress, address _usdcAddress, address _treasuryAddress) Ownable(msg.sender) {
        usdtAddress = _usdtAddress;
        usdcAddress = _usdcAddress;
        treasuryAddress = _treasuryAddress;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    modifier checkPurchaseLimit(uint256 quantity) {
        require(purchases[msg.sender] + quantity <= maxPurchaseLimit, "Purchase limit exceeded");
        _;
    }

    function setEthPrice(uint256 _ethPrice) external onlyOwner {
        ethPrice = _ethPrice;
    }

    function setUsdtPrice(uint256 _price) external onlyOwner {
        usdtPrice = _price;
    }

    function setUsdcPrice(uint256 _price) external onlyOwner {
        usdcPrice = _price;
    }

    function updateReferrer(address user, address newReferrer) public onlyOwner {

        require(user != address(0), "User cannot be the zero address");
        require(user != newReferrer, "User cannot be their own referrer");

        mintedAddress[user] = true;

        if(newReferrer != address(0)){
            mintedAddress[newReferrer] = true;
            userReferrer[user] = newReferrer;
            emit ReferrerUpdated(user, newReferrer);
        }

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

        require(quantity > 0, "Quantity must be greater than zero");
        uint256 totalPrice = ethPrice * quantity;
        require(msg.value >= totalPrice, "Insufficient ETH sent");

        address payable effectiveReferrer = payable(address(0));
        if (userReferrer[msg.sender] != address(0)) {
            effectiveReferrer = payable(userReferrer[msg.sender]);
        } else if (referrer != address(0) && mintedAddress[referrer] && msg.sender != referrer) {
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
        if(!mintedAddress[msg.sender]){
            mintedAddress[msg.sender] = true;
        }

        if (msg.value > totalPrice) {
            payable(msg.sender).transfer(msg.value - totalPrice);
        }

        emit PurchaseMade(msg.sender, quantity, totalPrice, referrer, effectiveReferrer, "ETH");
    }

    function buyWithERC20(address tokenAddress, uint256 quantity, address referrer) internal whenNotPaused checkPurchaseLimit(quantity) {

        require(quantity > 0, "Quantity must be greater than zero");
        uint256 price = (tokenAddress == usdtAddress) ? usdtPrice : usdcPrice;
        uint256 totalPrice = price * quantity;
        IERC20 token = IERC20(tokenAddress);

        address effectiveReferrer = address(0);
        if (userReferrer[msg.sender] != address(0)) {
            effectiveReferrer = userReferrer[msg.sender];
        } else if (referrer != address(0) && mintedAddress[referrer] && msg.sender != referrer) {
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
        if(!mintedAddress[msg.sender]){
            mintedAddress[msg.sender] = true;
        }

        string memory tokenType = (tokenAddress == usdtAddress) ? "USDT" : "USDC";
        emit PurchaseMade(msg.sender, quantity, totalPrice, referrer, effectiveReferrer, tokenType);
    }

    function buyWithUSDT(uint256 quantity, address referrer) external {
        buyWithERC20(usdtAddress, quantity, referrer);
    }

    function buyWithUSDC(uint256 quantity, address referrer) external {
        buyWithERC20(usdcAddress, quantity, referrer);
    }
}