# ``CascadingConfiguration``

Cascading scoped value lookup for Swift Configuration.

## Overview

``CascadingProvider`` is a Swift Configuration provider that falls back to less
specific keys when its upstream providers have no value for the requested key
(e.g., `a.b.setting`, then `a.setting`, then `setting`).

`CascadingConfiguration` re-exports Swift Configuration, so
`import CascadingConfiguration` also imports `Configuration`.

## Topics

### Providers

- ``CascadingProvider``
- ``ConfigProvider/ignoringCascadeContext()``
