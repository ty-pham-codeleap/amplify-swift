//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Amplify
import Foundation

public extension AWSAPIPlugin {

    func get(request: RESTRequest, listener: RESTOperation.ResultListener?) -> RESTOperation {
        let operationRequest = RESTOperationRequest(request: request,
                                                    operationType: .get)

        let operation = AWSRESTOperation(request: operationRequest,
                                         session: session,
                                         mapper: mapper,
                                         pluginConfig: pluginConfig,
                                         resultListener: listener)

        queue.addOperation(operation)
        return operation
    }
    
    func get(request: RESTRequest) async throws -> RESTOperationTask.Success {
        try await withCheckedThrowingContinuation { continuation in
            _ = get(request: request) { listener in
                continuation.resume(with: listener)
            }
        }
    }

    func put(request: RESTRequest, listener: RESTOperation.ResultListener?) -> RESTOperation {
        let operationRequest = RESTOperationRequest(request: request,
                                                    operationType: .put)

        let operation = AWSRESTOperation(request: operationRequest,
                                         session: session,
                                         mapper: mapper,
                                         pluginConfig: pluginConfig,
                                         resultListener: listener)

        queue.addOperation(operation)
        return operation
    }
    
    func put(request: RESTRequest) async throws -> RESTOperationTask.Success {
        try await withCheckedThrowingContinuation { continuation in
            _ = put(request: request) { listener in
                continuation.resume(with: listener)
            }
        }
    }

    func post(request: RESTRequest, listener: RESTOperation.ResultListener?) -> RESTOperation {
        let operationRequest = RESTOperationRequest(request: request,
                                                    operationType: .post)

        let operation = AWSRESTOperation(request: operationRequest,
                                         session: session,
                                         mapper: mapper,
                                         pluginConfig: pluginConfig,
                                         resultListener: listener)

        queue.addOperation(operation)
        return operation
    }
    
    func post(request: RESTRequest) async throws -> RESTOperationTask.Success {
        try await withCheckedThrowingContinuation { continuation in
            _ = post(request: request) { listener in
                continuation.resume(with: listener)
            }
        }
    }

    func patch(request: RESTRequest, listener: RESTOperation.ResultListener?) -> RESTOperation {
        let operationRequest = RESTOperationRequest(request: request, operationType: .patch)

        let operation = AWSRESTOperation(request: operationRequest,
                                         session: session,
                                         mapper: mapper,
                                         pluginConfig: pluginConfig,
                                         resultListener: listener)

        queue.addOperation(operation)
        return operation
    }
    
    func patch(request: RESTRequest) async throws -> RESTOperationTask.Success {
        try await withCheckedThrowingContinuation { continuation in
            _ = patch(request: request) { listener in
                continuation.resume(with: listener)
            }
        }
    }

    func delete(request: RESTRequest, listener: RESTOperation.ResultListener?) -> RESTOperation {
        let operationRequest = RESTOperationRequest(request: request,
                                                    operationType: .delete)

        let operation = AWSRESTOperation(request: operationRequest,
                                         session: session,
                                         mapper: mapper,
                                         pluginConfig: pluginConfig,
                                         resultListener: listener)

        queue.addOperation(operation)
        return operation
    }
    
    func delete(request: RESTRequest) async throws -> RESTOperationTask.Success {
        try await withCheckedThrowingContinuation { continuation in
            _ = delete(request: request) { listener in
                continuation.resume(with: listener)
            }
        }
    }

    func head(request: RESTRequest, listener: RESTOperation.ResultListener?) -> RESTOperation {
        let operationRequest = RESTOperationRequest(request: request,
                                                    operationType: .head)

        let operation = AWSRESTOperation(request: operationRequest,
                                         session: session,
                                         mapper: mapper,
                                         pluginConfig: pluginConfig,
                                         resultListener: listener)

        queue.addOperation(operation)
        return operation
    }
    
    func head(request: RESTRequest) async throws -> RESTOperationTask.Success {
        try await withCheckedThrowingContinuation { continuation in
            _ = head(request: request) { listener in
                continuation.resume(with: listener)
            }
        }
    }
}
