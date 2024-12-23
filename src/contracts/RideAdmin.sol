//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;
import {IRideAdmin} from "../interfaces/IRideAdmin.sol";
import {DriverModel} from "./DriverModel.sol";
import {Ownable} from "@openzeppelin-contracts/contracts/access/Ownable.sol";
import {IRide} from "../interfaces/IRide.sol";
import {PeerRideNft} from "./DriverNFT.sol";

// import {ERC721} from "@openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";

contract RideAdmin is IRideAdmin, DriverModel, Ownable {
    error RideAdmin__AddressAlreadyRegistered();
    error RideAdmin__InvalidRideContractAddress();
    error RideAdmin__AddingNewDriverFailed();
    error RideAdmin__AddressZeroNotAllowed();
    event Registered(address indexed user, string indexed name);

    mapping(bytes32 => bool) isLicenseRegistered;
    mapping(address => bool) addressAlreadyRegistered;
    address rideContractAddress;
    uint256 tokenCounter;
    Driver[] pendingApproval;
    PeerRideNft peerNft;

    constructor(address peerNftAddress) Ownable(msg.sender) {
        peerNft = PeerRideNft(peerNftAddress);
        tokenCounter = 0;
    }

    modifier alreadyRegistered() {
        if (addressAlreadyRegistered[msg.sender]) {
            revert RideAdmin__AddressAlreadyRegistered();
        }
        _;
    }
    modifier checkRideContractAddress() {
        if (rideContractAddress == address(0)) {
            revert RideAdmin__InvalidRideContractAddress();
        }
        _;
    }
    modifier zeroAddressChecker(address _address) {
        if (_address == address(0)) {
            revert RideAdmin__AddressZeroNotAllowed();
        }
        _;
    }

    function approveDriver(
        address _user
    ) external onlyOwner checkRideContractAddress {
        require(addressAlreadyRegistered[_user], "Address is not registerd");
        // getting the index of the user in the pending user list
        uint256 addressIndex = getAddressIndex(_user);
        // Making sure correct index of user is returned
        require(addressIndex != type(uint256).max, "index not found"); // this might be unreach able
        // Get driver to be approved
        Driver memory driver = pendingApproval[addressIndex];
        driver.isApproved = true;
        //  string memory _personalInfo,
        // bytes32 _driverId,
        // address _driverAddress,
        // bytes memory _licenseNumber

        bytes memory data = abi.encodeWithSignature(
            "addNewDriver(string,bytes32,address,bytes,uint256)",
            driver.tokenURI,
            driver.driverId,
            driver.driverAddress,
            driver.licenseNumber,
            driver.tokenId
        );
        (bool status, ) = rideContractAddress.call(data);
        if (!status) {
            revert RideAdmin__AddingNewDriverFailed();
        }

        removeFromPending(addressIndex);
    }

    /**
     *

     * @param _licenseNumber government license plate given to the car
     * @notice double registration of license number would lead to rejection of appplication
     * @dev call this function to apply for the role of driver
     */

    function register(
        string calldata _tokenURI,
        string calldata _licenseNumber
    ) external alreadyRegistered checkRideContractAddress {
        //checking if license is registered
        require(!_checkLicense(_licenseNumber), "License Plate is Registed");
        // making sure address is registered
        isLicenseRegistered[keccak256(abi.encodePacked(_licenseNumber))] = true;
        addressAlreadyRegistered[msg.sender] = true;

        // mint nft

        peerNft.mint(msg.sender, tokenCounter, _tokenURI);
        //create driver model
        Driver memory driverModel = Driver({
            tokenURI: _tokenURI,
            tokenId: tokenCounter,
            driverAddress: msg.sender,
            licenseNumber: bytes(_licenseNumber),
            isSanctioned: false,
            isApproved: false,
            driverId: keccak256(
                abi.encodePacked(block.timestamp, msg.sender, _licenseNumber)
            )
        });
        pendingApproval.push(driverModel);
        tokenCounter++;
    }

    function addRideContractAddress(
        address _rideContractAddress
    ) external onlyOwner zeroAddressChecker(_rideContractAddress) {
        rideContractAddress = _rideContractAddress;
    }

    function sanctionDriver(address _driver) external onlyOwner {
        IRide ride = IRide(rideContractAddress);
        uint256 index = ride.getDriverIndex(_driver);
        require(index != type(uint256).max, "index not found");
        ride.sanctionDriver(index);
    }

    /**
     *
     * @param _licenseNumber to be checked
     * @dev this function checks if license number have already been registered by a previous user
     */

    function _checkLicense(
        string memory _licenseNumber
    ) internal view returns (bool) {
        bytes32 hashedLicense = keccak256(abi.encodePacked(_licenseNumber));
        return isLicenseRegistered[hashedLicense];
    }

    function removeFromPending(uint256 index) internal {
        for (uint i = index; i < pendingApproval.length - 1; i++) {
            pendingApproval[i] = pendingApproval[i + 1];
        }
        pendingApproval.pop();
    }

    /**
     *
     * @param _userAddress wallet address of pending user to get their index in approval
     * @dev function would return type(uint256) max if address index is not found
     */
    function getAddressIndex(
        address _userAddress
    ) public view returns (uint256) {
        for (uint256 i = 0; i < pendingApproval.length; i++) {
            if (pendingApproval[i].driverAddress == _userAddress) {
                return i;
            }
        }
        return type(uint256).max;
    }

    /**
     * Retrieve all pending user waiting for approvals
     */
    function getAllPendingApprovals() external view returns (Driver[] memory) {
        return pendingApproval;
    }

    function getRideContractAddress() external view returns (address) {
        return rideContractAddress;
    }
}
