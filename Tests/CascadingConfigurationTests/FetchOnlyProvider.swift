//
// FetchOnlyProvider.swift
// swift-cascading-configuration
//
// Copyright © 2026 Ross Goldberg
// SPDX-License-Identifier: MIT
//

import Configuration

/// An upstream provider, which is its own snapshot, that has a value for 1 key
/// only when fetching it & has no value for any other.
@available(Configuration 1.0, *)
struct FetchOnlyProvider {
	/// The key whose fetches find the value `fetched`.
	var fetchableKey: AbsoluteConfigKey
}

@available(Configuration 1.0, *)
extension FetchOnlyProvider: ConfigSnapshot {
	var providerName: String {
		"FetchOnlyProvider"
	}

	func value(forKey key: AbsoluteConfigKey, type _: ConfigType) -> LookupResult {
		.init(encodedKey: key.description, value: nil)
	}
}

@available(Configuration 1.0, *)
extension FetchOnlyProvider: ConfigProvider {
	func fetchValue(forKey key: AbsoluteConfigKey, type _: ConfigType) -> LookupResult {
		.init(encodedKey: key.description, value: key == fetchableKey ? "fetched" : nil)
	}

	func watchValue<Return: ~Copyable>(
		forKey key: AbsoluteConfigKey,
		type: ConfigType,
		updatesHandler: (
			_ updates: ConfigUpdatesAsyncSequence<Result<LookupResult, any Error>, Never>,
		) async throws -> Return,
	) async throws -> Return {
		try await watchValueFromValue(forKey: key, type: type, updatesHandler: updatesHandler)
	}

	func snapshot() -> any ConfigSnapshot {
		self
	}

	func watchSnapshot<Return: ~Copyable>(
		updatesHandler: (_ updates: ConfigUpdatesAsyncSequence<any ConfigSnapshot, Never>) async throws -> Return,
	) async throws -> Return {
		try await watchSnapshotFromSnapshot(updatesHandler: updatesHandler)
	}
}
