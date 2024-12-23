//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;

import {Script} from "forge-std/Script.sol";
import {RideAdmin} from "../src/contracts/RideAdmin.sol";
import {Ride} from "../src/contracts/RideContract.sol";
import {PeerRideNft} from "../src/contracts/DriverNFT.sol";

contract DeployRideSystem is Script {
    function run() external returns (address, address, address, address) {
        address owner = makeAddr("owneraccount");
        vm.startBroadcast(owner);
        PeerRideNft peerRideNft = new PeerRideNft();
        RideAdmin rideAdmin = new RideAdmin(address(peerRideNft));
        Ride ride = new Ride(address(rideAdmin));
        peerRideNft.transferOwnership(address(rideAdmin));

        vm.stopBroadcast();
        return (owner, address(rideAdmin), address(ride), address(peerRideNft));
    }
}
