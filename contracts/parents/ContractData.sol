// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;
pragma abicoder v2;

contract ContractData {
    
    mapping (string => bool) public allowedNet;
    mapping (address => bool) public allowedToken;

    string public nameOfNet;
    uint public netCount;

    address public profitCurrency;
    address public wrapedGasCoin;

    address public contractFactory;
    address public swapRouter;

    function changeTokensStatus(address[] memory token) public{
        for(uint i;i<token.length;i++){
            allowedToken[token[i]] = !allowedToken[token[i]];
        }
    }

    function setNetworksAllowance(string[] memory _networks) public {
        for(uint i;i<_networks.length;i++){
            allowedNet[_networks[i]] = !allowedNet[_networks[i]];
            allowedNet[_networks[i]]? netCount++:netCount--;
        }
    }

    function setCurentNetwork(string memory _nameOfNet) public {
        require(allowedNet[_nameOfNet], "SUCH CONTRACT DOESN`T DEFINED IN ALLOWED NETWORKS LIST");
        nameOfNet = _nameOfNet;
    }

    function setMainPair(address _profitCurency,address _wrappedGas) public {
        profitCurrency = _profitCurency;
        wrapedGasCoin = _wrappedGas;
    }

    function setUniswapContact(address _factory, address _router) public {
        contractFactory = _factory;
        swapRouter = _router;
    }
}