let GigBlack        = artifacts.require("./GigBlack.sol");
let GigGold         = artifacts.require("./GigGold.sol");
let GigSilver       = artifacts.require("./GigSilver.sol");
let GigPlatinum     = artifacts.require("./GigPlatinum.sol");
let GigCrowdsale    = artifacts.require("./GigCrowdsale.sol");

const BigNumber = web3.BigNumber;

const decimals = 18;

const config = {
    wallet: web3.eth.accounts[0], 
    addressTxFeeCollector: web3.eth.accounts[1],
    startTime: new BigNumber(1532794353), 
    endTime: new BigNumber(2000000000), 
    
    // 1 GZB = 0.0025 ETH
    rate: new BigNumber(400),                                        
    
    // ETH amount. 8% from total supply of 1 billion tokens is sold on crowdsale
    // 80M GZB = 200k ETH 
    cap: new BigNumber(200000).mul(new BigNumber(10).pow(decimals)), 

    // total GZB supply: 1B
    totalSupply: new BigNumber(1000 * 10**6).mul(new BigNumber(10).pow(decimals)),
    
    // token amount for crowdsale : 8% of total supply = 80M GZB
    amountCrowdsale: new BigNumber(80 * 10**6).mul(new BigNumber(10).pow(decimals)),

    // amount to lock in a fee bank (90% of total supply) = 900M GZB
    amountFeeBank: new BigNumber(900 * 10**6).mul(new BigNumber(10).pow(decimals)),

    partnerWallet: '0x1F5a6E8f32BDdabbcFCB20978c3bF676501e712D'
};


module.exports = (deployer) => {
    deployer.then(async () => {
    
        await deployer.deploy(GigGold, config.addressTxFeeCollector);
        await deployer.deploy(GigSilver, config.addressTxFeeCollector);
        await deployer.deploy(GigPlatinum, config.addressTxFeeCollector);
        await deployer.deploy(GigBlack, config.addressTxFeeCollector);

        await deployer.deploy(
            GigCrowdsale, 
            config.startTime,
            config.endTime,
            config.rate,
            config.cap,
            config.wallet,
            GigBlack.address,
            config.partnerWallet
        );

        // retrieve gigBlack contract interface
        const gigBlack = GigBlack.at(GigBlack.address);

        // turn off fees for crowdsale stage
        await gigBlack.setFeeEnabled(false);
        
        // transfer amount for crowdsale
        await gigBlack.transfer(GigCrowdsale.address, config.amountCrowdsale, {from: config.wallet});

        // transfer amount to the fee bank
        const feeBankAddress = await gigBlack.feeBank(); 
        await gigBlack.transfer(feeBankAddress, config.amountFeeBank, {from: config.wallet});

        return GigCrowdsale.deployed();
    });
};
