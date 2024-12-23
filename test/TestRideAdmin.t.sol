//SPDX-License-Identifier:MIT

pragma solidity >=0.8.0 <0.9.0;
import {RideAdmin} from "../src/contracts/RideAdmin.sol";
import {Test, console} from "forge-std/Test.sol";
import {DeployRideSystem} from "../script/DeployRideSystem.s.sol";
import {Ride} from "../src/contracts/RideContract.sol";
import {PeerRideNft} from "../src/contracts/DriverNFT.sol";

contract TestRideAdmin is Test {
    RideAdmin rideAdmin;
    address owner;
    address ride;
    address newDriver;
    address newAdd;
    address peerRideNftAddress;

    function setUp() public {
        DeployRideSystem deployRideAdmin = new DeployRideSystem();
        (
            address _owner,
            address _rideAdmin,
            address _ride,
            address _peerRideNftAddress
        ) = deployRideAdmin.run();
        owner = _owner;
        rideAdmin = RideAdmin(_rideAdmin);
        ride = _ride;
        peerRideNftAddress = _peerRideNftAddress;
        newDriver = makeAddr("newDriver");
        newAdd = makeAddr("newAdd");
    }

    //Modiifers
    modifier registration() {
        vm.startPrank(newDriver);

        rideAdmin.register("http://ipfs.com/image.png", "XG4B589H");
        vm.stopPrank();
        _;
    }
    modifier addRideContract() {
        vm.startPrank(owner);
        rideAdmin.addRideContractAddress(ride);
        vm.stopPrank();
        _;
    }
    modifier newRegistration() {
        vm.startPrank(newAdd);
        rideAdmin.register("http://ipfs.com/image.png", "XG4B5H9H");
        vm.stopPrank();
        _;
    }

    function testOwner() public view {
        address expectedOwner = rideAdmin.owner();
        vm.assertEq(expectedOwner, owner);
    }

    function testRideContractAddressIsZero() public view {
        address rideContractAddress = rideAdmin.getRideContractAddress();
        address expectedResult = address(0);
        vm.assertEq(rideContractAddress, expectedResult);
    }

    function testNotOwnerAddingRideContract() public {
        address attacker = makeAddr("attacker");
        vm.expectRevert();
        vm.startPrank(attacker);
        rideAdmin.addRideContractAddress(ride);

        vm.stopPrank();
    }

    function testOwnerAddRideAdminContract() public {
        vm.startPrank(owner);
        rideAdmin.addRideContractAddress(ride);
        vm.stopPrank();
        address rideContract = rideAdmin.getRideContractAddress();
        vm.assertEq(rideContract, ride);
    }

    function testAddingZeroAddress() public {
        vm.expectRevert(RideAdmin.RideAdmin__AddressZeroNotAllowed.selector);
        vm.startPrank(owner);
        rideAdmin.addRideContractAddress(address(0));

        vm.stopPrank();
    }

    // Registration test

    function testRegisterWithoutRideContract() public {
        vm.startPrank(newDriver);
        vm.expectRevert(
            RideAdmin.RideAdmin__InvalidRideContractAddress.selector
        );
        rideAdmin.register("", "XG4B589H");
        vm.stopPrank();
    }

    function testRegister() public addRideContract registration {
        uint256 pendingApprovals = rideAdmin.getAllPendingApprovals().length;
        uint256 expectedResult = 1;
        vm.assertEq(expectedResult, pendingApprovals);
    }

    function testNftSuccessFullyMint() public addRideContract registration {
        uint256 result = PeerRideNft(peerRideNftAddress).balanceOf(newDriver);
        uint256 expectedResult = 1;
        vm.assertEq(result, expectedResult);
    }

    function testAlreadyRegisteredAddress()
        public
        addRideContract
        registration
    {
        vm.expectRevert(RideAdmin.RideAdmin__AddressAlreadyRegistered.selector);
        vm.startPrank(newDriver);
        rideAdmin.register("", "XG4B589");
        vm.stopPrank();
    }

    function testAlreadyRegisterdLicenseNumber()
        public
        addRideContract
        registration
    {
        address weirdDriver = makeAddr("WeirdDriver");
        vm.expectRevert();
        vm.startPrank(weirdDriver);
        rideAdmin.register("", "XG4B589H");
        vm.stopPrank();
    }

    function testNoneRegisteredAddressIndex() public {
        address weirdDriver = makeAddr("WeirdDriver");
        uint256 index = rideAdmin.getAddressIndex(weirdDriver);
        uint256 expectedResult = type(uint256).max;
        vm.assertEq(index, expectedResult);
    }

    function testGetRegisteredAddressIndex()
        public
        addRideContract
        registration
    {
        uint256 index = rideAdmin.getAddressIndex(newDriver);
        uint256 expectedResult = 0;
        vm.assertEq(index, expectedResult);
    }

    function testMultipleRegistrationAddressIndex()
        public
        addRideContract
        registration
        newRegistration
    {
        uint256 index = rideAdmin.getAddressIndex(newAdd);
        uint256 expectedResult = 1;
        vm.assertEq(index, expectedResult);
    }

    //Approval test

    function testNoneOwnerApproval() public addRideContract registration {
        vm.expectRevert();
        vm.startPrank(newDriver);
        rideAdmin.approveDriver(newDriver);
        vm.stopPrank();
    }

    function testOwnerApproveNoneRegisteredAddress() public addRideContract {
        vm.expectRevert();
        vm.startPrank(owner);
        rideAdmin.approveDriver(newDriver);
        vm.stopPrank();
    }

    function testApproval() public addRideContract registration {
        vm.startPrank(owner);
        rideAdmin.approveDriver(newDriver);
        uint256 driversWaitingApproval = rideAdmin
            .getAllPendingApprovals()
            .length;
        uint256 expected = 0;
        vm.assertEq(driversWaitingApproval, expected);

        vm.stopPrank();
    }

    function testApproveFromPoolOfPending()
        public
        addRideContract
        registration
        newRegistration
    {
        vm.startPrank(owner);
        rideAdmin.approveDriver(newAdd);

        vm.stopPrank();
        uint256 driversWaitingApproval = rideAdmin
            .getAllPendingApprovals()
            .length;
        uint256 expected = 1;
        vm.assertEq(driversWaitingApproval, expected);
    }

    function testApprovalCompleted() public addRideContract registration {
        vm.startPrank(owner);
        rideAdmin.approveDriver(newDriver);
        vm.stopPrank();
        uint256 approvedDrivers = Ride(ride).getAllApprovedDriver().length;
        uint256 expectedResult = 1;
        vm.assertEq(approvedDrivers, expectedResult);
    }

    // Sanction test

    function testNoneOwnerTrySanction() public addRideContract registration {
        vm.startPrank(owner);
        rideAdmin.approveDriver(newDriver);
        vm.stopPrank();
        vm.expectRevert();
        vm.startPrank(newDriver);
        rideAdmin.sanctionDriver(newDriver);
        vm.stopPrank();
    }

    function testSanctionNoneApprovedDriver()
        public
        addRideContract
        registration
    {
        vm.startPrank(owner);
        rideAdmin.approveDriver(newDriver);
        vm.expectRevert();
        rideAdmin.sanctionDriver(newAdd);
        vm.stopPrank();
    }

    function testSanctionDriver() public addRideContract registration {
        vm.startPrank(owner);
        rideAdmin.approveDriver(newDriver);
        rideAdmin.sanctionDriver(newDriver);
        vm.stopPrank();
        bool isSanctioned = Ride(ride).getAddressSanctioned(newDriver);
        bool expectedResult = true;
        vm.assertEq(isSanctioned, expectedResult);
    }
}
