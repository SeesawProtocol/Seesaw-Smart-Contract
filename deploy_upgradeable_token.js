const { ethers, upgrades } = require('hardhat');

async function main () {
  try{    
    const Token = await ethers.getContractFactory('Token');
    console.log('Deploying Token...');
    const token = await upgrades.deployProxy(Token, ["admin wallet address", 
    "Test Token", 
    "TTK", 
    "1000000000000",
    "marketing wallet address",
    "lp wallet address",
    "community wallet address",
    "dex router address",
    2,
    2,
    2
  ], { initializer: 'initialize' });
    await token.deployed();
    console.log('Token deployed to:', token.address);
  }catch(err){
    console.log(err);
  }
}

main();