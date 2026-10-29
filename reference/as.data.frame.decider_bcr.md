# Coerce a CRRDC benefit-cost ratio to a data.frame

Coerce a CRRDC benefit-cost ratio to a data.frame

## Usage

``` r
# S3 method for class 'decider_bcr'
as.data.frame(x, ...)
```

## Arguments

- x:

  A
  [`bcr_crrdc()`](https://max578.github.io/decideR/reference/bcr_crrdc.md)
  result.

- ...:

  Ignored, for compatibility with
  [`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html).

## Value

The `rates` `data.frame`: one row per discount rate, columns
`rate_label`, `rate`, `pv_benefits`, `pv_costs`, `npv`, `bcr`.

## Examples

``` r
bens <- data.frame(year = 2020:2021, value = c(0, 210))
csts <- data.frame(year = 2020:2021, value = c(100, 0))
up   <- data.frame(year = 2020:2021, uptake = c(1, 1))
as.data.frame(bcr_crrdc(bens, csts, counterfactual = "already_net",
                        counterfactual_label = "no intervention",
                        attribution = 1, adoption = up,
                        grounding = grounding_grounded()))
#>      rate_label rate pv_benefits pv_costs       npv      bcr
#> 1       central 0.05    200.0000      100 100.00000 2.000000
#> 2 sensitivity_1 0.03    203.8835      100 103.88350 2.038835
#> 3 sensitivity_2 0.07    196.2617      100  96.26168 1.962617
```
