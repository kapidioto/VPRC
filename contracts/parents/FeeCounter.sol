// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import '@uniswap/v2-core/contracts/interfaces/IERC20.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';

contract FeeCounter{
    using SafeMath for uint256;

    address public profitCurrency;
    string public nameOfNet;

    //fee collected
    uint public feeCollected;

    function setProfitAmount(uint amount) public {
        feeCollected = amount;
    }

    // outside contracts
    IUniswapV2Factory factory;

    uint public defaultFee = 5000; //fee procentage, 5%for defaul
    mapping(string => uint) public networkFees;

    constructor(address _profit, address _factory, string memory _name, uint _min, uint _max){
        profitCurrency = _profit;
        nameOfNet = _name;
        factory = IUniswapV2Factory(_factory);
        minAmount = _min;
        zeroFeeAmount = _max;
        networkFees[nameOfNet] = defaultFee;
    }

    function setDefaultFee(uint _fee) public{
        defaultFee = _fee;
    }

    function getDefaultFee() public view returns(uint){
        return defaultFee;
    }

    //total amount
    uint public totalAmount;

    function setTotalAmount(uint _amount) public returns(uint) {
        return totalAmount = _amount;
    }

    function getTotalAmount() public view returns(uint) {
        return totalAmount;
    }

    // network fee, can be calculated only outside contract

    function setNetworkFee(string memory _name, uint _fee) public returns(uint){
        return networkFees[_name] = _fee;
    }

    function getNetworkFee(string memory _name) public view returns(uint){
        return networkFees[_name];
    }

    // volume of swaps and pair fee
    mapping(address => mapping(address => uint)) public swaped;
    mapping (address => mapping (address => uint)) public pairFee;

    function setPairFee(address tokenA, address tokenB) public{
        if(swaped[tokenA][tokenB]>totalAmount) swaped[tokenA][tokenB] = 0;
        totalAmount == 0?pairFee[tokenA][tokenB] = defaultFee - defaultFee.mul(swaped[tokenA][tokenB].mul(100_000).div(1)).div(100_000):
        pairFee[tokenA][tokenB] = defaultFee - defaultFee.mul(swaped[tokenA][tokenB].mul(100_000).div(totalAmount)).div(100_000);
    }

    function chngSwapVol(address tokenA, address tokenB,uint amount) public {
        swaped[tokenA][tokenB]=amount; 
    }

    //amount fee
    uint public minAmount;
    uint public zeroFeeAmount;
    
    function setAmountFeeBorders(uint _min, uint _max) public{
        minAmount = _min;
        zeroFeeAmount = _max;
    }

    function amountFee(uint amount) public view returns(uint){
        require(amount>=minAmount, "LOW AMOUNT");
        uint zeroFee = zeroFeeAmount*(10**IERC20(profitCurrency).decimals());
        // return defaultFee.mul(amount.mul(100_000).div(zeroFeeAmount)).div(100_000);
        return amount>=zeroFee?0:defaultFee - defaultFee.mul(amount.mul(100_000).div(zeroFee)).div(100_000);
    }

    //curency for profit token
    function getProfitAmount(address token, uint amount) public view returns(uint){
        address pairAddress = factory.getPair(profitCurrency, token);
        
        if(pairAddress == address(0)) {
            return amount;
        }else{
            IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
            
            (uint _res0, uint _res1,) = pair.getReserves();

            // decimals
            if(profitCurrency == pair.token0()){
                return((amount*_res0)/_res1);
            }else{
                return((amount*_res1)/_res0);
            }
            // return amount of token0 needed to buy token1
        }
    }

    //Returns amount of tokens bought for profit currency
    function getTokenAmount(address token, uint amount) public view returns(uint){
        address pairAddress = factory.getPair(token, profitCurrency);
        
        if(pairAddress == address(0)) {
            return amount;
        }else{
            IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
            
            (uint _res0, uint _res1,) = pair.getReserves();

            if(token == pair.token0()){
                return((amount*_res0)/_res1);
            }else{
                return((amount*_res1)/_res0);
            }
        }
    }

    //total fee
    function totalFee(address tokenA, address tokenB, uint amount) public view returns(uint){
        return networkFees[nameOfNet] + pairFee[tokenA][tokenB] + amountFee(amount); 
    }
}