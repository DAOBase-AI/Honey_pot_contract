// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts@4.7.0/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts@4.7.0/access/Ownable.sol";
import "@openzeppelin/contracts@4.7.0/utils/Counters.sol"; 

contract HoneyPotNFT is ERC721, Ownable {

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;
    string private _fixedURI;

    constructor(string memory fixedURI) ERC721("Honey Pot NFT", "HP") {

        _fixedURI = fixedURI;
        _tokenIdCounter.increment();
    }

    function batchMint(address recipient, uint256 amount) public onlyOwner {
        for (uint256 i = 0; i < amount; i++) {
            uint256 tokenId = _tokenIdCounter.current();
            _safeMint(recipient, tokenId);
            _tokenIdCounter.increment();
        }
    }

    function setBaseURI(string memory baseURI_) external onlyOwner() {
        _fixedURI = baseURI_;
    }
    

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        return _fixedURI;
    }

    function _beforeTokenTransfer(
    address from, 
    address to, 
    uint256 tokenId
    ) internal override virtual {
        require(from == address(0), "Err: token transfer is BLOCKED"); 
        super._beforeTokenTransfer(from, to, tokenId);  
    }
}