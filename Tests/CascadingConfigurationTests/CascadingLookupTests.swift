//
// CascadingLookupTests.swift
// swift-cascading-configuration
//
// Copyright © 2026 Ross Goldberg
// SPDX-License-Identifier: MIT
//

import CascadingConfiguration
import Synchronization
import Testing

struct CascadingLookupTests {
	@available(Configuration 1.0, *)
	@Test
	func `base scope is prepended but never removed by default`() throws {
		let recorder = KeyRecordingProvider()
		_ = try CascadingProvider(providers: [.init(recorder, baseScope: ["tool"]), .init(recorder)])
			.value(forKey: ["install", "limit"], type: .string)
		#expect(recorder.keys.withLock(\.self) == ["tool.install.limit", "install.limit", "tool.limit", "limit"])
	}

	@available(Configuration 1.0, *)
	@Test
	func `base scope is prepended to empty key`() throws {
		let scoped = KeyRecordingProvider()
		let unscoped = KeyRecordingProvider()
		let provider = CascadingProvider(providers: [.init(scoped, baseScope: ["tool"]), .init(unscoped)])
		_ = try provider.value(forKey: [], type: .string)
		#expect(scoped.keys.withLock(\.self) == ["tool"])
		#expect(unscoped.keys.withLock(\.self) == [""])
	}

	@available(Configuration 1.0, *)
	@Test
	func `empty key removes cascade context & applies base scope context`() throws {
		let unscoped = ContextRecordingProvider()
		let scoped = KeyRecordingProvider()
		_ = try CascadingProvider(providers: [.init(unscoped), .init(scoped, baseScope: ["tool"])]).value(
			forKey: .init([], context: ["environment": "production"].baseScope(["git"])),
			type: .string,
		)
		#expect(unscoped.contexts.withLock(\.self) == [["environment": "production"]])
		#expect(scoped.keys.withLock(\.self) == ["git"])
	}

	@available(Configuration 1.0, *)
	@Test
	func `lookups interleave upstreams by step`() throws {
		let recorder = KeyRecordingProvider()
		_ = try CascadingProvider(
			providers: [
				.init(recorder, baseScope: ["tool"], baseScopeCascadeScopeFloor: 0),
				.init(recorder, baseScope: ["org", "tool"], baseScopeCascadeScopeFloor: 0),
			],
		).value(forKey: ["pager"], type: .string)
		#expect(recorder.keys.withLock(\.self) == ["tool.pager", "org.tool.pager", "pager", "org.pager", "pager"])
	}

	@available(Configuration 1.0, *)
	@Test(
		arguments: [
			(nil, ["tool.install.limit", "tool.limit"]),
			(0, ["tool.install.limit", "tool.limit", "limit"]),
			(1, ["tool.install.limit", "tool.limit"]),
			// A floor above the number of components of the base scope keeps no other
			// scope
			(2, ["tool.install.limit", "tool.limit"]),
		] as [(CascadingProvider.CascadeScopeFloor?, [String])],
	)
	func `base scope cascade scope floor counts only components of the base scope`(
		floor: CascadingProvider.CascadeScopeFloor?,
		expected: [String],
	) throws {
		let recorder = KeyRecordingProvider()
		let provider = CascadingProvider(providers: [.init(recorder, baseScope: ["tool"])])
		let context = floor.map([String: ConfigContextValue].baseScopeCascadeScopeFloor) ?? [:]
		_ = try provider.value(forKey: .init(["install", "limit"], context: context), type: .string)
		#expect(recorder.keys.withLock(\.self) == expected)
	}

	@available(Configuration 1.0, *)
	@Test
	func `base scope cascade scope floor keeps leading components of the base scope`() throws {
		let recorder = KeyRecordingProvider()
		_ = try CascadingProvider(providers: [.init(recorder, baseScope: ["org", "tool"], baseScopeCascadeScopeFloor: 1)])
			.value(forKey: ["a", "limit"], type: .string)
		#expect(recorder.keys.withLock(\.self) == ["org.tool.a.limit", "org.tool.limit", "org.limit"])
	}

