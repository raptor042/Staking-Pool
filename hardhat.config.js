require('dotenv').config();
require("@nomicfoundation/hardhat-toolbox");

const { PRIVATE__KEY ,PRIVATE_KEY, TESTNET_API_URL, MAINNET_API_URL, BSCSCAN_API_KEY } = process.env;

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.19",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  defaultNetwork: "testnet",
  networks: {
    hardhat: {},
    testnet: {
      url: `${TESTNET_API_URL}`,
      accounts: [`0x${PRIVATE__KEY}`]
    },
    mainnet: {
      url: `${MAINNET_API_URL}`,
      accounts: [`0x${PRIVATE_KEY}`]
    },
  },
  paths: {
    sources: "./contracts",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  mocha: {
    timeout: 40000
  },
  etherscan: {
    apiKey: BSCSCAN_API_KEY
  }
};
