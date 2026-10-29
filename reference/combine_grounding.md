# Combine input grounding worst-case

A decision that rests on several inputs is grounded only when *every*
input is grounded; a single un-grounded input taints the whole decision.
This is the worst-case combination mandated by the Independent Oracle
Principle, and it is the rule by which a decision inherits its grounding
label from the facts it consumes.

## Usage

``` r
combine_grounding(tokens)
```

## Arguments

- tokens:

  A character vector of grounding tokens, each either
  [`grounding_grounded()`](https://max578.github.io/decideR/reference/grounding_tokens.md)
  or
  [`grounding_unverified()`](https://max578.github.io/decideR/reference/grounding_tokens.md).

## Value

[`grounding_grounded()`](https://max578.github.io/decideR/reference/grounding_tokens.md)
if `tokens` is non-empty and every element is grounded; otherwise
[`grounding_unverified()`](https://max578.github.io/decideR/reference/grounding_tokens.md).

## Details

Each token is validated against the canonical vocabulary, so a synonym
such as `"unverified"` is rejected loudly rather than silently mistaken
for a grounded fact. The token written by decideR 0.2.0 and earlier is
accepted as un-grounded.

## See also

[grounding_tokens](https://max578.github.io/decideR/reference/grounding_tokens.md)
for the two canonical tokens.

Other grounding:
[`grounding_tokens`](https://max578.github.io/decideR/reference/grounding_tokens.md)

## Examples

``` r
combine_grounding(c(grounding_grounded(), grounding_grounded()))
#> [1] "grounded"
combine_grounding(c(grounding_grounded(), grounding_unverified()))
#> [1] "ungrounded"
```
