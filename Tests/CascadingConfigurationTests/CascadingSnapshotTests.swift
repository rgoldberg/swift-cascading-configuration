//
// CascadingSnapshotTests.swift
// swift-cascading-configuration
//
// Copyright © 2026 Ross Goldberg
// SPDX-License-Identifier: MIT
//

import CascadingConfiguration
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

		let specificResult = try snapshot.value(forKey: ["a", "b", "setting"], type: .string)
		#expect(try specificResult.value?.content.asString == "2nd specific")

		let generalResult = try snapshot.value(forKey: ["x", "setting"], type: .string)
		#expect(try generalResult.value?.content.asString == "1st general")
	}
}
