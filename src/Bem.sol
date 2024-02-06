//SPDX-License-Identifier:MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BemToken is ERC20,Ownable{

    constructor()ERC20("BEM","BM")Ownable(msg.sender){

    }
    //Event
    event FirstMint(address owner,uint256 amount);

    function initialMint(uint _amount)private onlyOwner{
        _mint(address(this), _amount);

        emit FirstMint(msg.sender,_amount);
    }
}
