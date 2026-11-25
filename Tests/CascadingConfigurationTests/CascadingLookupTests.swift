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
		let upstream = KeyRecordingProvider()
		let provider = CascadingProvider(providers: [
			.init(upstream, baseScope: ["tool"]),
			.init(KeyRecordingProvider()),
		])
		_ = try provider.value(forKey: ["install", "limit"], type: .string)
		#expect(upstream.keys.withLock(\.self) == ["tool.install.limit", "tool.limit"])
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
	func `lookups interleave upstreams by step`() throws {
		let recorder = KeyRecordingProvider()
		let provider = CascadingProvider(
			providers: [
				.init(recorder, baseScope: ["tool"], baseScopeCascadeScopeFloor: 0),
				.init(recorder, baseScope: ["org", "tool"], baseScopeCascadeScopeFloor: 0),
			],
		)
		_ = try provider.value(forKey: ["pager"], type: .string)
		#expect(recorder.keys.withLock(\.self) == ["tool.pager", "org.tool.pager", "pager", "org.pager", "pager"])
	}

	@available(Configuration 1.0, *)
	@Test(
		arguments: [
			(nil, ["tool.install.limit", "tool.limit"]),
			(0, ["tool.install.limit", "tool.limit", "limit"]),
			(1, ["tool.install.limit", "tool.limit"]),
			// A floor above the number of base scopes keeps no other scope
			(2, ["tool.install.limit", "tool.limit"]),
		] as [(Int?, [String])],
	)
	func `base scope cascade scope floor counts only base scopes`(floor: Int?, expected: [String]) throws {
		let recorder = KeyRecordingProvider()
		let provider = CascadingProvider(providers: [.init(recorder, baseScope: ["tool"])])
		let context: [String: ConfigContextValue] =
			floor.map { [CascadingProvider.baseScopeCascadeScopeFloorContextKey: .int($0)] } ?? [:]
		_ = try provider.value(forKey: .init(["install", "limit"], context: context), type: .string)
		#expect(recorder.keys.withLock(\.self) == expected)
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
		let provider = CascadingProvider(providers: [
			.init(recorder, baseScope: ["tool"], cascadeScopeFloor: upstreamFloor, baseScopeCascadeScopeFloor: 0),
		])
		let context: [String: ConfigContextValue] =
			contextFloor.map { [CascadingProvider.cascadeScopeFloorContextKey: .int($0.rawValue)] } ?? [:]
		_ = try provider.value(forKey: .init(["install", "limit"], context: context), type: .string)
		#expect(recorder.keys.withLock(\.self) == ["tool.install.limit"])
	}

	@available(Configuration 1.0, *)
	@Test
	func `zero context cascade scope floor applies base scope cascade scope floor`() throws {
		let recorder = KeyRecordingProvider()
		let provider = CascadingProvider(providers: [
			.init(recorder, baseScope: ["tool"], cascadeScopeFloor: 1, baseScopeCascadeScopeFloor: 0),
		])
		let context: [String: ConfigContextValue] = [CascadingProvider.cascadeScopeFloorContextKey: 0]
		_ = try provider.value(forKey: .init(["install", "limit"], context: context), type: .string)
		#expect(recorder.keys.withLock(\.self) == ["tool.install.limit", "tool.limit", "limit"])
	}

	@available(Configuration 1.0, *)
	@Test
	func `base scope cascade scope floor ignored without base scope`() throws {
		let recorder = KeyRecordingProvider()
		let provider = CascadingProvider(providers: [
			.init(recorder, cascadeScopeFloor: 1, baseScopeCascadeScopeFloor: 0),
		])
		_ = try provider.value(forKey: ["install", "limit"], type: .string)
		#expect(recorder.keys.withLock(\.self) == ["install.limit"])
	}

	@available(Configuration 1.0, *)
	@Test(
		arguments: [
			([], ["pager"], ["pager"]),
			(["git"], ["git.pager"], ["pager"]),
		] as [([String], [String], [String])],
	)
	func `base scope context overrides only non empty base scopes`(
		baseScope: [String],
		expectedScoped: [String],
		expectedUnscoped: [String],
	) throws {
		let scoped = KeyRecordingProvider()
		let unscoped = KeyRecordingProvider()
		let provider = CascadingProvider(providers: [.init(scoped, baseScope: ["tool"]), .init(unscoped)])
		_ = try provider.value(
			forKey: .init(["pager"], context: CascadingProvider.baseScopeContext(baseScope)),
			type: .string,
		)
		#expect(scoped.keys.withLock(\.self) == expectedScoped)
		#expect(unscoped.keys.withLock(\.self) == expectedUnscoped)
	}

	@available(Configuration 1.0, *)
	@Test
	func `invalid base scope context is ignored`() throws {
		let recorder = KeyRecordingProvider()
		let provider = CascadingProvider(providers: [.init(recorder, baseScope: ["tool"])])
		// The base scope claims 2 components, but has only 1
		let context: [String: ConfigContextValue] = [
			"cascadingConfiguration.baseScope.count": 2,
			"cascadingConfiguration.baseScope.0": "git",
		]
		_ = try provider.value(forKey: .init(["pager"], context: context), type: .string)
		#expect(recorder.keys.withLock(\.self) == ["tool.pager"])
	}
}
