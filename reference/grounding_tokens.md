# Canonical grounding tokens

The two states a fact – or a decision assembled from facts – can occupy
under the Independent Oracle Principle. `grounding_grounded()` returns
the token for a fact that has been checked against its external
authority; `grounding_unverified()` returns the token for everything
else, which is the default until a grounding check proves otherwise.

## Usage

``` r
grounding_grounded()

grounding_unverified()
```

## Value

A length-one character string holding the canonical token.

## Details

`grounding_unverified()` returns `"ungrounded"`. The token written by
decideR 0.2.0 and earlier is still accepted wherever a token is read.

## See also

[`combine_grounding()`](https://max578.github.io/decideR/reference/combine_grounding.md)
for worst-case combination across inputs.

Other grounding:
[`combine_grounding()`](https://max578.github.io/decideR/reference/combine_grounding.md)

## Examples

``` r
grounding_grounded()
#> [1] "grounded"
grounding_unverified()
#> [1] "ungrounded"
```
