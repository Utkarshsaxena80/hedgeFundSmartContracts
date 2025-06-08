//SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;
///////--->0x36CD2dafc9149B2dea2497B299D34f9D5478569B
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./hedgeToken.sol";

contract HedgeFund is Ownable, AutomationCompatibleInterface {
    AggregatorV3Interface internal immutable dataFeed;

    uint256 private _totalMoney;
    HedgeToken public immutable i_token;
    uint256 private tokenReserve;
    uint256 private poolMoney;
    uint256 private collectedFees;

    struct UserInfo {
        uint128 value;
        int128 lastPrice;
        uint128 initialPrice;
        uint8 tolerance;
        bool choice;
        bool isRegisteredForHedging;
    }
    struct isHedging {
        uint128 hedgeAmount;
        address owner;
        bool isHedging;
        uint256 valueAtHedge;
    }
    address[] public userAddresses;

    mapping(address => UserInfo) private userInfo;
    mapping(address => isHedging) public hedgeHistory;

    error InvalidTolerance();
    error ZeroValueDeposit();
    error AlreadyRegistered();
    error NotRegistered();

    event UserRegistered(address indexed user);
    event FundsAdded(address indexed user, uint256 value);
    event TreasuryUpdated(uint256 value);
    event ethSwapped(uint256 indexed tokensOUT);

    constructor(address tokenAddress) Ownable(msg.sender) {
        dataFeed = AggregatorV3Interface(
            0x694AA1769357215DE4FAC081bf1f309aDC325306
        );
        i_token = HedgeToken(tokenAddress);
        //  i_token.approve(address(this),_totalMoney);
        // i_token.allowance(msg.sender, address(this));
    }

    function getToken() public {
        i_token.mint(address(this), 1000000* 10**i_token.decimals());
        tokenReserve += 1000000;
    }

    function getReserves() external view returns (uint256, uint256) {
        return (_totalMoney, tokenReserve);
    }

    function register(bool _choice, uint8 _tolerance) public payable {
        if (_tolerance < 1 || _tolerance > 3) revert InvalidTolerance();
        if (msg.value == 0) revert ZeroValueDeposit();
        if (userInfo[msg.sender].isRegisteredForHedging) revert AlreadyRegistered();

        int256 price = getChainlinkDataFeedLatestAnswer();
        UserInfo storage user = userInfo[msg.sender];
        user.value = uint128(msg.value);
        user.choice = _choice;
        user.isRegisteredForHedging = false;
        user.tolerance = _tolerance;
        user.lastPrice = int128(price);
        user.lastPrice = int128(price);

        emit UserRegistered(msg.sender);

        unchecked {
            _totalMoney += msg.value;
            poolMoney += msg.value;
        }
        userAddresses.push(msg.sender);
        emit TreasuryUpdated(_totalMoney);
    }

    function addBalance() external payable {
        UserInfo storage user = userInfo[msg.sender];
      //  if (!user.isRegisteredForHedging) revert NotRegistered();

        int256 price = getChainlinkDataFeedLatestAnswer();

        unchecked {
            user.value += uint128(msg.value);
        }
        user.lastPrice = int128(price);

        emit FundsAdded(msg.sender, msg.value);

        unchecked {
            _totalMoney += msg.value;
            poolMoney += msg.value;
        }
        emit TreasuryUpdated(_totalMoney);
    }

    function checkUpkeep(
        bytes calldata
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        int256 price = getChainlinkDataFeedLatestAnswer();
        address[] memory usersToSwap = new address[](userAddresses.length);
        address[] memory usersToUnhedge = new address[](userAddresses.length);
        uint256 matchCount = 0;
        uint256 unhedgeCount=0;
        for (uint256 i = 0; i < userAddresses.length; i++){
            address userAddr = userAddresses[i];
            UserInfo memory user = userInfo[userAddr];
          if(!user.isRegisteredForHedging){
            int256 last =int256(user.lastPrice);
            uint8 tolerance =user.tolerance;
            int256 threshold =last -
                ((last * int256(uint256(tolerance))) / 100);
            if (price < threshold) {
                usersToSwap[matchCount] = userAddr;
                matchCount++;
            }
          }
           else if(user.isRegisteredForHedging){
            isHedging memory hedger = hedgeHistory[userAddr];
            if(hedger.isHedging) {
               
                int256 hedgePrice = int256(hedger.valueAtHedge);
                int256 recoveryThreshold = hedgePrice + ((hedgePrice * int256(uint256(user.tolerance))) / 100);
                
                if (price > recoveryThreshold) {
                    usersToUnhedge[unhedgeCount] = userAddr;
                    unhedgeCount++;
                }
            }
        }
                  
         upkeepNeeded = (matchCount > 0) || (unhedgeCount > 0);
        if (upkeepNeeded) {
            address[] memory filtered = new address[](matchCount);
            address[] memory filteredUnhedge = new address[](unhedgeCount);
            for (uint ii = 0; i < matchCount; ii++) {
                filtered[ii] = usersToSwap[ii];
            }
              for (uint iii = 0; iii < unhedgeCount; iii++) {
            filteredUnhedge[iii] = usersToUnhedge[iii];
        }
            performData = abi.encode(filtered,filteredUnhedge);
            } else {
                performData = "";
            }
        }
    }
    
        function performUpkeep(bytes calldata performData) external {
       (address[] memory usersToSwap, address[] memory usersToUnhedge) = 
        abi.decode(performData, (address[], address[]));

        for (uint i = 0; i < usersToSwap.length; i++) {
            address user = usersToSwap[i];
            UserInfo storage user1 = userInfo[user];
            if (user1.tolerance == 1) {
                //hedge 15% of initial investment
                //push to hedgeHistory
                uint128 newVaule = user1.value;
                isHedging storage hedger = hedgeHistory[user];
                hedger.hedgeAmount = (newVaule * 15) / 100;
                hedger.owner = user;
                hedger.isHedging = true;
                hedger.valueAtHedge = uint256(
                    getChainlinkDataFeedLatestAnswer()
                );
                swapEthToToken(user, (newVaule * 15) / 100);
                user1.value -= (newVaule * 15) / 100;
                user1.isRegisteredForHedging=true;
            } else if (user1.tolerance == 2) {
                //hedge to 20 %
                uint128 newVaule = user1.value;
                isHedging storage hedger = hedgeHistory[user];
                hedger.hedgeAmount = (newVaule * 20) / 100;
                hedger.owner = user;
                hedger.isHedging = true;
                hedger.valueAtHedge = uint256(
                    getChainlinkDataFeedLatestAnswer()
                );
                swapEthToToken(user, (newVaule * 20) / 100);
                user1.value -= (newVaule * 20) / 100;
            } else if (user1.tolerance == 3) {
                uint128 newVaule = user1.value;
                isHedging storage hedger = hedgeHistory[user];
                hedger.hedgeAmount = (newVaule * 15) / 100;
                hedger.owner = user;
                hedger.isHedging = true;
                hedger.valueAtHedge = uint256(
                    getChainlinkDataFeedLatestAnswer()
                );
                swapEthToToken(user, (newVaule * 30) / 100);
                user1.value -= (newVaule * 30) / 100;
            }
        }
        for (uint i = 0; i < usersToUnhedge.length; i++) {
        address user = usersToUnhedge[i];
        isHedging storage hedger = hedgeHistory[user];
        UserInfo storage userInfo1 = userInfo[user];
        
        if (hedger.isHedging && hedger.hedgeAmount > 0) {
            uint256 userTokenBalance = i_token.balanceOf(user);
            swapTokenToEth(/*user,*/userTokenBalance);
            if (userTokenBalance > 0) {
                hedger.isHedging = false;
                hedger.hedgeAmount = 0;
                hedger.valueAtHedge = 0;
                userInfo1.isRegisteredForHedging = false;
                userInfo1.lastPrice = int128(getChainlinkDataFeedLatestAnswer());
            }
        }
    }
    }

    function swapEthToToken(address user, uint256 eth) internal {
        require(eth > 0, "Send ETH to swap");
        uint256 ethInWithFee = (eth * 997) / 1000;
        collectedFees += eth - ethInWithFee;
        uint256 tokensOut = (ethInWithFee * tokenReserve) /
            (_totalMoney + ethInWithFee);
        require(tokensOut <= tokenReserve, "Not enough liquidity");
        _totalMoney -= eth;
        // poolMoney += eth;
        tokenReserve -= tokensOut;
        i_token.transfer(user, tokensOut);
        emit ethSwapped(tokensOut);
    }
     function swapTokenToEth(/*address user,*/uint256 tokenIn) internal  {
        require(tokenIn > 0, "Send tokens to swap");
        i_token.transferFrom(msg.sender, address(this), tokenIn);
        //////---->APPROVE THE TOKEN TO IN THE FRONTEND

        uint256 tokenInWithFee = tokenIn * 997 / 1000;

        uint256 ethOut = (tokenInWithFee * _totalMoney) / (tokenReserve + tokenInWithFee);

        require(ethOut <= _totalMoney, "Not enough ETH liquidity");

        tokenReserve += tokenIn;
        _totalMoney -= ethOut;


        payable(msg.sender).transfer(ethOut);
    //    emit tokenSwapped( ethOut ,msg.sender);
    }
    function getChainlinkDataFeedLatestAnswer() public view returns (int256) {
        (, int256 answer, , , ) = dataFeed.latestRoundData();
        return answer;
    }

    function getUserBalance() external view returns (uint256) {
      //  if (!userInfo[msg.sender].isRegistered) revert NotRegistered();
        return userInfo[msg.sender].value;
    }

    function getUserToleranceLevel() external view returns (uint8) {
      //  if (!userInfo[msg.sender].isRegistered) revert NotRegistered();
        return userInfo[msg.sender].tolerance;
    }

    // Additional getter functions for completeness
    function getUserChoice() external view returns (bool) {
     //   if (!userInfo[msg.sender].isRegistered) revert NotRegistered();
        return userInfo[msg.sender].choice;
    }

    function getUserLastPrice() external view returns (int256) {
      //  if (!userInfo[msg.sender].isRegistered) revert NotRegistered();
        return userInfo[msg.sender].lastPrice;
    }

    function getTotalMoney() external view returns (uint256) {
        return _totalMoney;
    }
}
