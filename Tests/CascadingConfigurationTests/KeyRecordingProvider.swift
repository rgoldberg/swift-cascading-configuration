//
// KeyRecordingProvider.swift
// swift-cascading-configuration
//
// Copyright © 2026 Ross Goldberg
// SPDX-License-Identifier: MIT
//

import Configuration
import Synchronization

/// An upstream provider, which is its own snapshot, that records every key that
/// it is asked for & has no values.
@available(Configuration 1.0, *)
final class KeyRecordingProvider {
	/// The keys looked up so far, in lookup order.
	private let recordedKeys = Mutex<[AbsoluteConfigKey]>([])

	/// The keys looked up so far, in dot notation, in lookup order.
	var keys: [String] {
		recordedKeys.withLock { recordedKeys in recordedKeys.map { $0.components.joined(separator: ".") } }
	}

	/// The contexts of the keys looked up so far, in lookup order.
	var contexts: [[String: ConfigContextValue]] {
		recordedKeys.withLock { $0.map(\.context) }
	}
}

@available(Configuration 1.0, *)
extension KeyRecordingProvider: ConfigSnapshot {
	var providerName: String {
		"KeyRecordingProvider"
	}

	func value(forKey key: AbsoluteConfigKey, type _: ConfigType) -> LookupResult {
		recordedKeys.withLock { $0.append(key) }
		return .init(encodedKey: key.components.joined(separator: "."), value: nil)
	}
}

@available(Configuration 1.0, *)
extension KeyRecordingProvider: ConfigProvider {
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
		self
	}

	func watchSnapshot<Return: ~Copyable>(
		updatesHandler: (_ updates: ConfigUpdatesAsyncSequence<any ConfigSnapshot, Never>) async throws -> Return,
	) async throws -> Return {
		try await watchSnapshotFromSnapshot(updatesHandler: updatesHandler)
	}
}
