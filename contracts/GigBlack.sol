pragma solidity ^0.4.21;

import "./FeeableToken.sol";

import "openzeppelin-solidity/contracts/math/SafeMath.sol";


contract GigBlack is FeeableToken {

    using SafeMath for uint256;

    string public name = "GigziBlack";
    string public symbol = "GZB";
    
    uint256 public constant INITIAL_SUPPLY = 1000 * (10**6) * (10**uint256(decimals));    

    /// *****************************
    /// AccountRewardInfo
    /// *****************************
    struct AccountRewardInfo {

        // address
        address accountAddress;

        // time when last balance change occurred
        uint timeLastChanged;

        // accumulated amount of reward between commits
        uint rewardAccum;

    }

    mapping (address => uint256) accountIndexes;
    AccountRewardInfo[] accounts;


    /// *************************************
    /// Commit reward and reset stats after
    /// reward payments
    /// All rewards should be payed right after a commit
    /// *************************************

    // stores last time of reward reset
    // can be changed only by CA (centracl authority — smart contract owner)
    // when a tx occurred if time < timeLastCommit then reward is reset
    uint256 public timeLastCommit;

    
    /// *************************************
    /// Constructor
    /// *************************************

    function GigBlack(address _feeCollector) public FeeableToken(_feeCollector) {

        totalSupply_ = INITIAL_SUPPLY;
        balances[owner] = INITIAL_SUPPLY;
        
        // add these two addresses as accounts
        addAccountExplicit (owner);
        addAccountExplicit (_feeCollector);

        timeLastCommit = now;
    }


    function hasAccount(address addr) private view returns (bool)
    {
        uint index = accountIndexes[addr];
        return !(index == 0 && addr != owner && addr != txFeeCollector);
    }
    
    function getAccount(address addr) private view returns (AccountRewardInfo storage info) {
        return accounts[accountIndexes[addr]];
    }

    function getAccountsCount() public view returns (uint count)
    {
        return accounts.length;
    }

    function getCA() public view returns (address) {
        return owner;
    }

    /// *************************************************
    /// Internal functions
    /// *************************************************
    function addAccountExplicit(address addr) private
    {
        accounts.push(AccountRewardInfo({
            accountAddress: addr,
            timeLastChanged: now,
            rewardAccum: 0
        }));

        accountIndexes[addr] = accounts.length - 1;
    }


    // ****************************************************
    // Check account and if account doesn't exist - add to the map
    // ****************************************************
    function checkAndPrepareAccount(address addr) private
    {
        if (!hasAccount(addr)) {
            // account not found, add one
            addAccountExplicit  (addr);
        }
    }    
    
    // *******************************************************************************************
    // override setTxFeeCollector
    // TODO: update rewardInfo for account[1]
    // *******************************************************************************************
    function setTxFeeCollector(address feeCollector) public onlyOwner returns (bool success) {
        FeeableToken.setTxFeeCollector    (feeCollector);
        accounts[1].accountAddress        = feeCollector;

        return true;
    }

    function commitRewards() public onlyOwner returns (bool success) {
        timeLastCommit  = now;
        return true;
    }

    // *******************************************************************************************
    // getAccountReward
    // Estimate account reward in percent
    // *******************************************************************************************
    function getAccountReward(address addr) public view returns (uint, uint, uint)
    {
        if (!hasAccount(addr)) {
            return (0,0,now);
        }
        
        AccountRewardInfo memory accInfo = getAccount(addr);

        // calc period between current time and last time of the commit or last change in the account's balance
        uint rewardPeriod           = now - (accInfo.timeLastChanged > timeLastCommit ? accInfo.timeLastChanged : timeLastCommit);

        // skip previous accumulation, when last operation on the account was the commitment
        uint prevAccum              =  (accInfo.timeLastChanged > timeLastCommit) ? accInfo.rewardAccum : 0;

        // handle commit state
        uint rewardAccum            =  prevAccum + balanceOf(accInfo.accountAddress) * rewardPeriod;

        // total supply multiply by the period between now and the last commit
        uint supplyTimeTotal        = (now - timeLastCommit) * totalSupply_;

        if (supplyTimeTotal == 0)
            return (0,0,now);
        
        return (rewardAccum, supplyTimeTotal, now);
    }


    // *******************************************************************************************
    // getAccountRewardByIdx
    // *******************************************************************************************
    function getAccountRewardByIdx(uint accountIdx) public view returns (address, uint, uint, uint)
    {
        address addr = accounts[accountIdx].accountAddress;
        uint reward;
        uint total;
        uint time;
        (reward, total, time) = getAccountReward(accounts[accountIdx].accountAddress);
        return (addr, reward, total, time);
    }

    // *******************************************************************************************
    // private updateAccountReward method
    // *******************************************************************************************
    function updateAccountReward(address addr) private
    {
        // prepare account (create if needed) 
        checkAndPrepareAccount      (addr);

        AccountRewardInfo storage accInfo  = getAccount(addr);

        // calc period between current time and last time of the commit or last change in the account's balance
        uint rewardPeriod           = now - (accInfo.timeLastChanged > timeLastCommit ? accInfo.timeLastChanged : timeLastCommit);

        // skip previous accumulation, when last operation on the account was the commitment
        uint prevAccum              =  (accInfo.timeLastChanged > timeLastCommit) ? accInfo.rewardAccum : 0;

        // set reward
        accInfo.rewardAccum         = prevAccum + balanceOf(accInfo.accountAddress) * rewardPeriod;

        // set current time
        accInfo.timeLastChanged     = now;
    }       
    
    // *******************************************************************************************
    // Override Feeable.processTransfer function
    // Extend transfer with reward calculations
    // *******************************************************************************************
    function processTransfer(address _from, address _to, uint256 _value) internal returns (bool) {

        // update rewards before transfer
        updateAccountReward          (_from);
        updateAccountReward          (_to);

        FeeableToken.processTransfer (_from, _to, _value);
    }
 
}
