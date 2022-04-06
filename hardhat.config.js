require("@nomiclabs/hardhat-waffle");
require('@nomiclabs/hardhat-ethers');
require('@openzeppelin/hardhat-upgrades');
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
  solidity: {
    version: "0.8.11",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000,
      },
    },
  }
};