	@available(Configuration 1.0, *)
	@Test
	func `context base scope cascade scope floor overrides upstream base scope cascade scope floor`() throws {
		let recorder = KeyRecordingProvider()
		_ = try CascadingProvider(providers: [.init(recorder, baseScope: ["tool"], baseScopeCascadeScopeFloor: 0)]).value(
			forKey: .init(["install", "limit"], context: .baseScopeCascadeScopeFloor(.noCascading)),
			type: .string,
		)
		#expect(recorder.keys.withLock(\.self) == ["tool.install.limit", "tool.limit"])
	}

	@available(Configuration 1.0, *)
	@Test(arguments: [ConfigContextValue.string("0"), -1])
	func `base scope cascade scope floor ignored unless nonnegative integer`(floor: ConfigContextValue) throws {
		// The entry would let the cascade remove the base scope if it were not
		// ignored
		let recorder = KeyRecordingProvider()
		_ = try CascadingProvider(providers: [.init(recorder, baseScope: ["tool"])]).value(
			forKey: .init(["install", "limit"], context: ["cascadingConfiguration.baseScopeCascadeScopeFloor": floor]),
			type: .string,
		)
		#expect(recorder.keys.withLock(\.self) == ["tool.install.limit", "tool.limit"])
	}

	@available(Configuration 1.0, *)
	@Test(
		arguments: [
			(nil, 1),
			(1, 0),
			(.noCascading, 0),
		] as [(CascadingProvider.CascadeScopeFloor?, CascadingProvider.CascadeScopeFloor)],
	)
	func `nonzero cascade scope floor keeps whole base scope`(
		contextFloor: CascadingProvider.CascadeScopeFloor?,
		upstreamFloor: CascadingProvider.CascadeScopeFloor,
	) throws {
		let recorder = KeyRecordingProvider()
		let context = contextFloor.map([String: ConfigContextValue].cascadeScopeFloor) ?? [:]
		_ = try CascadingProvider(
			providers: [
				.init(recorder, baseScope: ["tool"], cascadeScopeFloor: upstreamFloor, baseScopeCascadeScopeFloor: 0),
			],
		).value(forKey: .init(["install", "limit"], context: context), type: .string)
		#expect(recorder.keys.withLock(\.self) == ["tool.install.limit"])
	}

	@available(Configuration 1.0, *)
	@Test
	func `context cascade scope floor of 0 applies base scope cascade scope floor`() throws {
		let recorder = KeyRecordingProvider()
		_ = try CascadingProvider(
			providers: [
				.init(recorder, baseScope: ["tool"], cascadeScopeFloor: 1, baseScopeCascadeScopeFloor: 0),
			],
		).value(forKey: .init(["install", "limit"], context: .cascadeScopeFloor(0)), type: .string)
		#expect(recorder.keys.withLock(\.self) == ["tool.install.limit", "tool.limit", "limit"])
	}

	@available(Configuration 1.0, *)
	@Test
	func `base scope cascade scope floor ignored without base scope`() throws {
		let recorder = KeyRecordingProvider()
		_ = try CascadingProvider(
			providers: [
				.init(recorder, cascadeScopeFloor: 1, baseScopeCascadeScopeFloor: 0),
			],
		).value(forKey: ["install", "limit"], type: .string)
		#expect(recorder.keys.withLock(\.self) == ["install.limit"])
	}

	@available(Configuration 1.0, *)
	@Test(
		arguments: [
			([String](), ["pager"], ["pager"]),
			(["git"], ["git.pager"], ["pager"]),
		],
	)
	func `base scope context overrides only nonempty base scopes`(
		baseScope: [String],
		expectedScoped: [String],
		expectedUnscoped: [String],
	) throws {
		let scoped = KeyRecordingProvider()
		let unscoped = KeyRecordingProvider()
		_ = try CascadingProvider(providers: [.init(scoped, baseScope: ["tool"]), .init(unscoped)]).value(
			forKey: .init(["pager"], context: .baseScope(baseScope)),
			type: .string,
		)
		#expect(scoped.keys.withLock(\.self) == expectedScoped)
		#expect(unscoped.keys.withLock(\.self) == expectedUnscoped)
	}

