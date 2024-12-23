//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;
import {PeerRideNft} from "../src/contracts/DriverNFT.sol";
import {Test} from "forge-std/Test.sol";

contract TestPeerRideNft is Test {
    PeerRideNft peerRideNft;
    address owner;
    address minter = makeAddr("minter");

    function setUp() external {
        owner = makeAddr("owner");
        vm.startPrank(owner);
        peerRideNft = new PeerRideNft();
        vm.stopPrank();
    }

    function testNotOwnerMint() public {
        vm.expectRevert();
        vm.prank(minter);
        peerRideNft.mint(minter, 1, "htttp:/nfturi/png");
    }

    function testSuccessMint() public {
        vm.prank(owner);
        peerRideNft.mint(minter, 1, "htttp:/nfturi/png");
        uint256 balance = peerRideNft.balanceOf(minter);
        uint256 expectedResult = 1;
        vm.assertEq(balance, expectedResult);
    }

    function testTokenURI() public {
        string memory tokenURI = "htttp:/nfturi/png";
        vm.prank(owner);
        peerRideNft.mint(minter, 1, tokenURI);
        bytes32 expectedResult = keccak256(abi.encodePacked(tokenURI));
        bytes32 result = keccak256(abi.encodePacked(peerRideNft.tokenURI(1)));
        vm.assertEq(expectedResult, result);
    }
}
