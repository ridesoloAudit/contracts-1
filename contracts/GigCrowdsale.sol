pragma solidity ^0.4.21;

import "openzeppelin-solidity/contracts/crowdsale/validation/CappedCrowdsale.sol";
import "openzeppelin-solidity/contracts/crowdsale/validation/TimedCrowdsale.sol";
import "openzeppelin-solidity/contracts/token/ERC20/MintableToken.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./GigBlack.sol";

contract GigCrowdsale is CappedCrowdsale, TimedCrowdsale {
    
    using SafeMath for uint256;

    address public partnerWallet;
    // percent of funds transfered to partner
    uint8 public constant partnerPercent = 10;

    // <531 ETH: 15% bonus
    uint256 public constant BONUS1 = 531 * (10**uint256(18));  
    // <1600 ETH: 30%
    // >1600 ETH: 45%
    uint256 public constant BONUS2 = 1600 * (10**uint256(18));  


    function GigCrowdsale(
        uint256 _startTime, 
        uint256 _endTime, 
        uint256 _rate, 
        uint256 _cap, 
        address _wallet, 
        GigBlack _token, 
        address _partnerWallet) public
    CappedCrowdsale(_cap)
    TimedCrowdsale(_startTime, _endTime)
    Crowdsale(_rate, _wallet, _token)
    {
        partnerWallet = _partnerWallet;
    }

  /**
   * Overrides Crowdsale function 
   * include partner percent payment
   */
  function _forwardFunds() internal {

    uint partnerValue = msg.value.mul(partnerPercent).div(100);
    
    require(partnerValue > 0);
    require(partnerValue < msg.value);
    
    wallet.transfer(msg.value - partnerValue);
    partnerWallet.transfer(partnerValue);
  }
    
  /**
   * Overrides Crowdsale function 
   * @param _weiAmount Value in wei to be converted into tokens
   * @return Number of tokens that can be purchased with the specified _weiAmount
   */
  function _getTokenAmount(uint256 _weiAmount)
    internal view returns (uint256)
  {
    uint256 finalRate;

    // 15% bonus?
    if (_weiAmount < BONUS1) 
        finalRate = rate.mul(115).div(100);
    // 30% bonus
    else if (_weiAmount < BONUS2) 
        finalRate = rate.mul(130).div(100);
    // 45% bonus
    else 
        finalRate = rate.mul(145).div(100);

    return _weiAmount.mul(finalRate);
  }

}