	@available(Configuration 1.0, *)
	@Test(
		arguments: [
			(
				[String: ConfigContextValue].baseScope(["org", "git"]).baseScopeCascadeScopeFloor(1),
				["org.git.a.pager", "org.git.pager", "org.pager"],
			),
			// The example of the documentation of the cascade context functions
			(.cascadeScopeFloor(1).baseScope(["git"]), ["git.a.pager"]),
		],
	)
	func `cascade context entries combine`(context: [String: ConfigContextValue], expected: [String]) throws {
		let recorder = KeyRecordingProvider()
		_ = try CascadingProvider(providers: [.init(recorder, baseScope: ["tool"])])
			.value(forKey: .init(["a", "pager"], context: context), type: .string)
		#expect(recorder.keys.withLock(\.self) == expected)
	}

	@available(Configuration 1.0, *)
	@Test(
		arguments: [
			// The base scope claims 2 components, but has only 1
			[
				"cascadingConfiguration.baseScope.count": ConfigContextValue.int(2),
				"cascadingConfiguration.baseScope.0": .string("git"),
			],
			// The base scope claims more components than any context can hold
			["cascadingConfiguration.baseScope.count": .int(.max)],
			// The base scope claims a negative number of components
			["cascadingConfiguration.baseScope.count": -1],
			// The base scope claims 1 component, but has 2
			[
				"cascadingConfiguration.baseScope.count": 1,
				"cascadingConfiguration.baseScope.0": "git",
				"cascadingConfiguration.baseScope.1": "org",
			],
			// A component of the base scope is not a string
			["cascadingConfiguration.baseScope.count": 1, "cascadingConfiguration.baseScope.0": 1],
			// The base scope has a component, but no count
			["cascadingConfiguration.baseScope.0": "git"],
			// The count of the base scope is not an integer
			["cascadingConfiguration.baseScope.count": "1", "cascadingConfiguration.baseScope.0": "git"],
			// The base scope has as many components as it claims, but lacks the
			// component at index 1
			[
				"cascadingConfiguration.baseScope.count": 2,
				"cascadingConfiguration.baseScope.0": "org",
				"cascadingConfiguration.baseScope.2": "git",
			],
		],
	)
	func `invalid base scope context is ignored`(context: [String: ConfigContextValue]) throws {
		let recorder = KeyRecordingProvider()
		let provider = CascadingProvider(providers: [.init(recorder, baseScope: ["tool"])])
		_ = try provider.value(forKey: .init(["pager"], context: context), type: .string)
		#expect(recorder.keys.withLock(\.self) == ["tool.pager"])
	}

	@available(Configuration 1.0, *)
	@Test
	func `cascading value stops at 1st value`() throws {
		let recorder = KeyRecordingProvider()
		let result = try CascadingProvider(
			providers: [
				.init(InMemoryProvider(values: ["a.setting": "specific"])),
				.init(recorder),
				.init(FailingProvider(failingKey: ["setting"])),
			],
		).value(forKey: ["a", "setting"], type: .string)
		#expect(try result.value?.content.asString == "specific")
		#expect(recorder.keys.withLock(\.self).isEmpty)
	}

	@available(Configuration 1.0, *)
	@Test
	func `type mismatch at more specific key halts cascading`() {
		// InMemoryProvider throws for a value of another type
		let recorder = KeyRecordingProvider()
		#expect(throws: (any Error).self) {
			try CascadingProvider(
				providers: [.init(InMemoryProvider(values: ["a.setting": 1, "setting": "general"])), .init(recorder)],
			).value(forKey: ["a", "setting"], type: .string)
		}
		#expect(recorder.keys.withLock(\.self).isEmpty)
	}
}
