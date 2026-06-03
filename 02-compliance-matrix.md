# Compliance Control Matrix — Tokenized Treasury Fund

Each row maps a regulatory obligation to the **control** that enforces it, the **layer** where it lives (on-chain / off-chain), and the **evidence** an auditor can pull.

| # | Obligation | Source | Control | Layer | Evidence artifact | Owner |
|---|---|---|---|---|---|---|
| C-01 | Sell securities only to qualified purchasers | SEC Reg D Rule 506(c) | `investorType >= 3` enforced in `ComplianceRegistry.isWhitelisted()` | On-chain | `InvestorRegistered` event + accreditation letter (off-chain) | Compliance |
| C-02 | Bona-fide pre-existing relationship + verification | Rule 506(c) | Transfer-agent onboarding (Securitize Markets-equivalent) | Off-chain | KYC packet, Form ID, accreditation memo | Transfer Agent |
| C-03 | Block U.S. persons from Reg S sleeve (if applicable) | SEC Reg S | `blockedJurisdictions[US] = true` for Reg S token | On-chain | `JurisdictionBlocked` event | Compliance |
| C-04 | OFAC SDN screening | OFAC 31 CFR 501 | Daily SDN delta job → `updateInvestor(_, _, _, sanctioned=true)` | Hybrid | Job run log + `InvestorUpdated` event | Compliance |
| C-05 | Travel Rule (≥$3K transfers) | FinCEN | Off-chain TRP (Notabene / Sumsub) before transfer-agent approval | Off-chain | TRP transaction ID logged in `forceTransfer` reason field | Transfer Agent |
| C-06 | AML transaction monitoring | BSA | Off-chain Chainalysis KYT screening before whitelist | Off-chain | KYT case ID per investor | Compliance |
| C-07 | KYC refresh ≤ 12 months | FinCEN CDD Rule | `kycExpiry` checked at every `_update` | On-chain | `kycExpiry` field per investor + renewal log | Compliance |
| C-08 | Audit trail of every share movement | SEC 17 CFR 240.17a-4 | Indexed ERC-20 `Transfer` + custom `ForceTransfer` / `Subscribed` / `Redeemed` events | On-chain | Subgraph / on-chain logs | Engineering |
| C-09 | NAV calculation independence | 1940 Act §22 | NAV posted by oracle role keyed to custodian admin, not fund manager | Hybrid | `NavUpdated` events + admin attestation PDF | Fund Administrator |
| C-10 | Proof of reserve | Industry best practice | Daily Chainlink PoR attestation against custodian holdings | On-chain | PoR feed address + report | Custodian |
| C-11 | Investor recovery (lost wallet) | Trust law / IMA | `forceTransfer` with `reason` argument | On-chain | `ForceTransfer` event + court order / affidavit | Transfer Agent |
| C-12 | Pause for incident response | IMA / risk policy | `PAUSER_ROLE` → `pause()` | On-chain | `Paused` event + incident postmortem | Risk / Engineering |
| C-13 | Investor disclosure (PPM, fees) | SEC Reg D | Off-chain PPM + on-chain `mgmtFeeBps` matches | Off-chain | PPM PDF + on-chain getter | Legal |
| C-14 | Cap-table reconciliation vs. transfer agent of record | SEC 17 Ad-7 | Nightly reconciliation: on-chain `balanceOf` snapshot vs. TA system | Off-chain | Recon report (zero variance target) | Transfer Agent |
| C-15 | Smart-contract security | Industry best practice | Two independent audits (Trail of Bits + OpenZeppelin) pre-launch | Off-chain | Audit reports + remediation log | Engineering |

## Defence in depth

For each material risk, both an **on-chain** preventive control **and** an **off-chain** detective control exist:

- An unverified investor cannot acquire tokens (on-chain prevent) **and** the nightly recon flags any drift (off-chain detect).
- A sanctioned address cannot transfer (on-chain prevent) **and** the OFAC delta job re-screens daily (off-chain detect).
- A stale NAV halts subscriptions (on-chain prevent) **and** the monitoring alert pages oncall within 1 hour (off-chain detect).
