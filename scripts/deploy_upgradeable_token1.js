const { ethers, upgrades } = require('hardhat');

async function main () {
  try{    
    const Token1 = await ethers.getContractFactory('Token1');
    console.log('Deploying Token (removed community)...');
    const token1 = await upgrades.deployProxy(Token1, ["admin wallet address", 
    "Test Token", 
    "TTK", 
    "1000000000000",
    "marketing wallet address",
    "lp wallet address",
    "dex router address",
    2,
    2
  ], { initializer: 'initialize' });
    await token.deployed();
    console.log('Token (removed community) deployed to:', token.address);
  }catch(err){
    console.log(err);
  }
}

main();