//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;
import {IRide} from "../interfaces/IRide.sol";
import {ERC20} from "@openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract Ride is IRide {
    error RideContract__OnlyAdminContract();
    error RideContract__ZeroNotAllowed();
    error RideContract__DriverIsSacntioned();
    error RideContract__NotEnoughAllowance();
    error RideContract__TransactionFailed();
    error RideContract__NotEnoughBalance();
    event AddedNewDriver(bytes32 id, address indexed driver);
    event Sanctioned(bytes32 id, address indexed driver);

    //enum
    enum DriverState {
        AVAILABLE,
        BOOKED
    }

    enum OrderStatus {
        PENDING,
        ACCEPTED,
        ONGOING,
        CANCELLED,
        AWAITING_CONFIRMATION,
        COMPLETED
    }

    // struct

    // Personal data =  string fullName   string carImage;;  string carName;   string carModel;
    struct DriverInfo {
        DriverState driverState;
        string tokenURI;
        uint256 tokenId;
        bytes32 driverId;
        address driverAddress;
        bytes licenseNumber;
        bool isSanctioned;
        bool isApproved;
        uint256 numbersOfRideCompleted;
        string[] areaCovered;
        uint256 amountEarned;
    }

    struct UserBookingDetails {
        address driverAddress;
        string driverInfo;
        uint256 amountPaid;
        string pickUp;
        string dropOf;
        OrderStatus orderStatus;
        bytes32 bookingId;
    }

    struct DriverBooking {
        address userAddress;
        uint256 amountPaid;
        bytes32 bookingId;
        string pickUp;
        string dropOf;
        OrderStatus orderStatus;
    }

    //State Variables
    address adminContractAddress;
    mapping(address => bool) isAddressSanctioned;
    uint256 indexCount;
    DriverInfo[] driversInfo;
    mapping(address => DriverBooking[]) driverBookings;
    mapping(address => UserBookingDetails[]) userBookingOrders;
    mapping(address => uint256) userBalance;
    mapping(address => uint256) userEscrowBalance;
    address paymentCoin;

    modifier onlyAdminContract() {
        if (msg.sender != adminContractAddress)
            revert RideContract__OnlyAdminContract();
        _;
    }
    modifier checkFundingAmount(uint256 _value) {
        if (_value == 0) {
            revert RideContract__ZeroNotAllowed();
        }
        _;
    }
    modifier checkAllowance(uint256 _value) {
        if (_value > ERC20(paymentCoin).allowance(msg.sender, address(this))) {
            revert RideContract__NotEnoughAllowance();
        }
        _;
    }
    modifier checkBalanceAmount(uint256 _value) {
        if (_value > userBalance[msg.sender]) {
            revert RideContract__NotEnoughBalance();
        }
        _;
    }

    constructor(address _adminContractAddress, address paymentCoinAddress) {
        require(
            _adminContractAddress != address(0),
            "Admin contract cannot be zero address"
        );
        adminContractAddress = _adminContractAddress;
    }

    function bookRide(
        uint256 rideDriverIndex,
        string memory pickUpLocation,
        string memory dropOfLocation,
        uint256 amountToPay
    ) external checkBalanceAmount(amountToPay) {
        require(rideDriverIndex != type(uint256).max, "invalid index");
        DriverInfo memory driver = driversInfo[rideDriverIndex];
        require(driver.isApproved, "Driver is not approved");
        require(!driver.isSanctioned, "Driver is sanctioned");
        require(
            driver.driverState == DriverState.AVAILABLE,
            "Driver is not available"
        );

        bytes32 bookingId = keccak256(
            abi.encodePacked(msg.sender, driver.driverAddress, block.timestamp)
        );
        userBalance[msg.sender] -= amountToPay;
        userEscrowBalance[msg.sender] += amountToPay;
        DriverBooking memory driverBooking = DriverBooking({
            userAddress: msg.sender,
            amountPaid: amountToPay,
            pickUp: pickUpLocation,
            dropOf: dropOfLocation,
            orderStatus: OrderStatus.PENDING,
            bookingId: bookingId
        });
        UserBookingDetails memory userBooking = UserBookingDetails({
            driverAddress: driver.driverAddress,
            driverInfo: driver.tokenURI,
            amountPaid: amountToPay,
            pickUp: pickUpLocation,
            dropOf: dropOfLocation,
            orderStatus: OrderStatus.PENDING,
            bookingId: bookingId
        });
        driverBookings[driver.driverAddress].push(driverBooking);
        userBookingOrders[msg.sender].push(userBooking);
    }

    /**
     *
     * @param rideId the ride Id is hashed bytes32 using the driver and user address also the block.time stamp
     * @notice only the driver or the passenger can call this function
     */

    function cancelRide(bytes32 rideId) external {
        // checking if the msg.sender is the passenger
        uint256 userOrderOfIndex = getUserOrderIndex(rideId, msg.sender);

        // if the msg.sender is the passenger the function above would return index of the booking id from the list of the user orders else it would return the max number of uint256
        if (userOrderOfIndex != type(uint256).max) {
            // checking to make sure the order status is still on pending or accepted before it can be cancelled
            // ongoing or compelted order cannot be canceled

            require(
                userBookingOrders[msg.sender][userOrderOfIndex].orderStatus ==
                    OrderStatus.PENDING ||
                    userBookingOrders[msg.sender][userOrderOfIndex]
                        .orderStatus ==
                    OrderStatus.ACCEPTED,
                "Your order is not pending"
            );
            // geting the index of the booking id from the booking list of the driver
            uint256 driverBookingIndex = getDriverBookingIdIndex(
                rideId,
                userBookingOrders[msg.sender][userOrderOfIndex].driverAddress
            );
            uint256 driverIndex = getDriverIndex(
                userBookingOrders[msg.sender][userOrderOfIndex].driverAddress
            );

            //Updating the user booking to show cancelled
            userBookingOrders[msg.sender][userOrderOfIndex]
                .orderStatus = OrderStatus.CANCELLED;

            //Updating the driver booking to show cancelled
            driverBookings[
                userBookingOrders[msg.sender][userOrderOfIndex].driverAddress
            ][driverBookingIndex].orderStatus = OrderStatus.CANCELLED;
            //updating to make driver open for new ride
            driversInfo[driverIndex].driverState = DriverState.AVAILABLE;
            userEscrowBalance[msg.sender] -= userBookingOrders[msg.sender][
                userOrderOfIndex
            ].amountPaid;
            userBalance[msg.sender] += userBookingOrders[msg.sender][
                userOrderOfIndex
            ].amountPaid;
        }

        // Getting to the part means the caller is the driver

        uint256 driverBookIndex = getDriverBookingIdIndex(rideId, msg.sender);
        // this would return the index of the booking id from the list of booking if the caller is the driver or it would return max of type uint256

        if (driverBookIndex != type(uint256).max) {
            // Making sure the order is not currently on going or completed before its cancelled
            require(
                driverBookings[msg.sender][driverBookIndex].orderStatus ==
                    OrderStatus.PENDING ||
                    driverBookings[msg.sender][driverBookIndex].orderStatus ==
                    OrderStatus.ACCEPTED,
                "Order Cannot Be Canceled"
            );

            // getting the booking id index from list if user orders
            uint256 userOrderIndex = getUserOrderIndex(
                rideId,
                driverBookings[msg.sender][driverBookIndex].userAddress
            );
            //getting the driver index
            uint256 driverIndex = getDriverIndex(msg.sender);
            // Update the driver bookings to reflect that booking have been cancelled
            driverBookings[msg.sender][driverBookIndex]
                .orderStatus = OrderStatus.CANCELLED;
            // updating the user order to reflect that order have been cancelled
            userBookingOrders[
                driverBookings[msg.sender][driverBookIndex].userAddress
            ][userOrderIndex].orderStatus = OrderStatus.CANCELLED;
            //updating to make driver open for new ride
            driversInfo[driverIndex].driverState = DriverState.AVAILABLE;
            userEscrowBalance[
                driverBookings[msg.sender][driverBookIndex].userAddress
            ] -= driverBookings[msg.sender][driverBookIndex].amountPaid;
            userBalance[
                driverBookings[msg.sender][driverBookIndex].userAddress
            ] += driverBookings[msg.sender][driverBookIndex].amountPaid;
        }

        // function call would be reverted if any of those two condition are ot met meaning the caller is not the driver or the passenger

        revert("You don't have permision to cancel this booking");
    }

    function acceptRide(bytes32 rideId) external {
        uint256 orderIndex = getDriverBookingIdIndex(rideId, msg.sender);

        if (orderIndex != type(uint256).max) {
            // Making sure driver is not accepting already accepted or cancelled order
            require(
                driverBookings[msg.sender][orderIndex].orderStatus !=
                    OrderStatus.ACCEPTED ||
                    driverBookings[msg.sender][orderIndex].orderStatus !=
                    OrderStatus.CANCELLED,
                "This order cannot be accepted"
            );

            // Gettting the booking index from the user bookings
            uint256 passengerOrderIndex = getUserOrderIndex(
                rideId,
                driverBookings[msg.sender][orderIndex].userAddress
            );
            uint256 driverIndex = getDriverIndex(msg.sender);
            driverBookings[msg.sender][orderIndex].orderStatus = OrderStatus
                .ACCEPTED;
            userBookingOrders[
                driverBookings[msg.sender][orderIndex].userAddress
            ][passengerOrderIndex].orderStatus = OrderStatus.ACCEPTED;
            driversInfo[driverIndex].driverState = DriverState.BOOKED;
        }

        revert("You don't have permission to accept order");
    }

    function compeleteRide(bytes32 rideId) external {
        // check index of the rideId from driver bookings
        uint256 orderIndex = getDriverBookingIdIndex(rideId, msg.sender);
        if (orderIndex != type(uint256).max) {
            require(
                driverBookings[msg.sender][orderIndex].orderStatus ==
                    OrderStatus.ONGOING
            );

            uint256 passengerOrderIndex = getUserOrderIndex(
                rideId,
                driverBookings[msg.sender][orderIndex].userAddress
            );
            driverBookings[msg.sender][orderIndex].orderStatus = OrderStatus
                .AWAITING_CONFIRMATION;
            userBookingOrders[
                driverBookings[msg.sender][orderIndex].userAddress
            ][passengerOrderIndex].orderStatus = OrderStatus
                .AWAITING_CONFIRMATION;
        }
        revert("You don't have permission to accept order");
    }

    function confirmPayment(bytes32 rideId) external {
        uint256 getRideIndex = getUserOrderIndex(rideId, msg.sender);

        if (getRideIndex != type(uint256).max) {
            uint256 driverBookingIndex = getDriverBookingIdIndex(
                rideId,
                userBookingOrders[msg.sender][getRideIndex].driverAddress
            );
            uint256 getDriverInfoIndex = getDriverIndex(
                userBookingOrders[msg.sender][getRideIndex].driverAddress
            );
            userBookingOrders[msg.sender][getRideIndex]
                .orderStatus = OrderStatus.COMPLETED;
            driverBookings[
                userBookingOrders[msg.sender][getRideIndex].driverAddress
            ][driverBookingIndex].orderStatus = OrderStatus.COMPLETED;
            driversInfo[getDriverInfoIndex].numbersOfRideCompleted += 1;
        }

        revert("You don't have permission to accept order");
    }

    /**
     *
     * @param _tokenURI this a json link containing the containing driver full name, car name, car image and car model
     * @param _driverId this the bytes32  hashed for every driver that serves as their identification
     * @param _driverAddress this the wallet adress of the driver
     * @param _licenseNumber this is the government number given to the driver
     */

    function addNewDriver(
        string memory _tokenURI,
        bytes32 _driverId,
        address _driverAddress,
        bytes memory _licenseNumber,
        uint256 _tokenId
    ) external onlyAdminContract {
        DriverInfo memory newDriverInfo = DriverInfo({
            tokenId: _tokenId,
            driverState: DriverState.AVAILABLE,
            tokenURI: _tokenURI,
            driverId: _driverId,
            driverAddress: _driverAddress,
            licenseNumber: _licenseNumber,
            isSanctioned: false,
            isApproved: true,
            numbersOfRideCompleted: 0,
            areaCovered: new string[](100),
            amountEarned: 0
        });

        driversInfo.push(newDriverInfo);
        emit AddedNewDriver(
            newDriverInfo.driverId,
            newDriverInfo.driverAddress
        );
    }

    function fundAccount(uint256 _value) external checkFundingAmount(_value) {
        userBalance[msg.sender] += _value;
        bool status = ERC20(paymentCoin).transferFrom(
            msg.sender,
            address(this),
            _value
        );
        checkTransactionStatus(status);
    }

    function withdrawFund(uint256 _value) external checkBalanceAmount(_value) {
        userBalance[msg.sender] -= _value;
        bool status = ERC20(paymentCoin).transfer(msg.sender, _value);
        checkTransactionStatus(status);
    }

    /**
     *
     * @param index the index of the driver from all approvedDrivers in the index
     * @notice only the admin contract can call this function
     * @dev any sanctioned driver would not be able to take others
     */
    function sanctionDriver(uint256 index) external onlyAdminContract {
        driversInfo[index].isSanctioned = true;
        isAddressSanctioned[driversInfo[index].driverAddress] = true;

        emit Sanctioned(
            driversInfo[index].driverId,
            driversInfo[index].driverAddress
        );
    }

    /**
     * @dev this returns all registered drivers
     * @notice this does not filter any driver base on any condition. This should be done at the frontend to save gas cost
     */

    function getAllApprovedDriver() public view returns (DriverInfo[] memory) {
        return driversInfo;
    }

    /**
     * @dev this returns if an address is sanctioned or not
     */

    function getAddressSanctioned(address _user) public view returns (bool) {
        return isAddressSanctioned[_user];
    }

    function getDriverBookingIdIndex(
        bytes32 bookingId,
        address driver
    ) public view returns (uint256) {
        for (uint256 i = 0; i < driverBookings[driver].length; i++) {
            if (driverBookings[driver][i].bookingId == bookingId) {
                return i;
            }
        }
        return type(uint256).max;
    }

    function getUserOrderIndex(
        bytes32 bookingId,
        address user
    ) public view returns (uint256) {
        for (uint256 i = 0; i < userBookingOrders[user].length; i++) {
            if (userBookingOrders[user][i].bookingId == bookingId) {
                return i;
            }
        }
        return type(uint256).max;
    }

    function getDriverIndex(
        address _driver
    ) public view returns (uint256 index) {
        for (uint i = 0; i < driversInfo.length; i++) {
            if (driversInfo[i].driverAddress == _driver) {
                index = i;
                break;
            }
            index = type(uint256).max;
        }
    }

    function checkTransactionStatus(bool status) internal {
        if (!status) {
            revert RideContract__TransactionFailed();
        }
    }
}
