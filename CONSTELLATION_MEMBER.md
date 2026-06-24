# Orchestra membership — decideR

> **This project (decideR) is a MEMBER of the Orchestra** (one coordination
> structure; reconciled 2026-06-03). The leader-node is **ORCHESTRA_dev**
> (governance, roster, contracts, TACI, publication); the technical inference hub
> is **flexyBayes** (the dependency-DAG sink). This file is decideR's back-pointer
> to that charter and a map of my siblings.

- **My role:** the **decision layer** — the loss-optimal, risk-aware closer of the
  inference→decision loop. `decide()` maximises posterior expected utility over a
  candidate set subject to hard constraints, and **abstains** under four
  prioritised triggers (ungrounded input / no feasible action / ESS floor /
  too-close-to-call). Shared crop + trading-arm keystone.
- **Contracts I own / honour:** I **consume `orchestra_manifest`** via a
  duck-typed tail (`decide_from_manifest()` / `decide_rate_from_manifest()` — no
  contract-package dependency); I **produce `decision`** objects (not a manifest).
  I honour the canonical grounding vocabulary (`grounded` / `[unverified]`,
  worst-case `combine_grounding`).
- **My edge:** consumer — any member's manifest (PESTO/flexyBayes/proxymix/gpfield/
  **optimix**) → decideR → a grounded action; feeds grainPlan (the grain last-mile)
  and the trading arm (position sizing). Acyclic: downstream of inference.
- **What binds me (charter invariants):** *single-responsibility* (decisions, not
  inference); the **IOP capital firewall** — an `[unverified]` input forces the
  safe/status-quo action, never a fabricated decide; *leader-directed adoption*.
- **Governance:** decideR is a **Max-owned personal package** (`max578`, PRIVATE,
  MIT-track); the AAGI-AUS canon does not apply.

## My siblings (the full roster — so I am informed about the others)

| Member | Role | Class |
|---|---|---|
| flexyBayes | inference hub (owns C1/C4/C5/C7) | open (AAGI-gated) |
| PESTO | calibration + manifest source (C2) | open |
| kernR | validation + TACI/ACI engine | open |
| proxymix | KL-optimal proxy compression; the `proxymix_map` optimisation engine | open |
| gretaR | engine — torch MCMC | open |
| koine | synthesis — fourth opinion | open |
| terroir | data collector (C6) | open (MIT) |
| kalmix | state-space / change-point / ACI | open (MIT) |
| masque | data sovereignty (clones) | open |
| apsimR | external engine — APSIM Next Gen | open (MIT-src) |
| bourse | grounded market-data connector (trading arm) | open |
| survkit | time-to-event toolkit | open |
| janusplot | asymmetric GAM association matrices (diagnostic-viz) | open |
| gpfield | change-of-support spatial GP; emits `orchestra_manifest` | open (MIT) |
| decideR | **decision layer (this package; loss-optimal closer; consumes the manifest)** | open |
| grainPlan | grain decision-orchestration (on decideR) | open (MIT) |
| optimix | optimisation meta-layer; emits `orchestra_manifest` | open (MIT) |
| flexyBayesOrchestra | composition layer (surrogates, koine backend) | open |

Planned: genoR. **Canonical charter:** `ORCHESTRA_dev/ORCHESTRA.md` (mirrored in
the MaxAIbase brain, open tier). **Contract + dependency DAG:**
`ORCHESTRA_dev/integration/orchestra_manifest.R`.
