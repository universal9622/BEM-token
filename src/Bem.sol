//SPDX-License-Identifier:MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

// //Error
// error BM__InvalidAddress();
// error BM__InvalidAmount();
// error BM_InvalidMerkleProof();
// error BM__AirDropFailed();

contract BemToken is ERC20, Ownable {
    bytes32 public immutable i_merkleRoot;

    constructor() ERC20("BEM", "BM") Ownable(msg.sender) {
        // i_merkleRoot = merkleRoot;
        /*bytes32 merkleRoot*/
    }

    //Event
    event FirstMint(address owner, uint256 amount);
    event Burnt(address from, uint256 _supplyToBurn);
    event AirDrop(address source, address destination, uint256 _amount);

    function initialMint(uint _amount) public onlyOwner {
        _mint(address(this), _amount);

        emit FirstMint(msg.sender, _amount);
    }

    function monthlyBurn(uint256 supplyToBurn) public onlyOwner {
        _burn(address(this), supplyToBurn);
        emit Burnt(address(this), supplyToBurn);
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

    // function claimAirdrop(
    //     bytes32[] calldata merkleProof,
    //     address user,
    //     uint256 _tokenAmount
    // ) public onlyOwner {
    //     if (address(user) == address(0)) revert BM__InvalidAddress();
    //     if (_tokenAmount <= 0) revert BM__InvalidAmount();

    //     bytes32 leaf = keccak256(abi.encodePacked(user, _tokenAmount));
    //     if (MerkleProof.verify(merkleProof, i_merkleRoot, leaf))
    //         revert BM_InvalidMerkleProof();

    //     if (!transferFrom(address(this), user, _tokenAmount))
    //         revert BM__AirDropFailed();

    //     emit AirDrop(address(this), user, _tokenAmount);
    // }

    // function withrdaw(uint256 value) public onlyOwner {
    //     _transfer(address(this), msg.sender, value);
    // }
}
