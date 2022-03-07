const { ethers, upgrades } = require('hardhat');

async function main () {
  try{
    const BridgeBase = await ethers.getContractFactory('BridgeBase');
    console.log('Deploying BridgeBase...');
    const bridgeBase = await upgrades.deployProxy(BridgeBase, ["0xEC261AaA4A88Ce37671fEa5027b9d3f2f3C3a445", "0xE02a7607817d96f61238b4F5486be924bBFA2124"], 
    { initializer: 'initialize' });
    await bridgeBase.deployed();
    console.log('BridgeBase deployed to:', bridgeBase.address);
  }catch(err){
    console.log(err);
  }
}

main();