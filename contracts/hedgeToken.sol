// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import {ERC1363} from "@openzeppelin/contracts/token/ERC20/extensions/ERC1363.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract HedgeToken is ERC20, Ownable, ERC1363, ERC20Permit {
    constructor(address initialOwner)
        ERC20("HedgeToken", "HDG")
        Ownable(initialOwner)
        ERC20Permit("HedgeToken")
    {}

    function mint(address to, uint256 amount) external  {
        _mint(to, amount);
    }
}
