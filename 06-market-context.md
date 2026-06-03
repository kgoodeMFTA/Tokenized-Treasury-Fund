# Market Context — Tokenized U.S. Treasuries (as of May 2026)

Snapshot of the competitive landscape that informs this project's design choices.

## On-chain RWA market

- **Total on-chain RWA market cap:** $33.7B — all-time high, May 2026 ([rwa.xyz via FinanceFeeds](https://financefeeds.com/buidl-ousg-benji-tokenized-treasury-market-2026/)).
- **Tokenized U.S. Treasuries sub-category:** ~$6.8B AUM — the single largest on-chain RWA category alongside tokenized credit and stablecoins.
- **Growth curve:** From $0 in March 2024 (BUIDL launch) to $6.8B in 26 months — roughly tripling year over year.

## Product landscape

| Product | Issuer | AUM (May 2026) | KYC tier | Net yield | Chains | Redemption |
|---|---|---|---|---|---|---|
| BUIDL | BlackRock + Securitize | ~$2.58B | Reg D QP, $5M min | ~4.5% | Ethereum, Aptos, Arbitrum, Avalanche, Optimism, Polygon | Same-day USDC via Circle |
| USYC | Circle (formerly Hashnote) | ~$3.0B | Reg S + Cayman QI, $250K min | ~4.5% | Ethereum, Canton, Solana, Arbitrum | Same-day USDC via Circle |
| USDY | Ondo Finance | ~$2.1B | Reg S, non-US retail OK | ~4.4% | Ethereum, Solana, Mantle, Sui, Aptos, Cosmos, Noble, Arbitrum | Next-day USDC |
| USTB | Superstate | ~$836M | Reg D QP, $100K min | ~4.5% | Ethereum, Solana, Arbitrum | Next-day USDC via smart contract |
| BENJI | Franklin Templeton | ~$800M | 1940 Act fund, US retail OK | ~4.4% | Stellar, Polygon, Arbitrum, Aptos, Avalanche, Base, Ethereum, Solana | Same-day USD or USDC |
| OUSG | Ondo Finance | ~$625M | Reg D QP, $100K min | ~4.6% | Ethereum, Polygon, Solana, Mantle | Instant via BUIDL during market hours |

Source: [Eco — OUSG vs BUIDL vs USDY 2026 comparison](https://eco.com/support/en/articles/15254006-ousg-vs-buidl-vs-usdy-yield-2026-tokenized-t-bills-compared).

## Regulatory milestones

- **May 4, 2026** — FINRA cleared Securitize Markets LLC to operate as the first U.S. broker-dealer authorised to custody tokenised securities, settle them atomically against stablecoins, and underwrite tokenised IPOs and secondary offerings ([FinanceFeeds, May 2026](https://financefeeds.com/buidl-ousg-benji-tokenized-treasury-market-2026/)).
- The category remains structured as **ERC-20 wrapped in a permissioned framework operated by a regulated transfer agent** — eligibility is enforced primarily off-chain, with on-chain controls codifying the result ([LinkedIn analysis](https://www.linkedin.com/posts/damuwinston_tokenization-rwa-digitalassets-activity-7458121298863538176-dtuz)).

## Design implications for this project

1. **Permissioned ERC-20 is the dominant pattern** — BUIDL, OUSG, USTB all use it. ERC-3643 / T-REX from Tokeny is gaining ground for fully on-chain identity, but plain ERC-20 + transfer-agent gating remains the production default. This project models the dominant pattern but isolates compliance behind an interface so an ERC-3643 swap is a non-breaking change.
2. **Off-chain transfer agent is non-negotiable** — Securitize for BUIDL/OUSG, Franklin Templeton's in-house TA for BENJI. This project codifies that as the `TRANSFER_AGENT_ROLE`.
3. **Yield-as-new-shares (BUIDL model) is preferred over rebasing** for fund accounting transparency. This project follows that pattern.
4. **NAV freshness is a hard control** — stale NAV must halt subscriptions, not silently use old data. The 36-hour ceiling here is conservative; production funds use 24h.
5. **Multi-chain is canonical-on-Ethereum + mirrors elsewhere** ([MEXC analysis, May 2026](https://www.mexc.com/news/1119230)). This project keeps the canonical ledger on Ethereum and documents the multi-chain mirror as v2.
