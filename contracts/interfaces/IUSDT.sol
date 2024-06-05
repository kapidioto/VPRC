// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

interface IUSDT{
    function approve(address spender, uint256 amount) external;

    function transferFrom(address from, address to, uint value) external;

    function transfer(address to, uint value) external;
}