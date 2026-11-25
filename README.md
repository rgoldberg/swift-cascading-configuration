<!--editorconfig-checker-disable-->
<!--markdownlint-disable-next-line first-line-h1-->
[![current version](https://img.shields.io/github/v/release/ro-ss/swift-cascading-configuration.svg?style=for-the-badge)](https://github.com/ro-ss/swift-cascading-configuration/releases/latest)
[![CI status](https://img.shields.io/github/actions/workflow/status/ro-ss/swift-cascading-configuration/ci.yaml?label=ci&style=for-the-badge)](https://github.com/ro-ss/swift-cascading-configuration/actions/workflows/ci.yaml?query=branch%3Amain)
[![Swift 6.2+](https://img.shields.io/badge/Swift-6.2+-F05138.svg?style=for-the-badge)](https://www.swift.org)
[![Swift Configuration 1.0.2+](https://img.shields.io/badge/Swift_Configuration-1.0.2+-royalblue.svg?style=for-the-badge)](https://github.com/apple/swift-configuration)
[![MIT license](https://img.shields.io/badge/license-MIT-750014.svg?style=for-the-badge)](LICENSE)
<!--editorconfig-checker-enable-->

# Swift Cascading Configuration

Cascading scoped value lookup for [Swift
Configuration](https://github.com/apple/swift-configuration).

`CascadingProvider` is a Swift Configuration provider that falls back to less
specific keys when its upstream providers have no value for the requested key
(e.g., `a.b.setting`, then `a.setting`, then `setting`), so that a setting can
be set once for every scope, then overridden for a specific scope.

## Usage

```swift
import CascadingConfiguration

let config = ConfigReader(
    provider: CascadingProvider(
        providers: [
            .init(EnvironmentVariablesProvider(), baseScope: ["tool"]),
            .init(try await FileProvider<JSONSnapshot>(filePath: "tool.json")),
        ],
    ),
)

// Tries, in order:
// 1. TOOL_INSTALL_LIMIT from the environment
// 2. "install.limit" from the file
// 3. TOOL_LIMIT from the environment
// 4. "limit" from the file
config.int(forKey: "install.limit")
```

`FileProvider<JSONSnapshot>` needs the `JSON` trait of Swift Configuration (see
[Traits](#traits)).

`CascadingConfiguration` re-exports Swift Configuration, so
`import CascadingConfiguration` also imports `Configuration`.

### Value Resolution Order

A cascading lookup treats every component of a key except the last as a scope.
Key specificity takes precedence over provider order: each step of a cascade
removes 1 more scope from the key of every upstream provider, then queries every
upstream provider, in the order in which they were provided, before the next
step.

### Base Scopes

An upstream provider can have a base scope (e.g., `["tool"]`): scopes that are
prepended to every key that it is asked for, like a namespace. Unlike a key
prefix (see `ConfigProvider.prefixKeys(with:)`), a base scope can be removed by
a cascade, but only once no other scopes remain, and only down to a separate
floor: the base scope cascade scope floor, the minimum number of base scopes
that a key tried by the cascade keeps. That floor applies only if the cascade
scope floor (see [Limiting the Cascade](#limiting-the-cascade)) is `0`; its
default, `.noCascading`, keeps the whole base scope, while `0` lets the cascade
remove it (e.g., `0` reaches `PAGER` for `pager`, with base scope `["tool"]`).

A key overrides the base scope of every upstream provider via
`CascadingProvider.baseScopeContext(_:)`: an empty base scope removes every base
scope, while any other base scope replaces each base scope that is not empty:

```swift
// Looks up only PAGER, even in an environment provider whose base scope is ["tool"]
config.string(forKey: ConfigKey("pager", context: CascadingProvider.baseScopeContext([])))
```

### Limiting the Cascade

A cascade scope floor is the minimum number of scopes, not counting base scopes,
that a key tried by the cascade keeps: `0` (the default) cascades until no
scopes remain, while `.noCascading` turns cascading off. Each upstream provider
has its own floor, which a key overrides via its context:

```swift
// Tries "a.b.setting", then "a.setting"
config.string(forKey: ConfigKey("a.b.setting", context: [CascadingProvider.cascadeScopeFloorContextKey: 1]))
```

### Combining with Other Providers

`CascadingProvider` is an ordinary provider, so a `ConfigReader` can combine it
with others. A provider that follows it is only consulted after the whole
cascade finds no value.

`CascadingProvider` removes the cascade context (the floors & the base scope)
from the context of each key before it queries its upstream providers; wrap each
other provider in the same `ConfigReader` with `ignoringCascadeContext()`, so
that the cascade context cannot affect its lookups:

```swift
let config = ConfigReader(providers: [
    CommandLineArgumentsProvider().ignoringCascadeContext(), // Exact keys only
    CascadingProvider(providers: [.init(env), .init(userFile)]), // Cascades across both
    CascadingProvider(providers: [.init(defaultsFile)]), // Cascades after the above find nothing
])
```

`CommandLineArgumentsProvider` needs the `CommandLineArguments` trait of Swift
Configuration (see [Traits](#traits)).

### Watching & Errors

Fetching values, watching values & watching snapshots follow the same cascade as
a synchronous lookup. When an upstream provider throws an error,
`CascadingProvider` propagates it immediately instead of trying the next
provider or key.

## Installation

Add the package to the dependencies of your `Package.swift`:

```swift
.package(url: "https://github.com/ro-ss/swift-cascading-configuration", .upToNextMinor(from: "0.1.0")),
```

Until version 1.0.0, each minor version (e.g., 0.2.0) may break the API, so
`.upToNextMinor(from: "0.1.0")` accepts only 0.1 versions (e.g., 0.1.1).

Then add the `CascadingConfiguration` product to the dependencies of each target
that uses it:

```swift
.product(name: "CascadingConfiguration", package: "swift-cascading-configuration"),
```

### Traits

`CascadingConfiguration` enables no trait of Swift Configuration, so that a
package that depends on it enables only the traits that it uses. A package
enables each trait that it uses (e.g., `JSON` for `JSONSnapshot`, or
`CommandLineArguments` for `CommandLineArgumentsProvider`) by depending on Swift
Configuration directly:

```swift
.package(
    url: "https://github.com/apple/swift-configuration",
    from: "1.0.2",
    traits: ["CommandLineArguments", "JSON"],
),
```

## Requirements

| Requirement | Minimum                                                     |
| ----------- | ----------------------------------------------------------- |
| Build       | Swift 6.2 or Xcode 26                                       |
| Run         | macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, or Linux |

`CascadingConfiguration` declares no `platforms`, so a package that supports
older platforms can depend on it; each of its declarations is available wherever
Swift Configuration is.

## Contributing

Pull requests are welcome; see the [contribution guidelines](CONTRIBUTING.md) &
the [code of conduct](CODE_OF_CONDUCT.md). Report vulnerabilities as described
in the [security policy](SECURITY.md).

## License

`CascadingConfiguration` is available under the [MIT License](LICENSE), except
for the files copied from other projects, which the [notices](NOTICE.md) list
with their licenses.
