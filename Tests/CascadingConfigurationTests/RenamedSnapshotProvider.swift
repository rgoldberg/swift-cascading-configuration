//
// RenamedSnapshotProvider.swift
// swift-cascading-configuration
//
// Copyright © 2026 Ross Goldberg
// SPDX-License-Identifier: MIT
//

import Configuration

/// An upstream provider that has no values & whose snapshot has another name.
@available(Configuration 1.0, *)
struct RenamedSnapshotProvider {}

@available(Configuration 1.0, *)
extension RenamedSnapshotProvider: ConfigProvider {
	var providerName: String {
		"RenamedSnapshotProvider"
	}

	func value(forKey key: AbsoluteConfigKey, type _: ConfigType) -> LookupResult {
		.init(encodedKey: key.description, value: nil)
	}

	func fetchValue(forKey key: AbsoluteConfigKey, type: ConfigType) -> LookupResult {
		value(forKey: key, type: type)
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
		InMemoryProvider(name: "snapshot", values: [:]).snapshot()
	}

	func watchSnapshot<Return: ~Copyable>(
		updatesHandler: (_ updates: ConfigUpdatesAsyncSequence<any ConfigSnapshot, Never>) async throws -> Return,
	) async throws -> Return {
		try await watchSnapshotFromSnapshot(updatesHandler: updatesHandler)
	}
}
