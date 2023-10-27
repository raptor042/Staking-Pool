// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  const supply = await hre.ethers.parseEther("100000000");

  const stWETH = await hre.ethers.deployContract("stWETH", ["Staked WETH", "stWETH", supply]);

  await stWETH.waitForDeployment();

  console.log(
    `stWETH contract deployed at ${stWETH.target}`
  );

  const staking = await hre.ethers.deployContract("Staking");

  await staking.waitForDeployment();

  console.log(
    `Staking contract deployed at ${staking.target}`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});