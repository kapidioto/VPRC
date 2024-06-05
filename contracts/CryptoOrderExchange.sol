// SPDX-License-Identifier: MIT

/* 
    --Vicious - fruitless--
    --Virtue is abundant.--
*/

pragma solidity ^0.7.6;
pragma abicoder v2;

import './parents/MultiOwners.sol';
import './parents/FeeCounter.sol';
import './parents/ContractData.sol';
import './interfaces/IWETH.sol';
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';

contract CryptoOrderExchange is MultiOwners{

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct ExecSwap{
        address token;  
        address customer; 
        uint amount; 
        uint returnedFee;
    }

    event RecivedFunds(
        address customer,
        address tokenIn,
        address tokenOut,
        uint amount,
        uint recived,
        uint fee
    );

    // OUTSIDE CONTRACTS
    ContractData data = new ContractData();
    FeeCounter fee;

    //INITIAL CONTRACT EVENT
    constructor(address[] memory newOwners,
    address[] memory token,
    string[] memory network,
    string memory _nameOfNet,
    address _stable,
    address _gas,
    address _factory,
    address _router,
    uint _minAmount,
    uint _zeroFee
    ) 
    MultiOwners(newOwners){
        data.changeTokensStatus(token);
        data.setNetworksAllowance(network);
        data.setCurentNetwork(_nameOfNet);
        data.setMainPair(_stable,_gas);
        data.setUniswapContact(_factory, _router);
        fee = new FeeCounter(_stable, _factory, _nameOfNet, _minAmount, _zeroFee);
        emit DesidionIsMade(0, newOwners, block.timestamp);
    }
    
    receive() external payable {}

    function changeTokenStatus(address[] memory token, uint voteingNumber)
    external
    isVoted(voteingNumber)
    isOwner(){
        data.changeTokensStatus(token);
    }

    function setNetworks(string[] memory networks, uint voteingNumber)
    external
    isOwner()
    isVoted(voteingNumber){
        data.setNetworksAllowance(networks);
    }

    // FEE CONTRACT USAGE

    function setNetworkFee(string memory _net, uint _fee, uint voteingNumber) 
    external 
    isOwner()  
    isVoted(voteingNumber){
        fee.setNetworkFee(_net, _fee);
    }

    function setAmountFeeBorders(uint _minAmount, uint _zeroFeeAmount, uint voteingNumber) 
    external 
    isOwner()
    isVoted(voteingNumber){
        fee.setAmountFeeBorders(_minAmount,_zeroFeeAmount);
    }

    function custommerSwap(
        address tokenIn,
        address tokenOut,
        uint _amount
    ) external  {
        require(data.allowedToken(tokenIn), "UNKNOWN TOKEN!");
        require(data.allowedToken(tokenOut), "UNKNOWN TOKEN!");
        require(IERC20(tokenIn).balanceOf(msg.sender)>=_amount, "YOU HAVEN`T ENOUGHT TOKENS");

        uint profAmount = fee.getProfitAmount(tokenIn, _amount);
        
        fee.setPairFee(tokenIn, tokenOut);
        fee.setTotalAmount(fee.totalAmount() + profAmount);
        uint expectedFee = fee.totalFee(tokenIn, tokenOut, profAmount);

        fee.chngSwapVol(tokenIn, tokenOut, profAmount);

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), _amount);
        
        emit RecivedFunds(msg.sender, tokenIn, tokenOut, _amount, profAmount, expectedFee);
    }

    function globalSwap(
        address tokenIn,
        address tokenOut,
        uint _amount,
        uint voteingNumber
    )
    external
    isVoted(voteingNumber)
    isOwner()
    returns(uint amountOut){
        require(IERC20(tokenIn).balanceOf(address(this))>=_amount,"THERE ARE NOT ENOUGHT TOKENS TO SWAP IT");

        uint amount = fee.getProfitAmount(tokenIn, _amount);

        fee.chngSwapVol(tokenIn, tokenOut, fee.swaped(tokenIn, tokenOut) - amount);
        
        IERC20(tokenIn).safeApprove(data.swapRouter(), _amount);

        ISwapRouter.ExactInputSingleParams memory params =
            ISwapRouter.ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: uint24(3_000),
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: _amount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        amountOut = ISwapRouter(data.swapRouter()).exactInputSingle(params);

        fee.setPairFee(tokenIn, tokenOut);
    }

    function sendToCustomer(ExecSwap[] memory swap,
    uint voteingNumber)
    external
    isOwner()
    isVoted(voteingNumber)
    returns(uint){
        for(uint i;i<swap.length;i++){   

            address token = swap[i].token;
            address customer = swap[i].customer;
            uint amount = swap[i].amount;
            uint returnedFee = swap[i].returnedFee;

            require(IERC20(token).balanceOf(address(this))>=amount,"INVALID ARRAY INPUT");

            uint sendingAmount = amount - returnedFee.mul(amount).div(100_000);

            IERC20(token).safeApprove(customer, sendingAmount);
            IERC20(token).safeTransfer(customer, sendingAmount);
            IERC20(token).safeApprove(customer, 0);
            
            uint profitCur = fee.getProfitAmount(token, sendingAmount);
            fee.setTotalAmount(fee.totalAmount() - profitCur);
            fee.setProfitAmount(
                    fee.feeCollected() + fee.getProfitAmount(token, amount - sendingAmount)
                );
        }

        return fee.totalAmount();
    }

    function setRewards(address[] memory awarded, uint voteingNumber) 
    external
    isOwner()
    isHonest(awarded)
    isVoted(voteingNumber){
        uint spended; 
        for(uint i;i<awarded.length; i++){
            require(owners[awarded[i]].license,"AWARDED ARRAY CONTAINS ADDRESS THAT ISN`T OWNER");
            spended += gasSpended[awarded[i]];
        }
        for(uint i;i<awarded.length; i++){
            uint coef = gasSpended[awarded[i]].mul(100_000).div(spended);
            rewards[awarded[i]] += fee.feeCollected().mul(coef).div(100_000);

            gasSpended[awarded[i]] = 0;
        }
        emit RevardDefinded(fee.feeCollected());
        fee.setProfitAmount(0);
    }

    function getReward(address token)
    external
    isOwner(){
        require(IERC20(token).balanceOf(address(this) != 0,"CONTRACT DOESN`T HAVE SUCH TOKEN")
        if(rewards[msg.sender]>fee.totalAmount()) rewards[msg.sender]=0;
        uint collect = fee.getTokenAmount(token, rewards[msg.sender]);
        if(IERC20(token).balanceOf(address(this))<=collect) collect = IERC20(token).balanceOf(address(this));

        IERC20(token).safeApprove(msg.sender, collect);
        IERC20(token).safeTransfer(msg.sender,collect);
        IERC20(token).safeApprove(msg.sender, 0);

        rewards[msg.sender] -= fee.getProfitAmount(token, collect);
    }
}