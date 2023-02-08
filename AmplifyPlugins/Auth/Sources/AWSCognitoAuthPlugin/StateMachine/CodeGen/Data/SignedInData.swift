//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

public struct SignedInData {
    let userId: String
    let username: String
    let signedInDate: Date
    let signInMethod: SignInMethod
    let deviceMetadata: DeviceMetadata
    public let cognitoUserPoolTokens: AWSCognitoUserPoolTokens

    public init(userId: String,
         username: String,
         signedInDate: Date,
         cognitoUserPoolTokens: AWSCognitoUserPoolTokens
    ) {
        self.userId = userId
        self.username = username
        self.signedInDate = signedInDate
        self.signInMethod = .apiBased(.userSRP)
        self.deviceMetadata = DeviceMetadata.noData
        self.cognitoUserPoolTokens = cognitoUserPoolTokens
    }

    init(signedInDate: Date,
         signInMethod: SignInMethod,
         deviceMetadata: DeviceMetadata = .noData,
         cognitoUserPoolTokens: AWSCognitoUserPoolTokens
    ) {
        let user = try? TokenParserHelper.getAuthUser(accessToken: cognitoUserPoolTokens.accessToken)
        self.userId = user?.userId ?? "unknown"
        self.username = user?.username ?? "unknown"
        self.signedInDate = signedInDate
        self.signInMethod = signInMethod
        self.deviceMetadata = deviceMetadata
        self.cognitoUserPoolTokens = cognitoUserPoolTokens
    }
}

extension SignedInData: Codable { }

extension SignedInData: Equatable { }

extension SignedInData: CustomDebugDictionaryConvertible {
    var debugDictionary: [String: Any] {
        [
            "userId": userId.masked(),
            "userName": username.masked(),
            "signedInDate": signedInDate,
            "signInMethod": signInMethod,
            "deviceMetadata": deviceMetadata,
            "tokens": cognitoUserPoolTokens
        ]
    }
}

extension SignedInData: CustomDebugStringConvertible {
    public var debugDescription: String {
        debugDictionary.debugDescription
    }
}
