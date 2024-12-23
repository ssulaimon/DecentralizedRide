//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;
import {Ownable} from "@openzeppelin-contracts/contracts/access/Ownable.sol";

interface IRide {
    struct Driver {
        bytes32 driverId;
        string fullName;
        address driverAddress;
        string carName;
        string carModel;
        bytes licenseNumber;
        bool isSanctioned;
        bool isApproved;
        string carImage;
    }

    // function addNewDriver(Driver calldata _driver) external;

    function getDriverIndex(
        address _driver
    ) external view returns (uint256 index);

    function sanctionDriver(uint256 index) external;
}
