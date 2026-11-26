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

### Swift Configuration

The symbols that `CascadingConfiguration` re-exports from Swift Configuration
without a trait; it re-exports each symbol that a trait enables (e.g.,
`JSONSnapshot`), too.

- ``AbsoluteConfigKey``
- ``AccessEvent``
- ``AccessReporter``
- ``BroadcastingAccessReporter``
- ``ConfigBytesFromBase64StringDecoder``
- ``ConfigBytesFromHexStringDecoder``
- ``ConfigBytesFromStringDecoder``
- ``ConfigContent``
- ``ConfigContextValue``
- ``ConfigKey``
- ``ConfigProvider``
- ``ConfigReader``
- ``ConfigSnapshot``
- ``ConfigSnapshotReader``
- ``ConfigType``
- ``ConfigUpdatesAsyncSequence``
- ``ConfigValue``
- ``DirectoryFilesProvider``
- ``EnvironmentVariablesProvider``
- ``ExpressibleByConfigInt``
- ``ExpressibleByConfigString``
- ``FileAccessLogger``
- ``FileConfigSnapshot``
- ``FileParsingOptions``
- ``FileProvider``
- ``InMemoryProvider``
- ``KeyMappingProvider``
- ``LookupResult``
- ``MutableInMemoryProvider``
- ``SecretsSpecifier``
