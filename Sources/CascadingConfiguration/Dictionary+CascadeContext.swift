//
// Dictionary+CascadeContext.swift
// swift-cascading-configuration
//
// Copyright © 2026 Ross Goldberg
// SPDX-License-Identifier: MIT
//

public import Configuration

/// The functions that set the cascade context (which only ``CascadingProvider``
/// reads) of a key context.
///
/// Each static function creates a key context that holds only its entries,
/// while each instance method returns a copy of a key context, with its entries
/// replacing any that the context holds, so that calls chain:
///
/// ```swift
/// // Looks up only GIT_A_PAGER in an environment provider whose base scope is ["tool"]
/// config.string(forKey: .init("a.pager", context: .cascadeScopeFloor(1).baseScope(["git"])))
/// ```
@available(Configuration 1.0, *)
public extension [String: ConfigContextValue] {
	/// Returns a key context whose cascade scope floor overrides that of every
	/// upstream provider of a ``CascadingProvider``.
	///
	/// ```swift
	/// // Tries "a.b.setting", then "a.setting"
	/// config.string(forKey: .init("a.b.setting", context: .cascadeScopeFloor(1)))
	/// ```
	///
	/// - Parameter floor: The minimum number of scopes, not counting base scopes,
	///   that a key tried by the cascade keeps.
	/// - Returns: A key context that holds only `floor`.
	static func cascadeScopeFloor(_ floor: CascadingProvider.CascadeScopeFloor) -> Self {
		.init().cascadeScopeFloor(floor)
	}

	/// Returns a key context whose base scope cascade scope floor overrides that
	/// of every upstream provider of a ``CascadingProvider`` whose base scope is
	/// not empty.
	///
	/// ```swift
	/// // Tries TOOL_PAGER, then PAGER, in an environment provider whose base scope is ["tool"]
	/// config.string(forKey: .init("pager", context: .baseScopeCascadeScopeFloor(0)))
	/// ```
	///
	/// - Parameter floor: The minimum number of base scopes that a key tried by
	///   the cascade keeps, if its cascade scope floor is `0`.
	/// - Returns: A key context that holds only `floor`.
	static func baseScopeCascadeScopeFloor(_ floor: CascadingProvider.CascadeScopeFloor) -> Self {
		.init().baseScopeCascadeScopeFloor(floor)
	}

	/// Returns a key context whose base scope overrides that of upstream
	/// providers of a ``CascadingProvider``.
	///
	/// An empty base scope removes the base scope of every upstream provider,
	/// while any other base scope replaces each base scope that is not empty:
	///
	/// ```swift
	/// // Looks up only PAGER, even in an environment provider whose base scope is ["tool"]
	/// config.string(forKey: .init("pager", context: .baseScope([])))
	/// ```
	///
	/// - Parameter baseScope: The base scope of the key.
	/// - Returns: A key context that holds only `baseScope`.
	static func baseScope(_ baseScope: [String]) -> Self {
		.init().baseScope(baseScope)
	}

	/// Returns this key context with a cascade scope floor that overrides that of
	/// every upstream provider of a ``CascadingProvider``.
	///
	/// - Parameter floor: The minimum number of scopes, not counting base scopes,
	///   that a key tried by the cascade keeps.
	/// - Returns: This key context, with `floor` replacing any cascade scope
	///   floor.
	func cascadeScopeFloor(_ floor: CascadingProvider.CascadeScopeFloor) -> Self {
		merging([CascadingProvider.cascadeScopeFloorContextKey: .int(floor.rawValue)]) { $1 }
	}

	/// Returns this key context with a base scope cascade scope floor that
	/// overrides that of every upstream provider of a ``CascadingProvider`` whose
	/// base scope is not empty.
	///
	/// - Parameter floor: The minimum number of base scopes that a key tried by
	///   the cascade keeps, if its cascade scope floor is `0`.
	/// - Returns: This key context, with `floor` replacing any base scope cascade
	///   scope floor.
	func baseScopeCascadeScopeFloor(_ floor: CascadingProvider.CascadeScopeFloor) -> Self {
		merging([CascadingProvider.baseScopeCascadeScopeFloorContextKey: .int(floor.rawValue)]) { $1 }
	}

	/// Returns this key context with a base scope that overrides that of upstream
	/// providers of a ``CascadingProvider``.
	///
	/// An empty base scope removes the base scope of every upstream provider,
	/// while any other base scope replaces each base scope that is not empty.
	///
	/// - Parameter baseScope: The base scope of the key.
	/// - Returns: This key context, with `baseScope` replacing any base scope.
	func baseScope(_ baseScope: [String]) -> Self {
		let prefix = "\(CascadingProvider.baseScopeContextKeyPrefix)."
		return baseScope.enumerated()
			.reduce(into: filter { !$0.key.hasPrefix(prefix) }) { context, element in
				context["\(prefix)\(element.offset)"] = .string(element.element)
			}
			.merging(["\(prefix)count": .int(baseScope.count)]) { $1 }
	}
}
