pragma solidity ^0.4.21;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/StandardToken.sol";

contract FeeableToken is StandardToken, Ownable {

    using SafeMath for uint256;
    
    address public txFeeCollector;
    
    address public feeBank;

    uint public feeMultiplier;
    uint public feeDivider;
    uint public feeLimit;

    uint8 public decimals = 18;
    
    bool public feeEnabled;

    // accounts reserved to avoid fees on transactions
    address[] public accountsReserved;
    
    function FeeableToken(address _feeCollector) public {
        txFeeCollector = _feeCollector;

        // config default 0.2%
        feeMultiplier = 2;
        feeDivider = 1000;

        // by default limit is set to max int (limit is disabled) = 2**256 - 1
        feeLimit = 2**256 - 1;

        // by default fee is enabled on construction
        // this can be changed by owner later (e.g. for crowdsale)
        feeEnabled = true;

        // make _feeCollector avoid collecting fees from its transactions
        accountsReserved.push(_feeCollector);

        // create fee bank and assign an address
        feeBank = this;
    }

    // *******************************************************************************************
    // setFee
    // *******************************************************************************************
    function setFee(uint feeMul, uint feeDiv, uint feeLim) public onlyOwner returns (bool success) {
        feeMultiplier = feeMul;
        feeDivider = feeDiv;
        feeLimit = feeLim;
        return true;
    }

    // *******************************************************************************************
    // addReservedAccount
    // *******************************************************************************************
    function addReservedAccount(address reservedAccount) public onlyOwner returns (bool success) {
        accountsReserved.push(reservedAccount);
        return true;
    }

    // *******************************************************************************************
    // setTxFeeCollector
    // onlyOwner
    // *******************************************************************************************
    function setTxFeeCollector(address feeCollector) public onlyOwner returns (bool success) {
        txFeeCollector = feeCollector;
        return true;
    }

    function setFeeEnabled(bool value) public onlyOwner returns (bool success) {
        feeEnabled = value;
        return true;
    }

    // ***********************************************************************************
    // Override BasicToken.transfer
    // ***********************************************************************************
    function transfer(address _to, uint256 _value) public returns (bool success) {

        processTransfer (msg.sender, _to, _value);

        Transfer        (msg.sender, _to, _value);
        return true;
    }

    // ***********************************************************************************
    // Override ERC20 StandardToken.transferFrom
    // ***********************************************************************************
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        require                  (_value <= allowed[_from][msg.sender]);

        processTransfer         (_from, _to, _value);

        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
        Transfer                    (_from, _to, _value);
        return true;
    }    

    // ***********************************************************************************
    // Fee should not be paid if the fee is disabled or 
    // _from or _to addresses are reserved accounts 
    // **************************************************************   *********************
    function isFeeShouldBePaid(address _from, address _to) internal view returns (bool) {
        if (!feeEnabled)
            return false;
        
        // check if _from and _to addresses belong to reserved addresses
        bool reservedAccount = false;
        for (uint i=0; i<accountsReserved.length; i++) {
            address accountReserved = accountsReserved[i];
            if (_from == accountReserved || _to == accountReserved) {
                reservedAccount = true;
                break;
            }
        } 
        
        if (reservedAccount)
            return false;
        
        return true;
    }

    // ***********************************************************************************
    // Check if the fee bank is not empty and is active for specified _value to be sent
    // ***********************************************************************************
    function calcFee(uint _value) internal view returns (uint)
    {
        // calculate fee
        uint txFee = _value.mul(feeMultiplier).div(feeDivider);

        // normalize
        uint feeLimitWithDecimals = feeLimit * (10**uint256(decimals));
        
        if (txFee > feeLimitWithDecimals) {
            txFee = feeLimitWithDecimals;
        }

        return txFee;
    }


    // ***********************************************************************************
    // Check if the fee bank is not empty and is active for specified _value to be sent
    // ***********************************************************************************
    function isFeeBankActive(uint256 _value) internal view returns (bool)
    {
        // calculate fee
        uint txFee = calcFee(_value);
        return (balances[feeBank] >= txFee);
    }

    // ***********************************************************************************
    // 
    // ***********************************************************************************
    function processTransfer(address _from, address _to, uint256 _value) internal returns (bool) {
        require(_to != address(0));
        require(_value > 0);
        require(balances[_from] >= _value);

        if (isFeeShouldBePaid(_from, _to)) { 
            
            if (isFeeBankActive(_value))
                transferWithFeeFromBank(_from, _to, _value);            
            else 
                transferWithFee (_from, _to, _value);

        } else 
            transferWithoutFee(_from, _to, _value);
        
        return true;
    }

    // *******************************************************************************************
    // transferWithFee
    // update balances according to the fee
    // *******************************************************************************************    
    function transferWithFee(address _from, address _to, uint256 _value) private returns (bool) {

        // init with the default value 
        uint valueWithoutFee = _value;

        // calculate fee
        uint txFee = calcFee(_value);

        // reject tx if no fee
        require(txFee > 0);

        // reject if no money to pay a fee
        require(_value > txFee);

        // calculate value without fee
        valueWithoutFee = _value - txFee;

        // update balances
        // SafeMath.sub will throw if there is not enough balance.
        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(valueWithoutFee);
        balances[txFeeCollector] = balances[txFeeCollector].add(txFee);

        return true;
    }

    // *******************************************************************************************
    // transferWithoutFee
    // *******************************************************************************************    
    function transferWithoutFee(address _from, address _to, uint256 _value) private returns (bool) {
        // update balances
        // SafeMath.sub will throw if there is not enough balance
        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(_value);

        return true;
    }          

    // *******************************************************************************************
    // transferWithFeeFromBank
    // *******************************************************************************************    
    function transferWithFeeFromBank(address _from, address _to, uint256 _value) private returns (bool) {  
        
        // calculate fee
        uint txFee                  = calcFee(_value);

        // reject tx if no fee
        require(txFee > 0);

        transferWithoutFee          (_from, _to, _value);

        balances[feeBank]           = balances[feeBank].sub(txFee);
        balances[txFeeCollector]    = balances[txFeeCollector].add(txFee);

        return true;
    }
}