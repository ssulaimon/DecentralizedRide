//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;
import {Ownable} from "@openzeppelin-contracts/contracts/access/Ownable.sol";
import {ERC721} from "@openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";

contract PeerRideNft is ERC721, Ownable {
    mapping(uint256 tokenId => string tokenURI) nftTokenURI;

    constructor() ERC721("PeerRideNFT", "PRN") Ownable(msg.sender) {}

    function mint(
        address _newDriver,
        uint256 _tokenId,
        string memory _tokenURI
    ) external onlyOwner {
        _mint(_newDriver, _tokenId);
        nftTokenURI[_tokenId] = _tokenURI;
    }

    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        return nftTokenURI[tokenId];
    }
}
