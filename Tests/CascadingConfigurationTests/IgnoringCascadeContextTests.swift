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
	func `ignoring cascade context removes only the cascade context`() throws {
		let upstream = InMemoryProvider(
			values: [
				.init(["foo"]): "bar",
				.init(["baz"], context: ["environment": "production"]): "qux",
			],
		)
		let cascadeContext = [String: ConfigContextValue]
			.baseScope(["tool"])
			.cascadeScopeFloor(1)
			.baseScopeCascadeScopeFloor(0)

		// The in-memory provider only matches a key with the same context, so the
		// cascade context hides its value
		let cascadeContextKey = AbsoluteConfigKey(["foo"], context: cascadeContext)
		#expect(try upstream.value(forKey: cascadeContextKey, type: .string).value == nil)

		let ignoring = upstream.ignoringCascadeContext()
		#expect(try ignoring.value(forKey: cascadeContextKey, type: .string).value?.content == "bar")
		#expect(try ignoring.value(forKey: ["foo"], type: .string).value?.content == "bar")

		// The rest of the context is kept
		let cascadeAndOtherContextKey = AbsoluteConfigKey(
			["baz"],
			context: cascadeContext.merging(["environment": "production"]) { $1 },
		)
		#expect(try ignoring.value(forKey: cascadeAndOtherContextKey, type: .string).value?.content == "qux")
	}
}
