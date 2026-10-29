# CRRDC-guideline benefit-cost ratio

Discounts a benefit stream and a cost stream to a benefit-cost ratio in
the shape a Council of Rural Research and Development Corporations
(CRRDC) impact assessment reports, with the four inputs the guidelines
make mandatory: an explicit counterfactual, an explicit attribution
share, an adoption profile with lags, and a discount-rate sensitivity
band around the central rate. Where
[`decide_bcr()`](https://max578.github.io/decideR/reference/decide_bcr.md)
leaves those assumptions to the caller, `bcr_crrdc()` refuses to
construct a ratio without all four – a benefit-cost ratio that
implicitly assumes no counterfactual, full attribution and instant 100%
uptake is exactly what the guidelines forbid.

## Usage

``` r
bcr_crrdc(
  benefits,
  costs,
  counterfactual,
  attribution,
  adoption,
  counterfactual_label = NULL,
  discount_central = 0.05,
  discount_sensitivity = c(0.03, 0.07),
  base_year = NULL,
  grounding = NULL
)
```

## Arguments

- benefits:

  A `data.frame(year, value)`: the (gross, pre-counterfactual) annual
  real benefit stream.

- costs:

  A `data.frame(year, value)`: the annual real cost stream. Not adjusted
  by `counterfactual`, `attribution` or `adoption`.

- counterfactual:

  Required, no default. Either a `data.frame(year, value)` of benefits
  under the counterfactual, spanning every year `benefits` covers,
  subtracted from `benefits`; or the string `"already_net"` declaring
  `benefits` is already incremental, in which case
  `counterfactual_label` is also required.

- attribution:

  Required, no default. A single number in `(0, 1]`: the share of the
  incremental benefit attributable to this investment.

- adoption:

  Required, no default. A `data.frame(year, uptake)` with `uptake` in
  `[0, 1]`, spanning every year `benefits` covers, applied
  multiplicatively to the net, attributed benefit stream.

- counterfactual_label:

  A single character string naming the declared counterfactual. Required
  when `counterfactual = "already_net"`; optional (used only for
  reporting) when `counterfactual` is a `data.frame`.

- discount_central:

  The central real discount rate, as a proportion (CRRDC's Australian
  rural R&D standard is `0.05`).

- discount_sensitivity:

  A numeric vector of sensitivity discount rates reported alongside
  `discount_central` (CRRDC's standard band is `c(0.03, 0.07)`).

- base_year:

  The undiscounted period-zero year; defaults to the earliest year
  across `benefits` and `costs`.

- grounding:

  Optional grounding token(s) for the input facts, combined worst-case
  with
  [`combine_grounding()`](https://max578.github.io/decideR/reference/combine_grounding.md);
  defaults to
  [`grounding_unverified()`](https://max578.github.io/decideR/reference/grounding_tokens.md)
  when not supplied.

## Value

A `decider_bcr` object: `rates` (a `data.frame` with one row per
discount rate and columns `rate_label`, `rate`, `pv_benefits`,
`pv_costs`, `npv`, `bcr`), `counterfactual_label`, `attribution`,
`adoption`, `base_year`, `grounding`, `abstained` and `abstain_reason`.

## Details

`counterfactual` states what would have happened without the investment.
Supply a `data.frame(year, value)` of benefits under the counterfactual
scenario, spanning every year `benefits` covers, and it is subtracted
from `benefits` year by year before attribution and adoption are
applied. Alternatively, when `benefits` already IS the incremental
(net-of- counterfactual) stream, pass `counterfactual = "already_net"`
and name the declared counterfactual in `counterfactual_label` – the
label is required in this branch because a net stream carries no other
record of what it is net of.

`attribution` is the proportion, in `(0, 1]`, of the incremental benefit
this investment alone caused, net of co-funders, extension effort and
other contributing causes. `adoption` is the uptake profile, a
`data.frame(year, uptake)` with `uptake` in `[0, 1]`, applied
multiplicatively to the net, attributed benefit stream; it must cover
every year `benefits` covers, so an adoption lag is always stated rather
than assumed away. Costs are not adjusted by attribution or adoption –
the investment cost is what was actually spent, not a share of a
benefit.

The ratio is reported at `discount_central` (the CRRDC standard is 5%
for Australian rural R&D) and, side by side, at every rate in
`discount_sensitivity` (the CRRDC standard band is 3% and 7%), so a
reader sees how sensitive the ratio is to the one assumption a guideline
mandates testing. `base_year` (period `t = 0`, undiscounted) defaults to
the earliest year across `benefits` and `costs`, so an investment whose
costs precede its first benefit year is discounted from the year
spending began.

Grounding rides the same Independent Oracle Principle firewall as the
rest of decideR: an un-grounded input (the default when `grounding` is
not supplied) returns an abstained `decider_bcr` with
`abstain_reason = "input_ungrounded"` and every rate's
`pv_benefits`/`pv_costs`/`npv`/`bcr` `NA`, never a ratio a funding
submission would quote. A discounted cost base that is not strictly
positive at the central rate (a zero or negative cost stream) abstains
with `abstain_reason = "undefined_ratio"` for the same reason.

## See also

[`decide_bcr()`](https://max578.github.io/decideR/reference/decide_bcr.md)
for a benefit-cost ratio without the CRRDC mandatory inputs.

Other value:
[`decide_bcr()`](https://max578.github.io/decideR/reference/decide_bcr.md),
[`decide_evpi()`](https://max578.github.io/decideR/reference/decide_evpi.md),
[`decide_evsi()`](https://max578.github.io/decideR/reference/decide_evsi.md),
[`valuation()`](https://max578.github.io/decideR/reference/valuation.md)

## Examples

``` r
# A ten-year, evenly-adopted, half-attributed investment. The benefit
# stream is already declared incremental against a named counterfactual.
bens <- data.frame(year = 2020:2029, value = rep(500, 10))
csts <- data.frame(year = 2020:2029, value = rep(1000, 10))
up   <- data.frame(year = 2020:2029, uptake = rep(1, 10))
bcr_crrdc(bens, csts, counterfactual = "already_net",
          counterfactual_label = "no new variety released",
          attribution = 0.5, adoption = up,
          grounding = grounding_grounded())
#> <decider_bcr> priced  [grounded]
#>   counterfactual: no new variety released
#>   attribution   : 0.5
#>   base year     : 2020
#>   BCR @ central (5%): 0.25
#>   BCR @ sensitivity_1 (3%): 0.25
#>   BCR @ sensitivity_2 (7%): 0.25
```
