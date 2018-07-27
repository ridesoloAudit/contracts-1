pragma solidity ^0.4.21;

import "./FeeableToken.sol";

import "openzeppelin-solidity/contracts/token/ERC20/MintableToken.sol";
import "openzeppelin-solidity/contracts/token/ERC20/BurnableToken.sol";


contract GigSilver is MintableToken, BurnableToken, FeeableToken {

    string public name = "GigziSilver";
    string public symbol = "GZG";
    
    function GigSilver(address _feeCollector) FeeableToken(_feeCollector) public {
    }

}
