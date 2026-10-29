# Print a valuation

Print a valuation

## Arguments

- x:

  A
  [valuation](https://max578.github.io/decideR/reference/valuation.md).

- ...:

  Ignored, for compatibility with
  [`print()`](https://rdrr.io/r/base/print.html).

## Value

`x`, invisibly.

## Examples

``` r
print(valuation(value = 12.4, type = "evpi",
                grounding = grounding_grounded()))
#> <valuation: evpi> priced  [grounded]
#>   value : 12.4
```
