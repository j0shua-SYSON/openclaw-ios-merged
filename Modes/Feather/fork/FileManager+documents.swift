//
//  FileManager+documents.swift
//  Feather
//
//  OpenClaw mode isolation overlay: routes Feather's Documents footprint under
//  Documents/Feather/ so it never collides with the host or other modes in the
//  Files app. Replaces Feather's original (which built these off
//  URL.documentsDirectory directly). Keeps the exact same public API.
//

import Foundation.NSFileManager

extension FileManager {
	/// Base directory for all of Feather's user-visible storage (isolated per mode).
	private var _featherBase: URL {
		let base = URL.documentsDirectory.appendingPathComponent("Feather", isDirectory: true)
		try? createDirectory(at: base, withIntermediateDirectories: true)
		return base
	}

	/// Gives apps Signed directory
	var archives: URL {
		_featherBase.appendingPathComponent("Archives")
	}

	/// Gives apps Signed directory
	var signed: URL {
		_featherBase.appendingPathComponent("Signed")
	}

	/// Gives apps Signed directory with a UUID appending path
	func signed(_ uuid: String) -> URL {
		signed.appendingPathComponent(uuid)
	}

	/// Gives apps Unsigned directory
	var unsigned: URL {
		_featherBase.appendingPathComponent("Unsigned")
	}

	/// Gives apps Unsigned directory with a UUID appending path
	func unsigned(_ uuid: String) -> URL {
		unsigned.appendingPathComponent(uuid)
	}

	/// Gives apps Certificates directory
	var certificates: URL {
		_featherBase.appendingPathComponent("Certificates")
	}

	/// Gives apps Certificates directory with a UUID appending path
	func certificates(_ uuid: String) -> URL {
		certificates.appendingPathComponent(uuid)
	}
}
