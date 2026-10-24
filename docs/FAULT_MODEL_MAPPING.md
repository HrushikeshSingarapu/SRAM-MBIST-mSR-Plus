# Fault-model mapping to the reference paper

Reference: Lin, Chiang, Wang, IEEE TVLSI vol. 33 no. 9, Sept 2025, Table I
(one-line definitions only) and Section on functionality verification
(11 fault models). All numbers below are **our own simulation results**
(8-cell, 8-bit SRAM model, exhaustive over victims / aggressor pairs /
values, three memory power-up states). They are not the paper's figures.

| # | Paper model | Paper Table I definition | Model used here (fault_type) | Our definition |
|---|---|---|---|---|
| 1 | SAF | cell stuck at 0 or 1 | SAF (0) | read/write of victim always gives fv |
| 2 | TF | cell fails 0->1 or 1->0 | TF (1) | write ~fv over fv to victim is lost |
| 3 | CFid ("inversion dominant") | inversion in one cell causes error in another | CFIN (4) | aggressor transition inverts victim |
| 4 | CFdrd | aggressor read disturbs victim read result | CFDRD_P (11) | read of aggressor holding a flips victim holding x |
| 5 | CFin ("idempotent") | aggressor acts, victim forced | CFID (2) | aggressor transition forces victim to fv |
| 6 | RDF | repeated reads disturb cell | RDF (5) | read flips cell and returns flipped value |
| 7 | DRDF | data correct, cell wrong after read | DRDF (6) | read returns correct value, cell flips |
| 8 | IRF | read inverts value | IRF (7) | read returns inverted value, cell intact |
| 9 | CFtr | aggressor transition causes faulty victim transition | CFTR (8) | aggressor in state a blocks victim fv -> ~fv |
| 10 | CFwd | aggressor write causes unintended victim write | CFWD_P (12) | writing a to aggressor also writes a into victim |
| 11 | WDF | word-line activation disturbs nearby word lines | WDF_P (13) | any access to the aggressor word line flips a victim holding x |

The paper's expansions of CFid/CFin differ from the standard literature
(the standard names are the other way round); both an inversion and an
idempotent coupling fault are modelled, so the label swap does not change
which behaviours are covered.

The standard-literature versions (CFDRD, CFWD, WDF; fault_type 3, 9, 10) are
kept and reported separately, because they are harder to excite:

| Model | mSR+ detected (RTL) |
|---|---|
| CFDRD (standard) | 112/224 (50%) |
| CFWD (standard) | 56/224 (25%) |
| WDF (standard) | 8/16 (50%) |

## Result under the paper's definitions (RTL, March mSR+)

mSR+ detects 100% of the injected instances for all 11 paper fault models,
in every power-up state. Detections by algorithm (behavioural engine,
mSR+ column identical to the RTL):

| Paper model | mSR+ | mSR | MATS++ | March C- |
|---|---|---|---|---|
| SAF | 16/16 | 16/16 | 16/16 | 16/16 |
| TF | 16/16 | 16/16 | 16/16 | 16/16 |
| CFid | 112/112 | 112/112 | 84/112 | 112/112 |
| CFdrd | 224/224 | 168/224 | 84/224 | 224/224 |
| CFin | 224/224 | 168/224 | 84/224 | 224/224 |
| RDF | 16/16 | 16/16 | 16/16 | 16/16 |
| DRDF | 16/16 | 16/16 | 0/16 | 0/16 |
| IRF | 16/16 | 16/16 | 16/16 | 16/16 |
| CFtr | 224/224 | 224/224 | 112/224 | 224/224 |
| CFwd | 112/112 | 84/112 | 56/112 | 112/112 |
| WDF | 112/112 | 112/112 | 84/112 | 112/112 |

## What matches the paper and what does not

* Matches: mSR+ reaches 100% on all 11 models; mSR+ detects DRDF where
  MATS++ and March C- do not; mSR is weaker than mSR+ on CFdrd (168/224
  versus 224/224) and CFwd.
* Does not match: the paper reports March C- and MATS++ detecting no CFdrd
  and only mSR/mSR+ detecting WDF; with our literal one-line models March C-
  also detects CFdrd_P and CFwd_P, and MATS++/March C- detect WDF_P. The
  paper's exact fault lists are not published, so its tables cannot be
  reproduced instance for instance.
* Not reproducible: the paper's 32/36 (mSR+) and 30/36 (mSR) totals depend
  on the authors' list of 36 fault instances, which the paper does not give.
  The paper's own numbers are also internally inconsistent (the 32 vs 30
  difference is 2, while the CFdrd difference alone is 4).
* The paper's 125.38 mW / 1.36 mW / 4.4 uJ figures are for its Intel MAX 10
  implementation and are not claimed for this Basys 3 design.

WDF_P is our own reading of a one-line definition ("word-line activation
disturbs nearby word lines"); it was added after the other models were
fixed and was not tuned to the result.
