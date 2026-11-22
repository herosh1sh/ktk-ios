import Foundation
import KeychainAccess

/// Secure storage for credentials using Keychain
public final class KeychainManager {
    public static let shared = KeychainManager()

    private let keychain: Keychain
    private let service = AppConfiguration.keychainService

    private init() {
        self.keychain = Keychain(service: service)
            .accessibility(.whenUnlockedThisDeviceOnly)
            .synchronizable(false)
    }

    // MARK: - Credentials

    /// Save user credentials
    public func saveCredentials(collegeId: String, password: String) throws {
        let credentials = AccountCredentials(
            collegeId: collegeId,
            password: password,
            deviceIdentifier: AppConfiguration.deviceIdentifier
        )

        let data = try JSONEncoder().encode(credentials)
        try keychain.set(data, key: "credentials_\(collegeId)")
    }

    /// Load credentials for a college ID
    public func loadCredentials(collegeId: String) throws -> AccountCredentials? {
        guard let data = try keychain.getData("credentials_\(collegeId)") else {
            return nil
        }
        return try JSONDecoder().decode(AccountCredentials.self, from: data)
    }

    /// Delete credentials for a college ID
    public func deleteCredentials(collegeId: String) throws {
        try keychain.remove("credentials_\(collegeId)")
    }

    /// Get all saved college IDs
    public func getSavedCollegeIds() -> [String] {
        do {
            let allKeys = try keychain.allKeys()
            return allKeys
                .filter { $0.hasPrefix("credentials_") }
                .map { String($0.dropFirst("credentials_".count)) }
        } catch {
            return []
        }
    }

    // MARK: - Session Record

    /// Save session record for auto-login
    public func saveSessionRecord(_ record: SessionRecord, for collegeId: String) throws {
        let data = try JSONEncoder().encode(record)
        try keychain.set(data, key: "session_\(collegeId)")
    }

    /// Load session record
    public func loadSessionRecord(for collegeId: String) throws -> SessionRecord? {
        guard let data = try keychain.getData("session_\(collegeId)") else {
            return nil
        }
        return try JSONDecoder().decode(SessionRecord.self, from: data)
    }

    /// Delete session record
    public func deleteSessionRecord(for collegeId: String) throws {
        try keychain.remove("session_\(collegeId)")
    }

    // MARK: - Generic Storage

    /// Save any codable object
    public func save<T: Codable>(_ object: T, forKey key: String) throws {
        let data = try JSONEncoder().encode(object)
        try keychain.set(data, key: key)
    }

    /// Load any codable object
    public func load<T: Codable>(_ type: T.Type, forKey key: String) throws -> T? {
        guard let data = try keychain.getData(key) else { return nil }
        return try JSONDecoder().decode(type, from: data)
    }

    /// Delete object for key
    public func delete(forKey key: String) throws {
        try keychain.remove(key)
    }

    // MARK: - Clear All

    /// Clear all keychain data for this app
    public func clearAll() throws {
        try keychain.removeAll()
    }
}

// MARK: - AccountCredentials Extension

// Import the model
import Foundation

// The AccountCredentials struct is defined in SessionRecord.swift
// This extension adds keychain-specific functionality
extension AccountCredentials {
    /// Keychain key for this credential
    public var keychainKey: String {
        return "credentials_\(collegeId)"
    }
}