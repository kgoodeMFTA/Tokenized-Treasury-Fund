const { expect } = require("chai");
const { ethers } = require("hardhat");

// Helper: ISO-3166 alpha-2 country code as bytes2
const j = (code) => ethers.encodeBytes32String(code).slice(0, 6); // 0x + 4 hex = 2 bytes
const US = "0x" + Buffer.from("US").toString("hex");
const SG = "0x" + Buffer.from("SG").toString("hex");
const KP = "0x" + Buffer.from("KP").toString("hex");

const TIER_RETAIL = 1;
const TIER_ACCREDITED = 2;
const TIER_QP = 3;
const TIER_INSTITUTIONAL = 4;

describe("TokenizedTreasuryFund", function () {
  let admin, transferAgent, oracle, pauser, investorA, investorB, distributor, sanctioned;
  let registry, fund, usdc;
  const ONE_YEAR = 365 * 24 * 60 * 60;

  beforeEach(async function () {
    [admin, transferAgent, oracle, pauser, investorA, investorB, distributor, sanctioned] =
      await ethers.getSigners();

    const Registry = await ethers.getContractFactory("ComplianceRegistry");
    registry = await Registry.deploy(admin.address, TIER_QP);

    const USDC = await ethers.getContractFactory("MockUSDC");
    usdc = await USDC.deploy();

    const Fund = await ethers.getContractFactory("TokenizedTreasuryFund");
    fund = await Fund.deploy(
      "Tokenized Treasury Fund",
      "TTF",
      admin.address,
      transferAgent.address,
      oracle.address,
      pauser.address,
      await registry.getAddress(),
      await usdc.getAddress(),
      100_000_000_000n, // $100,000 min (6 decimals)
      15                // 0.15% mgmt fee
    );

    const expiry = Math.floor(Date.now() / 1000) + ONE_YEAR;
    await registry.registerInvestor(investorA.address, US, TIER_QP, expiry);
    await registry.registerInvestor(investorB.address, SG, TIER_INSTITUTIONAL, expiry);
    await registry.registerInvestor(distributor.address, US, TIER_INSTITUTIONAL, expiry);
  });

  describe("Compliance gating", function () {
    it("blocks subscription for non-whitelisted investor", async function () {
      await expect(
        fund.connect(transferAgent).subscribe(sanctioned.address, 100_000_000_000n)
      ).to.be.revertedWithCustomError(fund, "NotWhitelisted");
    });

    it("blocks transfer to non-whitelisted recipient", async function () {
      await fund.connect(transferAgent).subscribe(investorA.address, 100_000_000_000n);
      await expect(
        fund.connect(investorA).transfer(sanctioned.address, 1_000_000n)
      ).to.be.revertedWithCustomError(fund, "NotWhitelisted");
    });

    it("blocks subscription below minimum", async function () {
      await expect(
        fund.connect(transferAgent).subscribe(investorA.address, 1_000_000n) // $1
      ).to.be.revertedWithCustomError(fund, "BelowMinimum");
    });

    it("blocks sanctioned investor even if previously registered", async function () {
      const expiry = Math.floor(Date.now() / 1000) + ONE_YEAR;
      await registry.updateInvestor(investorA.address, TIER_QP, expiry, true);
      await expect(
        fund.connect(transferAgent).subscribe(investorA.address, 100_000_000_000n)
      ).to.be.revertedWithCustomError(fund, "NotWhitelisted");
    });
  });

  describe("Subscribe / Redeem flow", function () {
    it("mints shares at NAV on subscribe", async function () {
      // NAV starts at 1.00 -> $100,000 = 100,000 shares
      const tx = await fund.connect(transferAgent).subscribe(investorA.address, 100_000_000_000n);
      await expect(tx).to.emit(fund, "Subscribed");
      expect(await fund.balanceOf(investorA.address)).to.equal(100_000_000_000n);
    });

    it("redeems shares for stable amount at NAV", async function () {
      await fund.connect(transferAgent).subscribe(investorA.address, 100_000_000_000n);
      await fund.connect(oracle).updateNav(101_000_000n); // NAV up 1%
      const tx = await fund.connect(transferAgent).redeem(investorA.address, 100_000_000_000n);
      await expect(tx).to.emit(fund, "Redeemed");
      expect(await fund.balanceOf(investorA.address)).to.equal(0n);
    });

    it("reverts when NAV is stale", async function () {
      await fund.connect(transferAgent).subscribe(investorA.address, 100_000_000_000n);
      // Fast-forward 48 hours
      await ethers.provider.send("evm_increaseTime", [48 * 3600]);
      await ethers.provider.send("evm_mine");
      await expect(
        fund.connect(transferAgent).subscribe(investorA.address, 100_000_000_000n)
      ).to.be.revertedWithCustomError(fund, "StaleNav");
    });
  });

  describe("Yield distribution", function () {
    it("mints new shares to distributor proportional to supply", async function () {
      await fund.connect(transferAgent).subscribe(investorA.address, 100_000_000_000n);
      const supplyBefore = await fund.totalSupply();
      // 12 bps daily yield (~4.4% APY equivalent)
      await fund.connect(oracle).distributeYield(12, distributor.address);
      const supplyAfter = await fund.totalSupply();
      const expected = (supplyBefore * 12n) / 10_000n;
      expect(supplyAfter - supplyBefore).to.equal(expected);
      expect(await fund.balanceOf(distributor.address)).to.equal(expected);
    });
  });

  describe("Transfer agent overrides", function () {
    it("force-transfers from one whitelisted address to another", async function () {
      await fund.connect(transferAgent).subscribe(investorA.address, 100_000_000_000n);
      await fund.connect(transferAgent).forceTransfer(
        investorA.address,
        investorB.address,
        50_000_000_000n,
        "Court order #2026-04-117"
      );
      expect(await fund.balanceOf(investorB.address)).to.equal(50_000_000_000n);
    });
  });

  describe("Pause", function () {
    it("blocks subscribe when paused", async function () {
      await fund.connect(pauser).pause();
      await expect(
        fund.connect(transferAgent).subscribe(investorA.address, 100_000_000_000n)
      ).to.be.revertedWithCustomError(fund, "EnforcedPause");
    });
  });

  describe("Jurisdiction blocking", function () {
    it("blocks investors from a sanctioned jurisdiction", async function () {
      const expiry = Math.floor(Date.now() / 1000) + ONE_YEAR;
      const dprk = "0x" + Buffer.from("KP").toString("hex");
      await registry.registerInvestor(sanctioned.address, dprk, TIER_INSTITUTIONAL, expiry);
      await registry.setBlockedJurisdiction(dprk, true);
      await expect(
        fund.connect(transferAgent).subscribe(sanctioned.address, 100_000_000_000n)
      ).to.be.revertedWithCustomError(fund, "NotWhitelisted");
    });
  });
});
