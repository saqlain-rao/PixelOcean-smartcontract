import hre from "hardhat";

async function main() {
  console.log("Deploying NFTMarketplace...");

  const NFTMarketplace = await hre.ethers.getContractFactory("NFTMarketplace");
  const nftMarketplace = await NFTMarketplace.deploy();

  await nftMarketplace.waitForDeployment();

  const address = await nftMarketplace.getAddress();
  console.log("NFTMarketplace deployed to:", address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
