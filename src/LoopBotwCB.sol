// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IMMBot {
    function transferToAdmin(address Token) external payable;
    function AddLiquiditytokenY() external payable;
    function AddLiquiditytokenX() external payable;
    function removeFarmtokenY() external payable;
    function removeFarmtokenX() external payable;
    function collectRewardstokenY() external payable;
    function collectRewardstokenX() external payable; 
    function currentID() external view returns (uint256);
    function ViewBin() external view returns (uint256);
    function ViewNoOfBins() external view returns (uint256);
    function compoundMoePercent(uint256 percent) external payable;
}

contract BotController {
    address public admin;

    address public Bot;
    address public tokenX = 0x00000000eFE302BEAA2b3e6e1b18d08D69a9012a; // WMNT
    address public tokenY = 0x78c1b0C915c4FAA5FffA6CAbf0219DA63d7f4cb8; // USDT
    address public Moe = 0x4515A45337F461A11Ff0FE8aBF3c606AE5dC00c9;
    
    bool public USDTonly;
    uint256 public percent;
    bool public circuitStatus;
    uint256 public circuitRange;

    event CircuitStatusUpdated(bool status);

    constructor() {
        admin = msg.sender;
    }

    function setUSDTbool(bool setUSDTonly) external {
        require(msg.sender == admin, "Only admin can do this");
        USDTonly = setUSDTonly;
    }

    function resetCircuit() external {
        require(msg.sender == admin, "Only admin can do this");
        circuitStatus = false;
        emit CircuitStatusUpdated(false);
    }

    function setBotAddress(address newBot) external {
        require(msg.sender == admin, "Only admin can do this");
        Bot = newBot;
    }

    function setPercent(uint256 newPercent) external {
        require(msg.sender == admin, "Only admin can do this");
        percent = newPercent;
    }

    function setCircuitRange(uint256 newRange) external {
        require(msg.sender == admin, "Only admin can do this");
        circuitRange = newRange;
    }

    function circuitBreaker() public {
        uint256 y = IMMBot(Bot).ViewBin();
        uint256 x = IMMBot(Bot).currentID();
        bool newStatus = (x >= y) ? (x - y <= circuitRange) : (y - x <= circuitRange);
        if (newStatus != circuitStatus) {
            circuitStatus = newStatus;
            emit CircuitStatusUpdated(newStatus);
        }
    }

    function rebalance() public {
        circuitBreaker();
        if (!circuitStatus) return;

        if (USDTonly) {
            IMMBot(Bot).removeFarmtokenY();
            IMMBot(Bot).collectRewardstokenY();
        } else {
            IMMBot(Bot).removeFarmtokenX();
            IMMBot(Bot).collectRewardstokenX();
        }

        uint256 moeValue = IERC20(Moe).balanceOf(Bot);
        if (moeValue > 0) {
            IMMBot(Bot).compoundMoePercent(percent);
            IMMBot(Bot).transferToAdmin(Moe);
        }

        uint256 tokenYamount = IERC20(tokenY).balanceOf(Bot);
        uint256 tokenXamount = IERC20(tokenX).balanceOf(Bot);
        if (tokenYamount > tokenXamount) {
            IMMBot(Bot).AddLiquiditytokenY();
            USDTonly = true;
        } else if (tokenXamount > tokenYamount) {
            IMMBot(Bot).AddLiquiditytokenX();
            USDTonly = false;
        }
    }

    function compound() external {
        if (USDTonly) {
            IMMBot(Bot).collectRewardstokenY();
        } else {
            IMMBot(Bot).collectRewardstokenX();
        }
        IMMBot(Bot).transferToAdmin(Moe);
    }

    function transferToAdmin(address token) external {
        require(msg.sender == admin, "Only admin can do this");
        uint256 value = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(admin, value);
    }

    function checkFarm() external view returns (bool) {
        uint256 ActiveID = IMMBot(Bot).ViewBin();
        uint256 FarmID = IMMBot(Bot).currentID();
        uint256 noOfBins = IMMBot(Bot).ViewNoOfBins();
        if (!circuitStatus) return true;
        if (USDTonly) {
            return (ActiveID <= FarmID && ActiveID >= (FarmID - (noOfBins - 1)));
        } else {
            return (ActiveID >= FarmID && ActiveID <= (FarmID + (noOfBins - 1)));
        }
    }
}
