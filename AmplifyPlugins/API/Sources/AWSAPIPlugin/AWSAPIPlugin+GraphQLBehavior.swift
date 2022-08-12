//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Amplify

public extension AWSAPIPlugin {

    func query<R: Decodable>(request: GraphQLRequest<R>,
                             listener: GraphQLOperation<R>.ResultListener?) -> GraphQLOperation<R> {
        let operation = AWSGraphQLOperation(request: request.toOperationRequest(operationType: .query),
                                            session: session,
                                            mapper: mapper,
                                            pluginConfig: pluginConfig,
                                            resultListener: listener)
        queue.addOperation(operation)
        return operation
    }
    
    func query<R: Decodable>(request: GraphQLRequest<R>) async throws -> GraphQLOperationTask<R>.Success {
        try await withCheckedThrowingContinuation { continuation in
            _ = query(request: request) { listener in
                continuation.resume(with: listener)
            }
        }
    }

    func mutate<R: Decodable>(request: GraphQLRequest<R>,
                              listener: GraphQLOperation<R>.ResultListener?) -> GraphQLOperation<R> {
        let operation = AWSGraphQLOperation(request: request.toOperationRequest(operationType: .mutation),
                                            session: session,
                                            mapper: mapper,
                                            pluginConfig: pluginConfig,
                                            resultListener: listener)
        queue.addOperation(operation)
        return operation
    }
    
    func mutate<R: Decodable>(request: GraphQLRequest<R>) async throws -> GraphQLOperationTask<R>.Success {
        try await withCheckedThrowingContinuation { continuation in
            _ = mutate(request: request) { listener in
                continuation.resume(with: listener)
            }
        }
    }

    func subscribe<R>(
        request: GraphQLRequest<R>,
        valueListener: GraphQLSubscriptionOperation<R>.InProcessListener?,
        completionListener: GraphQLSubscriptionOperation<R>.ResultListener?
    ) -> GraphQLSubscriptionOperation<R> {
            let operation = AWSGraphQLSubscriptionOperation(
                request: request.toOperationRequest(operationType: .subscription),
                pluginConfig: pluginConfig,
                subscriptionConnectionFactory: subscriptionConnectionFactory,
                authService: authService,
                apiAuthProviderFactory: authProviderFactory,
                inProcessListener: valueListener,
                resultListener: completionListener)
            queue.addOperation(operation)
            return operation
    }
    
    func subscribe<R>(request: GraphQLRequest<R>) async throws -> GraphQLSubscriptionOperation<R> {
        let operation = AWSGraphQLSubscriptionOperation(
            request: request.toOperationRequest(operationType: .subscription),
            pluginConfig: pluginConfig,
            subscriptionConnectionFactory: subscriptionConnectionFactory,
            authService: authService,
            apiAuthProviderFactory: authProviderFactory,
            inProcessListener: { valueListner in
                print("send to sequence")
            },
            resultListener: { completionListener in
                print("send to sequence")
            }
        )
        queue.addOperation(operation)
        return operation
    }
}
