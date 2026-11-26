//
// FailingProvider.swift
// swift-cascading-configuration
//
// Copyright © 2026 Ross Goldberg
// SPDX-License-Identifier: MIT
//

import Configuration

/// An upstream provider, which is its own snapshot, that throws for 1 key & has
/// no value for any other.
@available(Configuration 1.0, *)
struct FailingProvider {
	enum TestError: Error {
		case failure
	}

	/// The key whose lookups throw.
	var failingKey: AbsoluteConfigKey
}

@available(Configuration 1.0, *)
extension FailingProvider: ConfigSnapshot {
	var providerName: String {
		"FailingProvider"
	}

	func value(forKey key: AbsoluteConfigKey, type _: ConfigType) throws(TestError) -> LookupResult {
		guard key != failingKey else {
			throw .failure
		}
		return .init(encodedKey: key.description, value: nil)
	}
}

@available(Configuration 1.0, *)
extension FailingProvider: ConfigProvider {
	func fetchValue(forKey key: AbsoluteConfigKey, type: ConfigType) throws(TestError) -> LookupResult {
		try value(forKey: key, type: type)
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
