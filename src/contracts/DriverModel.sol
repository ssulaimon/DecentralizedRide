//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;

contract DriverModel {
    struct Driver {
        bytes32 driverId;
        address driverAddress;
        bytes licenseNumber;
        bool isSanctioned;
        bool isApproved;
        string tokenURI;
        uint256 tokenId;
    }
}
