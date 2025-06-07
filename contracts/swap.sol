// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "./hedgeToken.sol"; 

contract Swap is Ownable {
    HedgeToken public immutable i_token;

    uint256 private totalETH;

    constructor(address tokenAddress) Ownable(msg.sender) {
        i_token = HedgeToken(tokenAddress);
    }

    function getToken() public  {
        i_token.mint(address(this), 100000 ether);  
    }

    function getTokenStatus() public view returns (uint256) {
        return i_token.balanceOf(address(this));
    }

    function receiveETHFromInvestors() public payable {
        totalETH += msg.value;
    }
      
}
