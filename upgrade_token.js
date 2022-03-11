// scripts/upgrade_Token.js
const { ethers, upgrades } = require('hardhat');

async function main () {
  const TokenV2 = await ethers.getContractFactory('TokenV2');
  console.log('Upgrading Token...');
  await upgrades.upgradeProxy('replace with the token address here', TokenV2);
  console.log('Token upgraded');
}

main();