//
// IgnoringCascadeContextTests.swift
// swift-cascading-configuration
//
// Copyright © 2026 Ross Goldberg
// SPDX-License-Identifier: MIT
//

import CascadingConfiguration
import Testing

struct IgnoringCascadeContextTests {
	@available(Configuration 1.0, *)
	@Test
	func `ignoring cascade context`() throws {
		let upstream = InMemoryProvider(
			values: [
				.init(["foo"]): "bar",
				.init(["baz"], context: ["environment": "production"]): "qux",
			],
		)
		let floorContext = [String: ConfigContextValue]
			.baseScope(["tool"])
			.cascadeScopeFloor(1)
			.baseScopeCascadeScopeFloor(0)

		// The in-memory provider only matches a key with the same context, so the
		// cascade context hides its value
		let flooredKey = AbsoluteConfigKey(["foo"], context: floorContext)
		#expect(try upstream.value(forKey: flooredKey, type: .string).value == nil)

		let ignoring = upstream.ignoringCascadeContext()
		#expect(try ignoring.value(forKey: flooredKey, type: .string).value?.content.asString == "bar")
		#expect(try ignoring.value(forKey: ["foo"], type: .string).value?.content.asString == "bar")

		// The rest of the context is kept
		let flooredContextKey = AbsoluteConfigKey(
			["baz"],
			context: floorContext.merging(["environment": "production"]) { $1 },
		)
		#expect(try ignoring.value(forKey: flooredContextKey, type: .string).value?.content.asString == "qux")
	}
}
