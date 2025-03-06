// SPDX-License-Identifier: MIT

pragma solidity >=0.5.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {BinHelper} from "./libraries/BinHelper.sol";
import {Constants} from "./libraries/Constants.sol";
import {Encoded} from "./libraries/math/Encoded.sol";
import {FeeHelper} from "./libraries/FeeHelper.sol";
import {JoeLibrary} from "./libraries/JoeLibrary.sol";
import {LiquidityConfigurations} from "./libraries/math/LiquidityConfigurations.sol";
import {PackedUint128Math} from "./libraries/math/PackedUint128Math.sol";
import {TokenHelper, IERC20} from "./libraries/TokenHelper.sol";
import {Uint256x256Math} from "./libraries/math/Uint256x256Math.sol";

import {IJoePair} from "./interfaces/IJoePair.sol";
import {ILBPair} from "./interfaces/ILBPair.sol";
import {ILBLegacyPair} from "./interfaces/ILBLegacyPair.sol";
import {ILBToken} from "./interfaces/ILBToken.sol";
import {ILBRouter} from "./interfaces/ILBRouter.sol";
import {ILBLegacyRouter} from "./interfaces/ILBLegacyRouter.sol";
import {IJoeFactory} from "./interfaces/IJoeFactory.sol";
import {ILBLegacyFactory} from "./interfaces/ILBLegacyFactory.sol";
import {ILBFactory} from "./interfaces/ILBFactory.sol";
import {IWNATIVE} from "./interfaces/IWNATIVE.sol";
import {LBRouter} from "./LBRouter.sol";





interface ILBTokenNFT {
    function balanceOf(address account, uint256 id) external view returns (uint256);

    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids)
        external
        view
        returns (uint256[] memory);

    function isApprovedForAll(address owner, address spender) external view returns (bool);

    function approveForAll(address spender, bool approved) external;
}

interface IRewarder {
    function claim(address user, uint256[] calldata ids) external;
    }

    interface IMOESwapRouter {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);
    }

