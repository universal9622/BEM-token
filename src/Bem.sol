//SPDX-License-Identifier:MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BemToken is ERC20, Ownable {
    bytes32 public immutable i_merkleRoot;

    constructor() ERC20("BEM", "BM") Ownable(msg.sender) {}

    //Event
    event FirstMint(address owner, uint256 amount);
    event Burnt(address from, uint256 _supplyToBurn);
    event AirDrop(address source, address destination, uint256 _amount);
    event MonthlyEmission(address owner, uint256 emittedTokenNum);

    function initialMint(uint _amount) public onlyOwner {
        _mint(address(this), _amount);

        emit FirstMint(msg.sender, _amount);
    }

    function monthlyBurn(uint256 supplyToBurn) public onlyOwner {
        _burn(address(this), supplyToBurn);
        emit Burnt(address(this), supplyToBurn);
    }

    function dynamicEmission(uint256 monthlyEmissionRate) public {
        _mint(address(this), monthlyEmissionRate);

        emit MonthlyEmission(msg.sender, monthlyEmissionRate);
    }

    function externalTransfer(address payee, uint256 amount) public onlyOwner {
        transferFrom(address(this), payee, amount);
    }

    //Dynamic emission
    /**
     * 
    *Mn+1= Amount of $ in use on the business month n+1 
     * 
    Tn+1 = Number of tokens available by the end of month N

    X = How many tokens we need to release in month n+1 in order to keep the value of the token as it was in month N.

    Vn = The value of the token in month N 


    Mn+1
    ———— = Vn 
    (Tn+1+X)

    X=     (Mn+1- Vn • Tn+1)
                ——————————-
                      Vn
    Mn = 100
    Tn = 10000
    Mn+1 = $120
    Tn+1 = 9000 ( 10% were burned)
    Vn =100/ 10000= .01

    X = (120 - 0.01 *9000) / 0.01 = 3000

    */
}
