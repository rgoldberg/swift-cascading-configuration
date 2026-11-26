//
// CascadingProviderTests.swift
// swift-cascading-configuration
//
// Copyright © 2026 Ross Goldberg
// SPDX-License-Identifier: MIT
//

import CascadingConfiguration
import ConfigurationTesting
import Testing

/// The bytes of a byte configuration value that the compat test expects.
private let magic = [UInt8(0x6d), 0x61, 0x67, 0x69, 0x63]

/// The bytes of another byte configuration value that the compat test expects.
private let magic2 = [UInt8(0x6d), 0x61, 0x67, 0x69, 0x63, 0x32]

struct CascadingProviderTests {
	@available(Configuration 1.0, *)
	@Test
	func `get value prefers most specific key`() throws {
		let result = try CascadingProvider(
			providers: [
				.init(
					InMemoryProvider(values: ["a.b.setting": "specific", "a.setting": "middle", "setting": "general"]),
				),
			],
		).value(forKey: ["a", "b", "setting"], type: .string)
		#expect(result.value?.content == "specific")
		#expect(result.encodedKey == "a.b.setting")
	}

	@available(Configuration 1.0, *)
	@Test
	func `get value cascades to less specific keys`() throws {
		let provider = CascadingProvider(
			providers: [.init(InMemoryProvider(values: ["a.setting": "middle", "setting": "general"]))],
		)

		let middleResult = try provider.value(forKey: ["a", "b", "c", "setting"], type: .string)
		#expect(middleResult.value?.content == "middle")
		#expect(middleResult.encodedKey == "a.setting")

		let generalResult = try provider.value(forKey: ["x", "setting"], type: .string)
		#expect(generalResult.value?.content == "general")
		#expect(generalResult.encodedKey == "setting")
	}

	@available(Configuration 1.0, *)
	@Test
	func `get value only removes innermost scopes`() throws {
		// "b.setting" is not a cascading key of "a.b.setting", whose scopes are
		// removed from the inside out
		let provider = CascadingProvider(providers: [.init(InMemoryProvider(values: ["b.setting": "unrelated"]))])
		let result = try provider.value(forKey: ["a", "b", "setting"], type: .string)
		#expect(result.value == nil)
		#expect(result.encodedKey == "a.b.setting")
	}

	@available(Configuration 1.0, *)
	@Test
	func `get value key specificity over provider order`() throws {
		let result = try CascadingProvider(
			providers: [
				.init(InMemoryProvider(name: "1st", values: ["setting": "1st general"])),
				.init(InMemoryProvider(name: "2nd", values: ["a.setting": "2nd specific"])),
			],
		).value(forKey: ["a", "setting"], type: .string)
		#expect(result.value?.content == "2nd specific")
	}

	@available(Configuration 1.0, *)
	@Test
	func `get value provider order within key`() throws {
		let result = try CascadingProvider(
			providers: [
				.init(InMemoryProvider(name: "1st", values: ["setting": "1st"])),
				.init(InMemoryProvider(name: "2nd", values: ["setting": "2nd"])),
			],
		).value(forKey: ["a", "setting"], type: .string)
		#expect(result.value?.content == "1st")
	}

