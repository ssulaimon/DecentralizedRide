//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;

interface IRideAdmin {
    //  string calldata _name,
    //     string calldata _carName,
    //     string calldata _carModel,
    // string calldata _carImage
    function register(
        string calldata tokenURI,
        string calldata _licenseNumber
    ) external;

    function approveDriver(address _user) external;

    function addRideContractAddress(address _rideContractAddress) external;

    function sanctionDriver(address _driver) external;

    // function sanctionDriver() external;

    // function checkApproval(address _user) external view returns (bool);

    // function viewDriverDetails(address _user)ex

    // function getUserWaitingApproval() external view returns (address[] memory);
}
