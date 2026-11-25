//
// ConfigContent+AsString.swift
// swift-cascading-configuration
//
// Copyright © 2026 Ross Goldberg
// SPDX-License-Identifier: MIT
//

import Configuration

@available(Configuration 1.0, *)
extension ConfigContent {
	/// An error thrown when the content is not a string.
	struct UnwrapError: Error {
		/// The content that is not a string.
		var content: ConfigContent
	}

	/// Returns the string value, or throws an error if the content is not a
	/// string.
	var asString: String {
		get throws(UnwrapError) {
			guard case let .string(value) = self else {
				throw .init(content: self)
			}
			return value
		}
	}
}