contract MMAutoFarmUSDT{

    //https://docs.lfj.gg/guides/add-remove-liquidity

    using TokenHelper for IERC20;
    using JoeLibrary for uint256;
    using PackedUint128Math for bytes32;

address admin;

    constructor() {
        admin = msg.sender;
    }


uint256 CurrentDepositID;
address INTX = 0x4b7F28397B4294277E7825f224172944f4f5A877; //tokenX
address USDT = 	0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE; //tokenY
address LBPool = 0xE819fd507C397dC94343BeDbf820435251dA37F7;
address LBrouter = 0x013e138EF6008ae5FDFDE29700e3f2Bc61d21E3a;
address MoeRewarder = 0xE322cd6005fA9CcCd4450e81DfDe6c8B5eB67D0B;//Only rewarder for the INTX/USDT 25 Pool
address Moe = 0x4515A45337F461A11Ff0FE8aBF3c606AE5dC00c9; 
address router = 0xeaEE7EE68874218c3558b40063c42B82D3E7232a;

function setDpositID(uint256 newDepositID) public payable {
    require(msg.sender == admin, "Only owner can do this");
    CurrentDepositID = newDepositID;
}


//Trasfer to and from contract

function transferToAdmin(address Token) external payable {
    uint256 value = IERC20(Token).balanceOf(address(this));
    address to = 0x0B9BC785fd2Bea7bf9CB81065cfAbA2fC5d0286B;
    IERC20(Token).transfer(to, value);
}




//Swap directly with MM
  function rebalance() external payable {
        
        uint256 amountIn = IERC20(INTX).balanceOf(address(this));
        uint128 amountOut = 0;
        IERC20(INTX).approve(LBrouter, amountIn); //Approve Spending

        IERC20[] memory tokenPath = new IERC20[](2);
        tokenPath[0] = IERC20(INTX);
        tokenPath[1] = IERC20(USDT);

        uint256[] memory pairBinSteps = new uint256[](1); // pairBinSteps[i] refers to the bin step for the market (x, y) where tokenPath[i] = x and tokenPath[i+1] = y
        pairBinSteps[0] = 25;

        ILBRouter.Version[] memory versions = new ILBRouter.Version[](1);
        versions[0] = ILBRouter.Version.V2_2; // add the version of the Dex to perform the swap on

        ILBRouter.Path memory path; // instanciate and populate the path to perform the swap.
        path.pairBinSteps = pairBinSteps;
        path.versions = versions;
        path.tokenPath = tokenPath;

    
        ILBRouter(LBrouter).swapExactTokensForTokens(amountIn, amountOut, path, address(this), block.timestamp + 1);
  }

  function ViewBin() external view returns(uint256) {

    uint24 _activeID =ILBPair(LBPool).getActiveId();
    uint256 activeID = uint256(_activeID);

    return activeID;
  }
//Enter Liquidity


function AddLiquidity() external payable {
       
    uint256 amountX = 0;
    uint256 amountY = IERC20(USDT).balanceOf(address(this));
    uint256 binStep = 25;
    uint256 amountXMin = 0;
    uint256 amountYMin = 0;
    uint24 _activeID =ILBPair(LBPool).getActiveId();
    uint256 activeIdDesired = uint256(_activeID);
    uint256 binsAmount = 1;
    int256[] memory deltaIds = new int256[](binsAmount);
    deltaIds[0] = -1;
    uint256[] memory distributionX = new uint256[](binsAmount);
    distributionX[0] = 0;
    uint256[] memory distributionY = new uint256[](binsAmount);
    distributionY[0] = 1e18;
    uint256 idSlippage = 0;

    //Approve Tokens
        IERC20(INTX).approve(LBrouter, 1e18);
        IERC20(USDT).approve(LBrouter, amountY);


        ILBRouter.LiquidityParameters memory liquidityParameters = ILBRouter.LiquidityParameters(
        IERC20(INTX), // Replace with actual token X address
        IERC20(USDT), // Replace with actual token Y address
        binStep,           // Replace with appropriate bin step
        amountX,           // Replace with desired amount of token X
        amountY,           // Replace with desired amount of token Y
        amountXMin,
        amountYMin,
        activeIdDesired,
        idSlippage,
        deltaIds,
        distributionX,
        distributionY,
        address(this),
        address(this),
        block.timestamp + 300 // deadline in 5 minutes
        );

ILBRouter(LBrouter).addLiquidity(liquidityParameters);

CurrentDepositID = (activeIdDesired - 1);
}

function currentID() external view returns(uint256) {

    return CurrentDepositID;}

//Exit Liquidity

function removeFarm() external payable {

uint16 binStep = 25;
uint256 binsAmount = 1;

uint256[] memory amounts = new uint256[](binsAmount);
uint256[] memory claimid = new uint256[](binsAmount);
claimid[0] = CurrentDepositID;


// To figure out amountXMin and amountYMin, we calculate how much X and Y underlying we have as liquidity
    uint256 LBTokenAmount = ILBTokenNFT(LBPool).balanceOf(address(this), CurrentDepositID);
    amounts[0] = LBTokenAmount;


ILBRouter(LBrouter).removeLiquidity( 
    IERC20(INTX), // Replace with actual token X address
    IERC20(USDT), // Replace with actual token Y address
    binStep,
    0,
    0,
    claimid,
    amounts,
    address(this),
    block.timestamp + 300
);

}

function removeFarmManual(uint256 ManDepositID) external payable {

uint16 binStep = 25;
uint256 binsAmount = 1;

uint256[] memory amounts = new uint256[](binsAmount);
uint256[] memory Manclaimid = new uint256[](binsAmount);
Manclaimid[0] = ManDepositID;


// To figure out amountXMin and amountYMin, we calculate how much X and Y underlying we have as liquidity
    uint256 LBTokenAmount = ILBTokenNFT(LBPool).balanceOf(address(this), ManDepositID);
    amounts[0] = LBTokenAmount;


ILBRouter(LBrouter).removeLiquidity( 
    IERC20(INTX), // Replace with actual token X address
    IERC20(USDT), // Replace with actual token Y address
    binStep,
    0,
    0,
    Manclaimid,
    amounts,
    address(this),
    block.timestamp + 300
);

}

function approveTokenRewarder() public payable {

ILBTokenNFT(LBPool).approveForAll(LBrouter, true);
ILBTokenNFT(LBPool).approveForAll(MoeRewarder, true);

}

//Collect Rewards

function collectRewards() public payable {
    uint256 rewardbinsAmount = 1;
    uint256[] memory claimid = new uint256[](rewardbinsAmount);
    claimid[0] = CurrentDepositID;
    IRewarder(MoeRewarder).claim(address(this), claimid);
}

//Collect Rewards Custom

function collectRewardsManual(uint256 ManualDepositID) public payable {
    uint256 rewardbinsAmount = 1;
    uint256[] memory claimid = new uint256[](rewardbinsAmount);
    claimid[0] = ManualDepositID;
    IRewarder(MoeRewarder).claim(address(this), claimid);
}


    // Function to receive MNT
    receive() external payable {}

}




