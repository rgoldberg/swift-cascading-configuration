//
// CascadeContextTests.swift
// swift-cascading-configuration
//
// Copyright © 2026 Ross Goldberg
// SPDX-License-Identifier: MIT
//

import CascadingConfiguration
import Testing

struct CascadeContextTests {
	@available(Configuration 1.0, *)
	@Test
	func `cascade scope floor entries`() {
		#expect([String: ConfigContextValue].cascadeScopeFloor(1) == ["cascadingConfiguration.cascadeScopeFloor": 1])
		#expect(
			[String: ConfigContextValue].cascadeScopeFloor(.noCascading)
				== ["cascadingConfiguration.cascadeScopeFloor": .int(.max)],
		)
	}

	@available(Configuration 1.0, *)
	@Test
	func `base scope cascade scope floor entries`() {
		#expect(
			[String: ConfigContextValue].baseScopeCascadeScopeFloor(0)
				== ["cascadingConfiguration.baseScopeCascadeScopeFloor": 0],
		)
	}

	@available(Configuration 1.0, *)
	@Test
	func `base scope entries`() {
		#expect([String: ConfigContextValue].baseScope([]) == ["cascadingConfiguration.baseScope.count": 0])
		let expected = [
			"cascadingConfiguration.baseScope.count": ConfigContextValue.int(2),
			"cascadingConfiguration.baseScope.0": "org",
			"cascadingConfiguration.baseScope.1": "tool",
		]
		#expect([String: ConfigContextValue].baseScope(["org", "tool"]) == expected)
	}

	@available(Configuration 1.0, *)
	@Test
	func `entries replace their own kind only`() {
		let context = ["environment": "production", "cascadingConfiguration.baseScopeCount": "kept"]
			.cascadeScopeFloor(2)
			.baseScope(["org", "tool"])
			.cascadeScopeFloor(1)
			// Leaves no entry of the replaced base scope
			.baseScope(["git"])
		let expected = [
			"environment": ConfigContextValue.string("production"),
			"cascadingConfiguration.baseScopeCount": "kept",
			"cascadingConfiguration.cascadeScopeFloor": 1,
			"cascadingConfiguration.baseScope.count": 1,
			"cascadingConfiguration.baseScope.0": "git",
		]
		#expect(context == expected)
	}
}
