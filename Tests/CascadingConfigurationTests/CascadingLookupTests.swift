//
// CascadingLookupTests.swift
// swift-cascading-configuration
//
// Copyright © 2026 Ross Goldberg
// SPDX-License-Identifier: MIT
//

import CascadingConfiguration
import Testing

struct CascadingLookupTests {
	@available(Configuration 1.0, *)
	@Test
	func `base scope is prepended but never removed by default`() throws {
		let recorder = KeyRecordingProvider()
		_ = try CascadingProvider(providers: [.init(recorder, baseScope: ["tool"]), .init(recorder)])
			.value(forKey: ["install", "limit"], type: .string)
		#expect(recorder.keys == ["tool.install.limit", "install.limit", "tool.limit", "limit"])
	}

	@available(Configuration 1.0, *)
	@Test
	func `base scope is prepended to empty key`() throws {
		let scoped = KeyRecordingProvider()
		let unscoped = KeyRecordingProvider()
		let provider = CascadingProvider(providers: [.init(scoped, baseScope: ["tool"]), .init(unscoped)])
		_ = try provider.value(forKey: [], type: .string)
		#expect(scoped.keys == ["tool"])
		#expect(unscoped.keys == [""])
	}

	@available(Configuration 1.0, *)
	@Test
	func `empty key removes cascade context & applies base scope context`() throws {
		let unscoped = KeyRecordingProvider()
		let scoped = KeyRecordingProvider()
		_ = try CascadingProvider(providers: [.init(unscoped), .init(scoped, baseScope: ["tool"])]).value(
			forKey: .init([], context: ["environment": "production"].baseScope(["git"])),
			type: .string,
		)
		#expect(unscoped.contexts == [["environment": "production"]])
		#expect(scoped.keys == ["git"])
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
		#expect(recorder.keys == ["tool.pager", "org.tool.pager", "pager", "org.pager", "pager"])
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
		#expect(recorder.keys == expected)
	}

	@available(Configuration 1.0, *)
	@Test
	func `base scope cascade scope floor keeps leading components of the base scope`() throws {
		let recorder = KeyRecordingProvider()
		_ = try CascadingProvider(providers: [.init(recorder, baseScope: ["org", "tool"], baseScopeCascadeScopeFloor: 1)])
			.value(forKey: ["a", "limit"], type: .string)
		#expect(recorder.keys == ["org.tool.a.limit", "org.tool.limit", "org.limit"])
	}

	@available(Configuration 1.0, *)
	@Test
	func `context base scope cascade scope floor overrides upstream base scope cascade scope floor`() throws {
		let recorder = KeyRecordingProvider()
		_ = try CascadingProvider(providers: [.init(recorder, baseScope: ["tool"], baseScopeCascadeScopeFloor: 0)]).value(
			forKey: .init(["install", "limit"], context: .baseScopeCascadeScopeFloor(.noCascading)),
			type: .string,
		)
		#expect(recorder.keys == ["tool.install.limit", "tool.limit"])
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
		#expect(recorder.keys == ["tool.install.limit"])
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
		#expect(recorder.keys == ["tool.install.limit", "tool.limit", "limit"])
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
		#expect(recorder.keys == ["install.limit"])
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
		#expect(scoped.keys == expectedScoped)
		#expect(unscoped.keys == expectedUnscoped)
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
		#expect(recorder.keys == expected)
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
		#expect(result.value?.content == "specific")
		#expect(recorder.keys.isEmpty)
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
		#expect(recorder.keys.isEmpty)
	}

	@available(Configuration 1.0, *)
	@Test(
		arguments: [
			(Int?.none, ConfigContent?.some("1 scope")),
			(0, "1 scope"),
			(1, "1 scope"),
			(2, nil),
			(3, nil),
			(4, nil),
		],
	)
	func `cascade scope floor limits cascade`(cascadeScopeFloor: Int?, expected: ConfigContent?) throws {
		// The only value is at a key with 1 scope, so the lookup finds it unless
		// the floor is above 1
		let provider = CascadingProvider(providers: [.init(InMemoryProvider(values: ["a.setting": "1 scope"]))])
		let key = AbsoluteConfigKey(
			["a", "b", "c", "setting"],
			context: cascadeScopeFloor.map { ["cascadingConfiguration.cascadeScopeFloor": .int($0)] } ?? [:],
		)
		#expect(try provider.value(forKey: key, type: .string).value?.content == expected)
		#expect(try provider.snapshot().value(forKey: key, type: .string).value?.content == expected)
	}

	@available(Configuration 1.0, *)
	@Test
	func `upstream cascade scope floor limits only its upstream`() throws {
		let provider = CascadingProvider(
			providers: [
				.init(InMemoryProvider(name: "floored", values: ["setting": "floored"]), cascadeScopeFloor: 1),
				.init(InMemoryProvider(name: "full", values: ["setting": "full"])),
			],
		)
		#expect(try provider.value(forKey: ["a", "setting"], type: .string).value?.content == "full")
	}

	@available(Configuration 1.0, *)
	@Test
	func `context cascade scope floor overrides upstream cascade scope floor`() throws {
		let provider = CascadingProvider(
			providers: [.init(InMemoryProvider(values: ["setting": "general"]), cascadeScopeFloor: .noCascading)],
		)
		let key = AbsoluteConfigKey(["a", "setting"], context: .cascadeScopeFloor(0))
		#expect(try provider.value(forKey: key, type: .string).value?.content == "general")
	}

	@available(Configuration 1.0, *)
	@Test
	func `cascade scope floor stops at no cascading`() throws {
		let recorder = KeyRecordingProvider()
		_ = try CascadingProvider(
			providers: [
				.init(recorder, baseScope: ["tool"], cascadeScopeFloor: .noCascading),
			],
		).value(forKey: ["install", "limit"], type: .string)
		#expect(recorder.keys == ["tool.install.limit"])
	}
}
