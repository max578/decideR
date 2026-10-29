# Print a decision

Print a decision

## Arguments

- x:

  A [decision](https://max578.github.io/decideR/reference/decision.md).

- ...:

  Ignored, for compatibility with
  [`print()`](https://rdrr.io/r/base/print.html).

## Value

`x`, invisibly.

## Examples

``` r
print(decision(action_label = "flat", grounding = grounding_grounded()))
#> <decision> decided  [grounded]
#>   action : flat
```
