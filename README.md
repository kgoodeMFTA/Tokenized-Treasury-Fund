# Tokenized Treasury Fund (TTF)

> A permissioned ERC-20 tokenized money-market fund — built end-to-end with smart contracts, full business-analyst artifacts, and a transparency dashboard. Modeled on the production mechanics of **BlackRock BUIDL**, **Ondo OUSG**, **Franklin BENJI**, and **Superstate USTB**.

[![Solidity](https://img.shields.io/badge/Solidity-0.8.24-363636?logo=solidity)](https://soliditylang.org)
[![Hardhat](https://img.shields.io/badge/Hardhat-2.22-yellow?logo=ethereum)](https://hardhat.org)
[![OpenZeppelin](https://img.shields.io/badge/OpenZeppelin-5.0-blue)](https://openzeppelin.com)
[![Tests](https://img.shields.io/badge/tests-11%20passing-brightgreen)]()
[![License](https://img.shields.io/badge/license-MIT-lightgrey)]()

---

## Why this project exists

The on-chain Real-World Asset (RWA) market reached **$33.7B** in May 2026, and tokenized U.S. Treasuries alone account for **~$6.8B** of that — the single largest sub-category on-chain ([rwa.xyz via FinanceFeeds, May 2026](https://financefeeds.com/buidl-ousg-benji-tokenized-treasury-market-2026/)).

A Tokenization Business Analyst at a firm like **Securitize**, **Ondo**, **Centrifuge**, or **Tokeny** has to hold three things in their head at once:

1. **The product mechanics** — how a permissioned ERC-20 actually mints, yields, and redeems.
2. **The regulatory wrapper** — Reg D 506(c), Reg S, OFAC, FINRA, transfer-agent obligations.
3. **The operational reality** — KYC refresh, NAV strikes, cap-table reconciliation, incident response.

This repository demonstrates all three by building a working tokenized treasury fund and documenting every business decision behind it.

## What's inside

```
tokenized-treasury-fund/
├── contracts/                         Solidity smart contracts
│   ├── TokenizedTreasuryFund.sol      ERC-20 share + subscribe/redeem/yield/pause
│   ├── ComplianceRegistry.sol         On-chain whitelist (KYC, jurisdiction, sanctions)
│   ├── interfaces/                    IComplianceRegistry interface
│   └── mocks/                         MockUSDC for tests
├── test/                              Hardhat test suite (13 tests, all critical paths)
├── scripts/
│   ├── deploy.js                      Deployment script (local + Sepolia)
│   └── simulate-lifecycle.js          30-day fund-lifecycle simulation
├── dashboard/
│   └── index.html                     Static transparency dashboard (Chart.js)
├── docs/                              Business-analyst artifacts
│   ├── 01-business-requirements.md    BRD with FRs, NFRs, stakeholders, objectives
│   ├── 02-compliance-matrix.md        15 controls × on/off-chain × evidence × owner
│   ├── 03-data-model.md               Conceptual model, entities, recon queries
│   ├── 04-process-flows.md            6 sequence diagrams (Mermaid)
│   ├── 05-user-stories.md             User stories + acceptance + traceability matrix
│   └── 06-market-context.md           Competitive landscape (BUIDL, OUSG, USDY, ...)
├── hardhat.config.js
└── package.json
```

## The design at a glance

```
Investor ──► Transfer Agent ──► TokenizedTreasuryFund (ERC-20)
                  │                       │
                  │                       ├─► ComplianceRegistry (whitelist gate)
                  │                       ├─► Oracle (daily NAV + yield)
                  │                       └─► Pauser (emergency halt)
                  ▼
              KYC + Cap Table
              (Securitize-eq.)
```

- **Permissioned ERC-20** — the dominant production pattern (BUIDL, OUSG, USTB all use it). Compliance logic lives behind an `IComplianceRegistry` interface so an ERC-3643/T-REX swap is non-breaking.
- **Transfer agent as a first-class role** — codifies the Securitize-equivalent off-chain decision-maker. Force-transfers require an on-chain `reason` string for audit.
- **NAV via oracle + yield as new shares (BUIDL model)** — daily NAV update; yield distributed by minting pro-rata shares rather than rebasing or cash dividends.
- **Defence in depth** — every material risk has both an on-chain preventive control and an off-chain detective control (see `docs/02-compliance-matrix.md`).

## Quick start

```bash
npm install
npx hardhat compile
npx hardhat test           # runs the 13-test suite
npx hardhat run scripts/simulate-lifecycle.js   # 30-day end-to-end simulation
open dashboard/index.html  # opens the transparency dashboard
```

## Test coverage highlights

11 tests passing, covering every Must-have functional requirement:

| Area | What's tested |
|---|---|
| Compliance gating | Non-whitelisted blocked, sanctioned blocked, sub-minimum blocked, blocked-jurisdiction blocked |
| Subscribe / redeem | Mint at NAV, burn at NAV, stale-NAV revert |
| Yield distribution | Pro-rata share mint, supply delta = bps × supply / 10,000 |
| Operational controls | Force-transfer with reason, pause halts all transfers |

Sample simulation output (30 days, daily yield, 1 partial redemption):

```
Day 1  Alice subscribes $500K  → 500,000 TTF
Day 1  Bob subscribes   $2M    → 2,000,000 TTF
Day 15 Bob redeems $500K       → −500,000 TTF
Day 30 NAV/share              = 1.00360
Day 30 Total supply           = 2,082,507 TTF (incl. yield)
```



## License

MIT. Educational / portfolio project. Not a real fund. Not investment advice.