	@available(Configuration 1.0, *)
	@Test
	func `get value error halts cascading`() throws {
		let recorder = KeyRecordingProvider()
		#expect(throws: FailingProvider.TestError.self) {
			try CascadingProvider(
				providers: [
					.init(FailingProvider(failingKey: ["a", "setting"])),
					.init(recorder),
					.init(InMemoryProvider(values: ["setting": "unreachable"])),
				],
			).value(forKey: ["a", "setting"], type: .string)
		}
		#expect(recorder.keys.isEmpty)
	}

	@available(Configuration 1.0, *)
	@Test
	func `fetch value error halts cascading`() async {
		let recorder = KeyRecordingProvider()
		await #expect(throws: FailingProvider.TestError.self) {
			try await CascadingProvider(
				providers: [
					.init(FailingProvider(failingKey: ["a", "setting"])),
					.init(recorder),
					.init(InMemoryProvider(values: ["setting": "unreachable"])),
				],
			).fetchValue(forKey: ["a", "setting"], type: .string)
		}
		#expect(recorder.keys.isEmpty)
	}

	@available(Configuration 1.0, *)
	@Test(.timeLimit(.minutes(1)))
	func `watch value error halts cascading`() async throws {
		try await CascadingProvider(
			providers: [
				.init(FailingProvider(failingKey: ["a", "setting"])),
				.init(InMemoryProvider(values: ["setting": "unreachable"])),
			],
		).watchValue(forKey: ["a", "setting"], type: .string) { updates in
			var iterator = updates.makeAsyncIterator()
			await #expect(throws: FailingProvider.TestError.self) {
				try await iterator.next(isolation: #isolation)?.get()
			}
		}
	}

	@available(Configuration 1.0, *)
	@Test(.timeLimit(.minutes(1)))
	func `watch value prefers more specific value over less specific error`() async throws {
		try await CascadingProvider(
			providers: [
				.init(InMemoryProvider(values: ["a.setting": "specific"])),
				.init(FailingProvider(failingKey: ["setting"])),
			],
		).watchValue(forKey: ["a", "setting"], type: .string) { updates in
			var iterator = updates.makeAsyncIterator()
			let result = try await iterator.next(isolation: #isolation)?.get()
			#expect(result?.value?.content == "specific")
		}
	}

	@available(Configuration 1.0, *)
	@Test(.timeLimit(.minutes(1)))
	func `watch value without value returns result of 1st lookup`() async throws {
		try await CascadingProvider(
			providers: [
				.init(InMemoryProvider(name: "1st", values: [:])),
				.init(InMemoryProvider(name: "2nd", values: [:]), baseScope: ["tool"]),
			],
		).watchValue(forKey: ["a", "setting"], type: .string) { updates in
			var iterator = updates.makeAsyncIterator()
			let result = try await iterator.next(isolation: #isolation)?.get()
			#expect(result?.value == nil)
			#expect(result?.encodedKey == "a.setting")
		}
	}

	@available(Configuration 1.0, *)
	@Test(arguments: [ConfigContextValue.string("0"), -1])
	func `cascade scope floor ignored unless nonnegative integer`(cascadeScopeFloor: ConfigContextValue) throws {
		// The entry would let the cascade reach "setting" if it were not ignored
		let provider = CascadingProvider(
			providers: [.init(InMemoryProvider(values: ["setting": "general"]), cascadeScopeFloor: 1)],
		)
		let key = AbsoluteConfigKey(
			["a", "setting"],
			context: ["cascadingConfiguration.cascadeScopeFloor": cascadeScopeFloor],
		)
		#expect(try provider.value(forKey: key, type: .string).value == nil)
	}

	@available(Configuration 1.0, *)
	@Test
	func `cascade context removed from upstream context`() throws {
		let upstream = KeyRecordingProvider()
		let key = AbsoluteConfigKey(
			["a", "setting"],
			context: [
				"environment": "production",
				// Not in the cascade context, despite sharing its name with the base
				// scope entries
				"baseScope.0": "kept",
			]
				.baseScope(["tool"])
				.cascadeScopeFloor(1)
				.baseScopeCascadeScopeFloor(0),
		)
		_ = try CascadingProvider(providers: [.init(upstream)]).value(forKey: key, type: .string)
		#expect(upstream.contexts == [["baseScope.0": "kept", "environment": "production"]])
	}

	@available(Configuration 1.0, *)
	@Test
	func `cascade scope floor through reader`() {
		let config = ConfigReader(
			provider: CascadingProvider(providers: [.init(InMemoryProvider(values: ["setting": "general"]))]),
		)
		#expect(config.string(forKey: "a.setting") == "general")
		#expect(config.string(forKey: .init("a.setting", context: .cascadeScopeFloor(1))) == nil)
	}

	@available(Configuration 1.0, *)
	@Test
	func `cascade scope floor limits fetch`() async throws {
		let result = try await CascadingProvider(providers: [.init(InMemoryProvider(values: ["setting": "general"]))])
			.fetchValue(forKey: .init(["a", "b", "setting"], context: .cascadeScopeFloor(1)), type: .string)
		#expect(result.value == nil)
		#expect(result.encodedKey == "a.b.setting")
	}

	@available(Configuration 1.0, *)
	@Test(.timeLimit(.minutes(1)))
	func `cascade scope floor limits watch`() async throws {
		let upstream = MutableInMemoryProvider(initialValues: ["setting": "general"])
		try await withThrowingTaskGroup(of: Void.self) { group in
			let future1 = TestFuture<ConfigContent?>(name: "future1")
			let future2 = TestFuture<ConfigContent?>(name: "future2")
			group.addTask {
				try await CascadingProvider(providers: [.init(upstream)])
					.watchValue(forKey: .init(["a", "b", "setting"], context: .cascadeScopeFloor(1)), type: .string) { updates in
						var iterator = updates.makeAsyncIterator()
						try await future1.fulfill(iterator.next()?.get().value?.content)
						try await future2.fulfill(iterator.next()?.get().value?.content)
					}
			}
			// "setting" has fewer scopes than the floor, so its value is not found
			await #expect(future1.value == nil)

			upstream.setValue("middle", forKey: "a.setting")
			await #expect(future2.value == "middle")
			try await group.waitForAll()
		}
	}

	@available(Configuration 1.0, *)
	@Test
	func `cascade scope floor raw value`() {
		#expect(CascadingProvider.CascadeScopeFloor(rawValue: 0) == 0)
		#expect(CascadingProvider.CascadeScopeFloor(rawValue: 1) == 1)
		#expect(CascadingProvider.CascadeScopeFloor(rawValue: -1) == nil)
		#expect(CascadingProvider.CascadeScopeFloor(rawValue: .max) == .noCascading)
		#expect(CascadingProvider.CascadeScopeFloor.noCascading.rawValue == .max)
	}

	@available(Configuration 1.0, *)
	@Test
	func `fetch value cascades`() async throws {
		let provider = CascadingProvider(
			providers: [
				.init(InMemoryProvider(name: "1st", values: ["setting": "1st general"])),
				.init(InMemoryProvider(name: "2nd", values: ["a.setting": "2nd specific"])),
			],
		)

		let specificResult = try await provider.fetchValue(forKey: ["a", "b", "setting"], type: .string)
		#expect(specificResult.value?.content == "2nd specific")
		#expect(specificResult.encodedKey == "a.setting")

		let absentResult = try await provider.fetchValue(forKey: ["a", "other"], type: .string)
		#expect(absentResult.value == nil)
		#expect(absentResult.encodedKey == "a.other")
	}

	@available(Configuration 1.0, *)
	@Test(arguments: [AbsoluteConfigKey(["a", "setting"]), ["setting"]])
	func `fetch value fetches from upstreams`(fetchableKey: AbsoluteConfigKey) async throws {
		// The upstream provider has the value only when fetching it, for either the
		// requested key or a cascaded key
		let result = try await CascadingProvider(providers: [.init(FetchOnlyProvider(fetchableKey: fetchableKey))])
			.fetchValue(forKey: ["a", "setting"], type: .string)
		#expect(result.value?.content == "fetched")
	}

	@available(Configuration 1.0, *)
	@Test(.timeLimit(.minutes(1)))
	func `watch value cascades`() async throws {
		let upstream = MutableInMemoryProvider(initialValues: ["setting": "general"])
		try await withThrowingTaskGroup(of: Void.self) { group in
			let future1 = TestFuture<ConfigContent?>(name: "future1")
			let future2 = TestFuture<ConfigContent?>(name: "future2")
			group.addTask {
				try await CascadingProvider(providers: [.init(upstream)])
					.watchValue(forKey: ["a", "setting"], type: .string) { updates in
						var iterator = updates.makeAsyncIterator()
						try await future1.fulfill(iterator.next()?.get().value?.content)
						try await future2.fulfill(iterator.next()?.get().value?.content)
					}
			}
			await #expect(future1.value == "general")

			upstream.setValue("specific", forKey: "a.setting")
			await #expect(future2.value == "specific")
			try await group.waitForAll()
		}
	}

	@available(Configuration 1.0, *)
	@Test(.timeLimit(.minutes(1)))
	func `watch value key specificity over provider order`() async throws {
		let first = MutableInMemoryProvider(name: "1st", initialValues: ["setting": "1st general"])
		let second = MutableInMemoryProvider(name: "2nd", initialValues: [:])
		try await withThrowingTaskGroup(of: Void.self) { group in
			let future1 = TestFuture<ConfigContent?>(name: "future1")
			let future2 = TestFuture<ConfigContent?>(name: "future2")
			let future3 = TestFuture<ConfigContent?>(name: "future3")
			group.addTask {
				try await CascadingProvider(providers: [.init(first), .init(second)])
					.watchValue(forKey: ["a", "setting"], type: .string) { updates in
						var iterator = updates.makeAsyncIterator()
						try await future1.fulfill(iterator.next()?.get().value?.content)
						try await future2.fulfill(iterator.next()?.get().value?.content)
						try await future3.fulfill(iterator.next()?.get().value?.content)
					}
			}
			await #expect(future1.value == "1st general")

			// The 2nd provider's specific value beats the 1st provider's general
			// value
			second.setValue("2nd specific", forKey: "a.setting")
			await #expect(future2.value == "2nd specific")

			// Within 1 key, the 1st provider's value beats the 2nd provider's value
			first.setValue("1st specific", forKey: "a.setting")
			await #expect(future3.value == "1st specific")
			try await group.waitForAll()
		}
	}

	@available(Configuration 1.0, *)
	@Test(.timeLimit(.minutes(1)))
	func `watch snapshot key specificity over provider order`() async throws {
		let first = MutableInMemoryProvider(name: "1st", initialValues: ["setting": "1st general"])
		let second = MutableInMemoryProvider(name: "2nd", initialValues: ["setting": "2nd general"])
		try await withThrowingTaskGroup(of: Void.self) { group in
			let future1 = TestFuture<ConfigContent?>(name: "future1")
			let future2 = TestFuture<ConfigContent?>(name: "future2")
			group.addTask {
				try await CascadingProvider(providers: [.init(first), .init(second)]).watchSnapshot { updates in
					var iterator = updates.makeAsyncIterator()
					let key = AbsoluteConfigKey(["a", "setting"])
					try await future1.fulfill(
						iterator.next()?.value(forKey: key, type: .string).value?.content,
					)
					try await future2.fulfill(
						iterator.next()?.value(forKey: key, type: .string).value?.content,
					)
				}
			}
			// Within 1 key, the 1st provider's value beats the 2nd provider's value
			await #expect(future1.value == "1st general")

			// The 2nd provider's specific value beats the 1st provider's general
			// value
			second.setValue("2nd specific", forKey: "a.setting")
			await #expect(future2.value == "2nd specific")
			try await group.waitForAll()
		}
	}

	@available(Configuration 1.0, *)
	@Test(.timeLimit(.minutes(1)))
	func `canceling watch value ends updates`() async throws {
		let upstream = MutableInMemoryProvider(initialValues: [:])
		let future = TestFuture<Void>(name: "future")
		let task = Task {
			try await CascadingProvider(providers: [.init(upstream), .init(upstream)])
				.watchValue(forKey: ["a", "setting"], type: .string) { updates in
					var iterator = updates.makeAsyncIterator()
					_ = try await iterator.next()
					future.fulfill(())
					// Ends iff canceling the task ends the updates
					while try await iterator.next() != nil {}
				}
		}
		await future.value
		task.cancel()
		try await task.value
	}

	@available(Configuration 1.0, *)
	@Test
	func `snapshot ignores later upstream changes`() throws {
		let upstream = MutableInMemoryProvider(initialValues: ["setting": "old"])
		let snapshot = CascadingProvider(providers: [.init(upstream)]).snapshot()
		upstream.setValue("new", forKey: "setting")
		#expect(try snapshot.value(forKey: ["a", "setting"], type: .string).value?.content == "old")
	}

	@available(Configuration 1.0, *)
	@Test
	func `later provider consulted after whole cascade`() {
		let config = ConfigReader(
			providers: [
				CascadingProvider(
					providers: [.init(InMemoryProvider(name: "primary", values: ["setting": "primary"]))],
				),
				CascadingProvider(
					providers: [
						.init(
							InMemoryProvider(name: "later", values: ["a.setting": "later specific", "other": "later"]),
						),
					],
				),
			],
		)
		// The primary cascade's general value beats the later provider's specific
		// value
		#expect(config.string(forKey: "a.setting") == "primary")
		// The later provider cascades by itself once the primary cascade finds
		// nothing
		#expect(config.string(forKey: "a.b.other") == "later")
	}

	@available(Configuration 1.0, *)
	@Test
	func compat() async throws {
		let upstream = InMemoryProvider(
			name: "test",
			values: [
				"string": "Hello",
				"other.string": "Other Hello",
				"int": 42,
				"other.int": 24,
				"double": 3.14,
				"other.double": 2.72,
				"bool": true,
				"other.bool": false,
				"bytes": .init(.bytes(magic), isSecret: false),
				"other.bytes": .init(.bytes(magic2), isSecret: false),
				"stringy.array": .init(.stringArray(["Hello", "World"]), isSecret: false),
				"other.stringy.array": .init(.stringArray(["Hello", "Swift"]), isSecret: false),
				"inty.array": .init(.intArray([42, 24]), isSecret: false),
				"other.inty.array": .init(.intArray([16, 32]), isSecret: false),
				"doubly.array": .init(.doubleArray([3.14, 2.72]), isSecret: false),
				"other.doubly.array": .init(.doubleArray([0.9, 1.8]), isSecret: false),
				"booly.array": .init(.boolArray([true, false]), isSecret: false),
				"other.booly.array": .init(.boolArray([false, true, true]), isSecret: false),
				"byteChunky.array": .init(.byteChunkArray([magic, magic2]), isSecret: false),
				"other.byteChunky.array": .init(.byteChunkArray([magic, magic2, magic]), isSecret: false),
			],
		)

		// The compat test expects no value for keys like "absent.string", which a
		// cascade would find at "string", so give every key a cascade scope floor
		// that prevents cascading
		let provider = CascadingProvider(providers: [.init(upstream, cascadeScopeFloor: .noCascading)])
		try await ProviderCompatTest(provider: provider).runTest()
	}

	@available(Configuration 1.0, *)
	@Test
	func `provider name`() {
		#expect(
			CascadingProvider(
				providers: [
					.init(InMemoryProvider(name: "1st", values: [:])),
					.init(InMemoryProvider(name: "2nd", values: [:])),
				],
			).providerName == "CascadingProvider[providers: InMemoryProvider[1st], InMemoryProvider[2nd]]",
		)
	}

	@available(Configuration 1.0, *)
	@Test
	func description() {
		#expect(
			CascadingProvider(
				providers: [
					.init(InMemoryProvider(name: "1st", values: [:]), baseScope: ["org", "tool"], cascadeScopeFloor: 1),
					.init(InMemoryProvider(name: "2nd", values: [:]), baseScopeCascadeScopeFloor: 0),
				],
			).description == """
				CascadingProvider[providers: \
				UpstreamProvider[provider: InMemoryProvider[1st, 0 values], baseScope: ["org", "tool"], \
				cascadeScopeFloor: 1, baseScopeCascadeScopeFloor: noCascading], \
				UpstreamProvider[provider: InMemoryProvider[2nd, 0 values], baseScope: [], \
				cascadeScopeFloor: 0, baseScopeCascadeScopeFloor: 0]]
				""",
		)
	}

	@available(Configuration 1.0, *)
	@Test
	func `debug description`() {
		#expect(
			CascadingProvider(providers: [.init(InMemoryProvider(name: "1st", values: [:]))]).debugDescription == """
				CascadingProvider[providers: \
				UpstreamProvider[provider: InMemoryProvider[1st, 0 values: ], baseScope: [], \
				cascadeScopeFloor: 0, baseScopeCascadeScopeFloor: noCascading]]
				""",
		)
	}

	@available(Configuration 1.0, *)
	@Test
	func `cascade scope floor description`() {
		#expect((1 as CascadingProvider.CascadeScopeFloor).description == "1")
		#expect(CascadingProvider.CascadeScopeFloor.noCascading.description == "noCascading")
	}

	// Swift Testing has exit tests only on macOS, Linux, FreeBSD, OpenBSD &
	// Windows (e.g., not on Android or iOS)
	#if os(macOS) || os(Linux) || os(FreeBSD) || os(OpenBSD) || os(Windows)
	@available(Configuration 1.0, *)
	@Test
	func `no upstream providers fails`() async {
		await #expect(processExitsWith: .failure) {
			_ = CascadingProvider(providers: [])
		}
	}

	@available(Configuration 1.0, *)
	@Test
	func `negative cascade scope floor literal fails`() async {
		await #expect(processExitsWith: .failure) {
			_ = CascadingProvider.CascadeScopeFloor(integerLiteral: -1)
		}
	}
	#endif

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
		#expect(recorder.keys == ["tool.install.limit", "tool.limit"])
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
		#expect(recorder.keys == ["tool.pager"])
	}
}
