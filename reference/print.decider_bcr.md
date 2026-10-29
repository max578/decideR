# Print a CRRDC benefit-cost ratio

Print a CRRDC benefit-cost ratio

## Usage

``` r
# S3 method for class 'decider_bcr'
print(x, ...)
```

## Arguments

- x:

  A
  [`bcr_crrdc()`](https://max578.github.io/decideR/reference/bcr_crrdc.md)
  result.

- ...:

  Ignored, for compatibility with
  [`print()`](https://rdrr.io/r/base/print.html).

## Value

`x`, invisibly.

## Examples

``` r
bens <- data.frame(year = 2020:2021, value = c(0, 210))
csts <- data.frame(year = 2020:2021, value = c(100, 0))
up   <- data.frame(year = 2020:2021, uptake = c(1, 1))
print(bcr_crrdc(bens, csts, counterfactual = "already_net",
                counterfactual_label = "no intervention", attribution = 1,
                adoption = up, grounding = grounding_grounded()))
#> <decider_bcr> priced  [grounded]
#>   counterfactual: no intervention
#>   attribution   : 1
#>   base year     : 2020
#>   BCR @ central (5%): 2
#>   BCR @ sensitivity_1 (3%): 2.0388
#>   BCR @ sensitivity_2 (7%): 1.9626
```
