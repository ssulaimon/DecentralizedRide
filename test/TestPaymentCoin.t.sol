//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;
import {PaymentCoin} from "../src/contracts/PaymentCoin.sol";
import {Test} from "forge-std/Test.sol";

contract TestPaymentCoin is Test {
    PaymentCoin paymentCoin;
    address minter = makeAddr("minter");

    function setUp() external {
        paymentCoin = new PaymentCoin();
    }

    function testZeroAddressMint() public {
        vm.expectRevert();
        vm.prank(address(0));
        paymentCoin.mint(100 ether);
    }

    function testMintFirstTime() public {
        vm.prank(minter);
        paymentCoin.mint(100 ether);
        uint256 expectedBalance = 100 ether;
        uint256 result = paymentCoin.balanceOf(minter);

        vm.assertEq(expectedBalance, result);
    }

    function testDoubleMint() public {
        vm.startPrank(minter);
        paymentCoin.mint(100 ether);
        vm.expectRevert(PaymentCoin.PaymentCoin__MintTimeNotElapse.selector);
        paymentCoin.mint(100 ether);

        vm.stopPrank();
    }

    function testMintAfterTimeElapse() public {
        vm.startPrank(minter);
        paymentCoin.mint(100 ether);
        vm.warp(block.timestamp + 1 days);
        paymentCoin.mint(100 ether);

        uint256 expectedBalance = 200 ether;
        uint256 result = paymentCoin.balanceOf(minter);
        vm.assertEq(expectedBalance, result);
    }

    function testMintMoreThanAllowed() public {
        vm.expectRevert(PaymentCoin.PaymentCoin__MoreThanMintAble.selector);
        vm.prank(minter);
        paymentCoin.mint(200 ether);
    }
}
