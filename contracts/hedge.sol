//SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract HedgeFund {
    AggregatorV3Interface internal immutable dataFeed;
    
    uint256 private _totalMoney;
    
   
    struct UserInfo {
        uint128 value;        
        int128 lastPrice;    
        uint8 tolerance;      
        bool choice;          
        bool isRegistered; 
    }
    
    mapping(address => UserInfo) private userInfo; 
   
    error InvalidTolerance();
    error ZeroValueDeposit();
    error AlreadyRegistered();
    error NotRegistered();
    
    event UserRegistered(address indexed user);
    event FundsAdded(address indexed user, uint256 value);
    event TreasuryUpdated(uint256 value);
    
    constructor() {
        dataFeed = AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306);
    }
    
    function register(bool _choice, uint8 _tolerance) public payable {
        if (_tolerance < 1 || _tolerance > 3) revert InvalidTolerance();
        if (msg.value == 0) revert ZeroValueDeposit();
        if (userInfo[msg.sender].isRegistered) revert AlreadyRegistered();
        
        int256 price = getChainlinkDataFeedLatestAnswer();
        UserInfo storage user = userInfo[msg.sender];
        user.value = uint128(msg.value);
        user.choice = _choice;
        user.isRegistered = true;
        user.tolerance = _tolerance;
        user.lastPrice = int128(price);
        
        emit UserRegistered(msg.sender);
    
        unchecked {
            _totalMoney += msg.value;
        }
        emit TreasuryUpdated(_totalMoney);
    }
    
    function addBalance() external payable {
        UserInfo storage user = userInfo[msg.sender];
        if (!user.isRegistered) revert NotRegistered();
        
        int256 price = getChainlinkDataFeedLatestAnswer();
    
        unchecked {
            user.value += uint128(msg.value);
        }
        user.lastPrice = int128(price);
        
        emit FundsAdded(msg.sender, msg.value);
        
        unchecked {
            _totalMoney += msg.value;
        }
        emit TreasuryUpdated(_totalMoney);
    }
    
    function getChainlinkDataFeedLatestAnswer() public view returns (int256) {
        (, int256 answer, , , ) = dataFeed.latestRoundData();
        return answer;
    }
    
    function getUserBalance() external view returns (uint256) {
        if (!userInfo[msg.sender].isRegistered) revert NotRegistered();
        return userInfo[msg.sender].value;
    }
    
    function getUserToleranceLevel() external view returns (uint8) {
        if (!userInfo[msg.sender].isRegistered) revert NotRegistered();
        return userInfo[msg.sender].tolerance;
    }
    
    // Additional getter functions for completeness
    function getUserChoice() external view returns (bool) {
        if (!userInfo[msg.sender].isRegistered) revert NotRegistered();
        return userInfo[msg.sender].choice;
    }
    
    function getUserLastPrice() external view returns (int256) {
        if (!userInfo[msg.sender].isRegistered) revert NotRegistered();
        return userInfo[msg.sender].lastPrice;
    }
    
    function getTotalMoney() external view returns (uint256) {
        return _totalMoney;
    }
    
    function stake() external payable {
        // Implementation needed
    }
}