//SPDX-License-Identifier:MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

//Error
error BM__InvalidAddress();
error BM__InvalidAmount();
error BM_InvalidMerkleProof();
error BM__AirDropFailed();

contract BemToken is ERC20, Ownable {
    bytes32 public immutable i_merkleRoot;

    constructor(bytes32 merkleRoot) ERC20("BEM", "BM") Ownable(msg.sender) {
        i_merkleRoot = merkleRoot;
    }

    //Event
    event FirstMint(address owner, uint256 amount);
    event Burnt(address from, uint256 _supplyToBurn);
    event AirDrop(address source, address destination, uint256 _amount);

    function initialMint(uint _amount) private onlyOwner {
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

    function claimAirdrop(
        bytes32[] calldata merkleProof,
        address user,
        uint256 _tokenAmount
    ) public onlyOwner {
        if (address(user) == address(0)) revert BM__InvalidAddress();
        if (_tokenAmount <= 0) revert BM__InvalidAmount();

        bytes32 leaf = keccak256(abi.encodePacked(user, _tokenAmount));
        if (MerkleProof.verify(merkleProof, i_merkleRoot, leaf))
            revert BM_InvalidMerkleProof();

        if (!transferFrom(address(this), user, _tokenAmount))
            revert BM__AirDropFailed();

        emit AirDrop(address(this), user, _tokenAmount);
    }

    function withrdaw(uint256 value) public onlyOwner {
        _transfer(address(this), msg.sender, value);
    }
}
