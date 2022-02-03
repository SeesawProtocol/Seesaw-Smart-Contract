require("@nomiclabs/hardhat-waffle");
require('@nomiclabs/hardhat-ethers');
require('@openzeppelin/hardhat-upgrades');
// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  networks: {
    
    ropsten: {
      url: "https://eth-ropsten.alchemyapi.io/v2/zT6MSYFVB-ojEc0-BbokQELJKOl0YxdS",
      accounts: ["07609aac21400451b4f22ad06686bd388b46f22372cd7b1162e684b762d1628a"]
    }
  },
  solidity: "0.8.4",
};
