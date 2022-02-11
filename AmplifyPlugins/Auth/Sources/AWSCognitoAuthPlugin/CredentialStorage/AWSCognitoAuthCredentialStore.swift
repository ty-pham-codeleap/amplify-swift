//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import Amplify

struct AWSCognitoAuthCredentialStore {

    // Credential store constants
    private let service = "com.amplify.credentialStore"
    private let sessionKey = "session"
    
    // User defaults constants
    private let isKeychainConfiguredKey = "isKeychainConfigured"
    private let storedNamespaceKey = "storedNamespace"
    
    private let authConfiguration: AuthConfiguration
    private let keychain: CredentialStoreBehavior
    private let userDefaults = UserDefaults.standard

    init(authConfiguration: AuthConfiguration, accessGroup: String? = nil) {
        self.authConfiguration = authConfiguration
        self.keychain = CredentialStore(service: service, accessGroup: accessGroup)
        
        if !self.userDefaults.bool(forKey: isKeychainConfiguredKey) {
            try? self.clearAllCredentials()
            self.userDefaults.set(true, forKey: isKeychainConfiguredKey)
        }
        
        restoreCredentialsOnConfigurationChanges()
        
        // Set the namespace in the user defaults
        self.userDefaults.set(generateSessionKey(), forKey: storedNamespaceKey)
    }
    
    // The method is responsible for migrating any old credentials to the new namespace
    private func restoreCredentialsOnConfigurationChanges() {
        guard let oldNamespace = self.userDefaults.string(forKey: storedNamespaceKey) else {
            return
        }
        let newNamespace = generateSessionKey()
        
        if oldNamespace != newNamespace {
            // retrieve data from the old namespace
            let oldCognitoCredentialsData = try? self.keychain.getData(oldNamespace)
            
            // Clear the old credentials
            try? self.keychain.remove(oldNamespace)
            
            // Save with the new namespace
            if let oldCognitoCredentialsData = oldCognitoCredentialsData {
                try? self.keychain.set(oldCognitoCredentialsData, key: newNamespace)
            }
        }
        
    }

    private func storeKey() -> String {
        let prefix = "amplify"
        var suffix = ""

        switch authConfiguration {
        case .userPools(let userPoolConfigurationData):
            suffix = userPoolConfigurationData.poolId
        case .identityPools(let identityPoolConfigurationData):
            suffix = identityPoolConfigurationData.poolId
        case .userPoolsAndIdentityPools(let userPoolConfigurationData, let identityPoolConfigurationData):
            suffix = "\(userPoolConfigurationData.poolId).\(identityPoolConfigurationData.poolId)"
        }

        return "\(prefix).\(suffix)"
    }

    private func generateSessionKey() -> String {
        return "\(storeKey()).\(sessionKey)"
    }

}

extension AWSCognitoAuthCredentialStore: AmplifyAuthCredentialStoreBehavior {

    func saveCredential(_ credential: CognitoCredentials) throws {

        let authCredentialStoreKey = generateSessionKey()
        let encodedCredentials = try encode(object: credential)
        try keychain.set(encodedCredentials, key: authCredentialStoreKey)
    }

    func retrieveCredential() throws -> CognitoCredentials {
        let authCredentialStoreKey = generateSessionKey()
        let authCredentialData = try keychain.getData(authCredentialStoreKey)
        let awsCredential: CognitoCredentials = try decode(data: authCredentialData)
        return awsCredential
    }

    func deleteCredential() throws {
        let authCredentialStoreKey = generateSessionKey()
        try keychain.remove(authCredentialStoreKey)
    }

    private func clearAllCredentials() throws {
        try keychain.removeAll()
    }

}

extension AWSCognitoAuthCredentialStore: AmplifyAuthCredentialStoreProvider {

    func getCredentialStore() -> CredentialStoreBehavior {
        return keychain
    }

}

/// Helpers for encode and decoding
private extension AWSCognitoAuthCredentialStore {

    func encode<T: Codable>(object: T) throws -> Data {
        do {
            return try JSONEncoder().encode(object)
        } catch {
            throw CredentialStoreError.codingError("Error occurred while encoding AWSCredentials", error)
        }
    }

    func decode<T: Decodable>(data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw CredentialStoreError.codingError("Error occurred while decoding AWSCredentials", error)
        }
    }

}