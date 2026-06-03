/**
 * Simulates a 30-day fund lifecycle so a recruiter (or you in an interview) can
 * see the BUIDL-style mechanics end-to-end:
 *
 *   Day 0  - register investors (QP whitelist)
 *   Day 1  - investors subscribe via the transfer agent
 *   Days 1-30 - oracle posts daily NAV + 12bps daily yield (~4.4% APY)
 *   Day 15 - one investor partial-redeems
 *   Day 30 - print final cap table and AUM
 */
const { ethers } = require("hardhat");

const US = "0x" + Buffer.from("US").toString("hex");
const SG = "0x" + Buffer.from("SG").toString("hex");
const TIER_QP = 3;
const TIER_INSTITUTIONAL = 4;
const ONE_DAY = 24 * 3600;

async function main() {
  const [admin, ta, oracle, pauser, alice, bob, distributor] = await ethers.getSigners();

  const Registry = await ethers.getContractFactory("ComplianceRegistry");
  const registry = await Registry.deploy(admin.address, TIER_QP);

  const USDC = await ethers.getContractFactory("MockUSDC");
  const usdc = await USDC.deploy();

  const Fund = await ethers.getContractFactory("TokenizedTreasuryFund");
  const fund = await Fund.deploy(
    "Tokenized Treasury Fund", "TTF",
    admin.address, ta.address, oracle.address, pauser.address,
    await registry.getAddress(), await usdc.getAddress(),
    100_000_000_000n, 15
  );

  const expiry = Math.floor(Date.now() / 1000) + 365 * ONE_DAY;
  await registry.registerInvestor(alice.address, US, TIER_QP, expiry);
  await registry.registerInvestor(bob.address, SG, TIER_INSTITUTIONAL, expiry);
  await registry.registerInvestor(distributor.address, US, TIER_INSTITUTIONAL, expiry);

  console.log("\n=== Day 1: Subscriptions ===");
  await fund.connect(ta).subscribe(alice.address, 500_000_000_000n);   // $500K
  await fund.connect(ta).subscribe(bob.address,   2_000_000_000_000n); // $2M
  console.log(`Alice: ${ethers.formatUnits(await fund.balanceOf(alice.address), 6)} TTF`);
  console.log(`Bob:   ${ethers.formatUnits(await fund.balanceOf(bob.address),   6)} TTF`);

  let nav = 100_000_000n; // 1.00
  for (let day = 1; day <= 30; day++) {
    await ethers.provider.send("evm_increaseTime", [ONE_DAY]);
    await ethers.provider.send("evm_mine");
    nav = nav + 12_000n; // +0.012% NAV/day
    await fund.connect(oracle).updateNav(nav);
    await fund.connect(oracle).distributeYield(12, distributor.address);

    if (day === 15) {
      console.log("\n=== Day 15: Bob partial redemption ($500K worth) ===");
      await fund.connect(ta).redeem(bob.address, 500_000_000_000n);
    }
  }

  console.log("\n=== Day 30: Final state ===");
  console.log(`NAV/share:        ${ethers.formatUnits(await fund.navPerShare(), 8)}`);
  console.log(`Total supply:     ${ethers.formatUnits(await fund.totalSupply(),  6)} TTF`);
  console.log(`Alice balance:    ${ethers.formatUnits(await fund.balanceOf(alice.address),  6)} TTF`);
  console.log(`Bob balance:      ${ethers.formatUnits(await fund.balanceOf(bob.address),    6)} TTF`);
  console.log(`Distributor pool: ${ethers.formatUnits(await fund.balanceOf(distributor.address), 6)} TTF`);
}

main().catch((e) => { console.error(e); process.exit(1); });
