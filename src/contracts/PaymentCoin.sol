//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;
import {ERC20} from "@openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

/**
 * @title RideContract Statblecoin
 * @author Salaudeen Sulaimon
 * @notice This just to simulate stable coin used for payment of rides
 */

contract PaymentCoin is ERC20 {
    error PaymentCoin__MoreThanMintAble();
    error PaymentCoin__MintTimeNotElapse();
    mapping(address => uint256) lastTimeMinted;

    constructor() ERC20("RideStableCoin", "RSC") {}

    /**
     *
     * @param value the amount user requested to mint
     * @notice there is cap on amount mintable each time user request to mint
     */

    modifier checkAmount(uint256 value) {
        if (value > 100 ether || value == 0) {
            revert PaymentCoin__MoreThanMintAble();
        }
        _;
    }

    modifier checkLastMinted() {
        if ((block.timestamp - lastTimeMinted[msg.sender]) < 1) {
            revert PaymentCoin__MintTimeNotElapse();
        }
        _;
    }

    function mint(
        uint256 _amount
    ) external checkAmount(_amount) checkLastMinted {
        lastTimeMinted[msg.sender] = block.timestamp;
        _mint(msg.sender, _amount);
    }
}
