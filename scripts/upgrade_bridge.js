// scripts/upgrade_Bridge.js
const { ethers, upgrades } = require('hardhat');

async function main () {
  const BridgeV2 = await ethers.getContractFactory('BridgeV2');
  console.log('Upgrading Bridge...');
  await upgrades.upgradeProxy('replace with the bridge address here', BridgeV2);
  console.log('Bridge upgraded');
}

main();