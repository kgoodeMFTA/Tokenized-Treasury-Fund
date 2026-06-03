# Business Requirements Document — Tokenized Treasury Fund (TTF)

| | |
|---|---|
| **Document ID** | BRD-TTF-001 |
| **Version** | 1.0 |
| **Owner** | Business Analyst, Tokenization |
| **Status** | Draft for review |
| **Last updated** | June 2026 |

---

## 1. Executive summary

The on-chain tokenized U.S. Treasury market grew from $0 in March 2024 to **~$6.8B AUM** by May 2026, led by BlackRock's BUIDL (~$2.6B), Ondo's OUSG/USDY (~$2.7B combined), Franklin Templeton's BENJI (~$800M), Superstate's USTB (~$836M), and Circle's USYC (~$3B). Total on-chain RWA market cap reached **$33.7B** — an all-time high — per [rwa.xyz](https://rwa.xyz) analytics cited in [FinanceFeeds, May 2026](https://financefeeds.com/buidl-ousg-benji-tokenized-treasury-market-2026/).

The Tokenized Treasury Fund (TTF) is a portfolio reference implementation of a permissioned ERC-20 money-market fund. It demonstrates the operational, compliance, and product mechanics required to launch and run a fund of this type from a Business Analyst's perspective.

## 2. Business objectives

| # | Objective | Success metric |
|---|---|---|
| BO-1 | Offer qualified-purchaser investors a 24/7, atomically-settled exposure to short-duration U.S. Treasuries | Subscriptions onboarded within 1 business day; redemption settled T+0 |
| BO-2 | Enforce all SEC / FINRA / OFAC compliance obligations on-chain and off-chain | Zero unauthorised holders at any block; 100% KYC freshness |
| BO-3 | Reduce operational cost vs. legacy fund admin by ≥40% | Cap-table reconciliation hours / month |
| BO-4 | Enable composability with DeFi venues for eligible holders | Listings on ≥2 permissioned lending markets within 6 months of GA |
| BO-5 | Maintain NAV transparency at attestation cadence ≤24h | Proof-of-Reserve attestations published daily |

## 3. Scope

### In scope
- Permissioned ERC-20 share token with on-chain whitelist enforcement
- Off-chain transfer agent integration (Securitize-equivalent role)
- Daily NAV update via oracle (Chainlink Proof of Reserve target)
- Yield distribution via additional-share minting (BUIDL model)
- Subscribe / redeem against a stablecoin (USDC) settlement leg
- Emergency pause, force-transfer, and sanctions screening

### Out of scope (v1)
- Secondary trading on a permissioned ATS (planned v2 — Securitize Markets integration)
- Multi-chain bridging (planned v2 — canonical registry stays on Ethereum)
- Tokenized fund-of-funds wrapper (planned v3, OUSG model)
- Retail (non-QP) distribution under Reg S

## 4. Stakeholders

| Stakeholder | Role | Interest |
|---|---|---|
| Fund manager (e.g., asset-management arm) | Owns IMA, sets investment policy | Net yield, AUM growth |
| Transfer agent (Securitize-equivalent) | KYC, cap table, transfer restriction enforcement | Operational accuracy, regulatory cover |
| Compliance officer | Sanctions, jurisdiction, accreditation | Zero violations |
| Custodian (e.g., BNY Mellon for BUIDL) | Holds underlying T-bills | Reconciliation accuracy |
| Auditor (PwC / EY / Deloitte) | Attests NAV and reserves | Audit-trail completeness |
| Investor (QP) | Subscribes / redeems | Yield, liquidity, transparency |
| Smart-contract auditor | Pre-launch security review | Findings closure |
| Regulator (SEC, FINRA, MAS, FCA) | Enforces securities laws | Reporting and oversight |

## 5. Functional requirements

| ID | Requirement | Priority |
|---|---|---|
| FR-1 | Only addresses whitelisted in the compliance registry may hold or receive TTF tokens | Must |
| FR-2 | The compliance registry must record jurisdiction, investor type, KYC expiry, and sanctions status per address | Must |
| FR-3 | KYC must be re-verified at least every 12 months; expiry on-chain blocks transfers | Must |
| FR-4 | Subscriptions must enforce a minimum (default $100,000) and reject below it | Must |
| FR-5 | NAV per share must be updated at least daily; subscriptions / redemptions must revert if NAV is >36h stale | Must |
| FR-6 | Yield must be distributed by minting new shares pro-rata (no cash dividend) | Must |
| FR-7 | The transfer agent must be able to force-transfer tokens (lost-wallet recovery, court order) with on-chain reason logging | Must |
| FR-8 | A pauser role must be able to halt all transfers and subscriptions in an incident | Must |
| FR-9 | Blocked jurisdictions (OFAC sanctioned) must reject registration and transfers | Must |
| FR-10 | All admin actions must emit indexed events for off-chain audit | Must |
| FR-11 | Management fee must be configurable and capped at 5% (500 bps) | Should |
| FR-12 | Required investor tier (retail / accredited / QP / institutional) must be configurable per token | Should |

## 6. Non-functional requirements

| ID | Requirement | Target |
|---|---|---|
| NFR-1 | Gas per subscribe / redeem | ≤ 120K gas |
| NFR-2 | Smart-contract code coverage | ≥ 90% |
| NFR-3 | Audit findings closed before mainnet | 100% high / critical |
| NFR-4 | NAV oracle staleness alert | < 1h |
| NFR-5 | Cap-table reconciliation vs. custodian | T+0, automated |
| NFR-6 | Sanctions screening refresh | Daily (OFAC SDN delta) |

## 7. Regulatory framework

Reference implementation assumes a U.S. **Reg D 506(c)** offering restricted to qualified purchasers, mirroring BUIDL and OUSG ([Eco, May 2026](https://eco.com/support/en/articles/15254006-ousg-vs-buidl-vs-usdy-yield-2026-tokenized-t-bills-compared)). A parallel **Reg S** sleeve for non-U.S. retail (USDY model) is documented but not built in v1.

| Obligation | How addressed | Owner |
|---|---|---|
| Reg D 506(c) accreditation verification | Transfer agent KYC + on-chain `investorType >= QP` | Compliance officer |
| Reg S non-U.S. eligibility | Jurisdiction tag + blocked-US flag | Compliance officer |
| OFAC sanctions screening | Daily SDN delta + on-chain `sanctioned` flag | Compliance officer |
| 1940 Act fund disclosures | Off-chain prospectus + on-chain transparency dashboard | Fund manager |
| FINRA broker-dealer settlement | Securitize Markets-equivalent ATS (out of scope v1) | Transfer agent |
| State money-transmitter laws | Stablecoin issuer (USDC / Circle) responsibility | External |

## 8. Assumptions and constraints

- Settlement stablecoin is USDC (6-decimals, mintable/redeemable 1:1 with USD).
- Underlying T-bill custody, daily Proof-of-Reserve attestation, and NAV calculation are performed off-chain by the fund administrator and posted on-chain by an oracle role.
- The canonical share registry lives on Ethereum; multi-chain mirrors are out of scope v1.
- Transfer-agent actions remain authoritative — the smart contract codifies their decisions, it does not replace them.

## 9. Acceptance criteria

The project is considered "ready for design phase" when:

1. All Must-have FRs have a corresponding user story + acceptance test.
2. The compliance matrix (`02-compliance-matrix.md`) is signed off by Compliance.
3. The data model (`03-data-model.md`) is signed off by Engineering.
4. The process flows (`04-process-flows.md`) are signed off by Operations.
5. Smart contract test coverage is ≥ 90% with all critical paths covered.
