# Print a grade-band value schedule

Print a grade-band value schedule

## Usage

``` r
# S3 method for class 'grade_band_value'
print(x, ...)
```

## Arguments

- x:

  A
  [grade_band_value](https://max578.github.io/decideR/reference/grade_band_value.md)
  schedule.

- ...:

  Ignored, for compatibility with
  [`print()`](https://rdrr.io/r/base/print.html).

## Value

`x`, invisibly.

## Examples

``` r
print(grade_band_value(c(10.5, 11.5), c(300, 330, 360)))
#> <grade_band_value> 3 bands
#>          band value
#>  [-Inf, 10.5)   300
#>  [10.5, 11.5)   330
#>   [11.5, Inf)   360
```
