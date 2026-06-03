const { ethers } = require("hardhat");

async function main() {
  const [deployer, transferAgent, oracle, pauser] = await ethers.getSigners();
  console.log("Deployer:", deployer.address);

  const Registry = await ethers.getContractFactory("ComplianceRegistry");
  const registry = await Registry.deploy(deployer.address, 3); // require QP tier
  await registry.waitForDeployment();
  console.log("ComplianceRegistry:", await registry.getAddress());

  const USDC = await ethers.getContractFactory("MockUSDC");
  const usdc = await USDC.deploy();
  await usdc.waitForDeployment();
  console.log("MockUSDC:", await usdc.getAddress());

  const Fund = await ethers.getContractFactory("TokenizedTreasuryFund");
  const fund = await Fund.deploy(
    "Tokenized Treasury Fund",
    "TTF",
    deployer.address,
    transferAgent.address,
    oracle.address,
    pauser.address,
    await registry.getAddress(),
    await usdc.getAddress(),
    100_000_000_000n, // $100,000 min subscription (6 decimals)
    15                // 0.15% mgmt fee
  );
  await fund.waitForDeployment();
  console.log("TokenizedTreasuryFund:", await fund.getAddress());
}

main().catch((err) => { console.error(err); process.exit(1); });
