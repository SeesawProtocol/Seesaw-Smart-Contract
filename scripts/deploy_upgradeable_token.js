const { ethers, upgrades } = require('hardhat');

async function main () {
  try{    
    const Token = await ethers.getContractFactory('Token');
    console.log('Deploying Token...');
    const token = await upgrades.deployProxy(Token, [
      "token name",
      "tokensymbol",
      9, //decimals
      "0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3", //pancake router address
      [
        true, // limitsInEffect
        false, // tradingActive
        false, //swapEnabled
        true, // transferDelayEnabled
        true, //gasLimitActive
        false // swapAndLiquifyEnabled
      ],
      [    
        "1000000000000000000000000000", // total supply
        "100000000000000000000000", // maxTransactionAmount
        "1000000000000000000000000", // minimumTokensBeforeSwap
        "1000000000000000000000000", // maxWallet
        5, // _buyTaxFee
        3, // _buyLiquidityFee
        2, // _buyMarketingFee
        5, // _sellTaxFee
        3, // _sellLiquidityFee
        2, // _sellMarketingFee
        0, // liquidityActiveBlock: 0 means liquidity is not active yet
        0, // tradingActiveBlock : 0 means trading is not active
        "1000000000000000000000000", // gasPriceLimit
      ]        
    ], { initializer: 'initialize' });
    await token.deployed();
    console.log('Token deployed to:', token.address);
  }catch(err){
    console.log(err);
  }
}

main();