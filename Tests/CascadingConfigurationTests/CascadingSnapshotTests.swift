//
// CascadingSnapshotTests.swift
// swift-cascading-configuration
//
// Copyright © 2026 Ross Goldberg
// SPDX-License-Identifier: MIT
//

import CascadingConfiguration
import Synchronization
import Testing

struct CascadingSnapshotTests {
	@available(Configuration 1.0, *)
	@Test
	func `snapshot cascades`() throws {
		let provider = CascadingProvider(
			providers: [
				.init(InMemoryProvider(name: "1st", values: ["setting": "1st general"])),
				.init(InMemoryProvider(name: "2nd", values: ["a.setting": "2nd specific"])),
			],
		)
		let snapshot = provider.snapshot()
		#expect(snapshot.providerName == provider.providerName)

		#expect(try snapshot.value(forKey: ["a", "b", "setting"], type: .string).value?.content.asString == "2nd specific")

		#expect(try snapshot.value(forKey: ["x", "setting"], type: .string).value?.content.asString == "1st general")
	}

	@available(Configuration 1.0, *)
	@Test
	func `snapshot provider name matches provider name even if an upstream snapshot has another name`() {
		let provider = CascadingProvider(providers: [.init(RenamedSnapshotProvider())])
		#expect(provider.snapshot().providerName == provider.providerName)
	}

	@available(Configuration 1.0, *)
	@Test
	func `snapshot tries the keys of a synchronous lookup`() throws {
		let recorder = KeyRecordingProvider()
		let result = try CascadingProvider(providers: [.init(recorder, baseScope: ["tool"]), .init(recorder)])
			.snapshot()
			.value(forKey: ["install", "limit"], type: .string)
		#expect(result.value == nil)
		#expect(result.encodedKey == "tool.install.limit")
		#expect(recorder.keys.withLock(\.self) == ["tool.install.limit", "install.limit", "tool.limit", "limit"])
	}

	@available(Configuration 1.0, *)
	@Test
	func `snapshot error halts cascading`() {
		let recorder = KeyRecordingProvider()
		#expect(throws: FailingProvider.TestError.self) {
			try CascadingProvider(providers: [.init(FailingProvider(failingKey: ["a", "setting"])), .init(recorder)])
				.snapshot()
				.value(forKey: ["a", "setting"], type: .string)
		}
		#expect(recorder.keys.withLock(\.self).isEmpty)
	}
}
