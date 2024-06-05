// SPDX-License-Identifier: MIT

import '@uniswap/v3-core/contracts/interfaces/IERC20Minimal.sol';

pragma solidity ^0.7.6;

interface IWETH is IERC20Minimal {
    function deposite() external payable;

    function withdraw(uint) external;
    
    function totalSuply() external view returns(uint);
}