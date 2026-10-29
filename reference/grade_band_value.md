# A grade-band value schedule (threshold-economics loss)

Builds a step value schedule: a payoff that is constant within a quality
band and jumps at each breakpoint. This is the canonical shape of a
quality-graded payoff – a grain price that steps up as protein clears
10.5%, 11.5%, and 13%, say – where the value of an outcome depends on
which band it falls in, not on its exact magnitude. The returned object
is a vectorised function from a quality outcome to its band payoff,
classed so it carries the schedule for inspection and prints as a
readable band table.

## Usage

``` r
grade_band_value(breaks, values, right = FALSE, labels = NULL)
```

## Arguments

- breaks:

  A strictly increasing numeric vector of band edges (e.g. the protein
  thresholds `c(10.5, 11.5, 13)`).

- values:

  A numeric vector of band payoffs, of length `length(breaks) + 1`,
  ordered from the lowest band to the highest.

- right:

  Logical; when `FALSE` (default) bands are `[lower, upper)` so an
  outcome on a break clears into the higher band; when `TRUE` bands are
  `(lower, upper]`.

  \[lower,
  upper)`so an outcome on a break clears into the higher band; when`TRUE`bands are`(lower,
  upper\]:
  R:lower,%20upper)%60%20so%20an%0Aoutcome%20on%20a%20break%20clears%20into%20the%20higher%20band;%20when%20%60TRUE%60%20bands%20are%0A%60(lower,%20upper

- labels:

  Optional character labels for the bands, of length `length(values)`;
  defaults to formatted interval strings.

## Value

A function of one numeric argument returning the band payoff for each
element, with class `grade_band_value` and the schedule stored as
attributes (`breaks`, `values`, `labels`, `right`).

## Details

`breaks` are the band edges, strictly increasing. `values` are the
payoffs, one per band: the first applies below `breaks[1]`, the last
applies at or above `breaks[length(breaks)]`, and each interior element
applies between a consecutive pair of breaks. With `right = FALSE` (the
default) each band is the half-open interval `[lower, upper)`, so an
outcome exactly on a break clears into the higher band – the convention
a delivery standard uses when it pays the better grade at the threshold.

## See also

[`grade_band_utility()`](https://max578.github.io/decideR/reference/grade_band_utility.md)
to turn the schedule into a
[`decide()`](https://max578.github.io/decideR/reference/decide.md)
utility;
[`decide()`](https://max578.github.io/decideR/reference/decide.md) for
the engine that consumes it.

Other loss:
[`grade_band_utility()`](https://max578.github.io/decideR/reference/grade_band_utility.md)

## Examples

``` r
# An APW-style protein payoff: $/t steps up as protein clears each band.
v <- grade_band_value(breaks = c(10.5, 11.5, 13),
                      values = c(300, 330, 360, 400))
v(c(9.0, 11.0, 11.5, 14.0))
#> [1] 300 330 360 400
v
#> <grade_band_value> 4 bands
#>          band value
#>  [-Inf, 10.5)   300
#>  [10.5, 11.5)   330
#>    [11.5, 13)   360
#>     [13, Inf)   400
```
