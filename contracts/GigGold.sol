pragma solidity ^0.4.21;

import "./FeeableToken.sol";

import "openzeppelin-solidity/contracts/token/ERC20/MintableToken.sol";
import "openzeppelin-solidity/contracts/token/ERC20/BurnableToken.sol";


contract GigGold is MintableToken, BurnableToken, FeeableToken {

    string public name = "GigziGold";
    string public symbol = "GZG";
    
    function GigGold(address _feeCollector) FeeableToken(_feeCollector) public {
    }

}
