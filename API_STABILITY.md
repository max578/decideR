# API stability

`decideR` follows semantic versioning. During the `0.x` series the package is
**experimental**: the public API may change between minor versions as the
decision contract is exercised by ORCHESTRA members. Breaking changes are
recorded at the top of `NEWS.md`.

## Stability ladder

- **Experimental (current, `0.x`).** Function signatures and the `decision`
  object's property set may change. Pin a specific version for a reproducible
  pipeline.
- **Stable (from `1.0.0`).** The exported functions and the `decision` contract
  become subject to the deprecation policy below.

## Deprecation policy (from `1.0.0`)

A removed or renamed export passes through at least one minor version emitting a
deprecation warning that names its successor before it is made defunct, so a
downstream consumer always has a migration path it can act on.
