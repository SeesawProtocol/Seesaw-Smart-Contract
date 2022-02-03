const { ethers, upgrades } = require('hardhat');

async function main () {
  try{    
    const Token = await ethers.getContractFactory('Token');
    console.log('Deploying Token...');
    const token = await upgrades.deployProxy(Token, ["replace with the admin address here"], { initializer: 'initialize' });
    await token.deployed();
    console.log('Token deployed to:', token.address);
  }catch(err){
    console.log(err);
  }
}

main();