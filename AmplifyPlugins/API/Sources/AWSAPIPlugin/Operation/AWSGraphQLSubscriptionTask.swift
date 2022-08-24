//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Amplify
import Foundation
import AWSPluginsCore
import AppSyncRealTimeClient

final public class AWSGraphQLSubscriptionTask<R: Decodable> {

    public typealias Request = GraphQLOperationRequest<R>
    public typealias InProcess = SubscriptionEvent<GraphQLResponse<R>>
    public typealias Failure = APIError

    let request: Request
    let pluginConfig: AWSAPICategoryPluginConfiguration
    let subscriptionConnectionFactory: SubscriptionConnectionFactory
    let authService: AWSAuthServiceBehavior

    var subscriptionConnection: SubscriptionConnection?
    var subscriptionItem: SubscriptionItem?
    var apiAuthProviderFactory: APIAuthProviderFactory

    private let subscriptionQueue = DispatchQueue(label: "AWSGraphQLSubscriptionOperation.subscriptionQueue")

    private var channel: AmplifyAsyncThrowingSequence<InProcess>?
    private var task: Task<Void, Error>?

    init(request: GraphQLOperationRequest<R>,
         pluginConfig: AWSAPICategoryPluginConfiguration,
         subscriptionConnectionFactory: SubscriptionConnectionFactory,
         authService: AWSAuthServiceBehavior,
         apiAuthProviderFactory: APIAuthProviderFactory) {

        self.request = request
        self.pluginConfig = pluginConfig
        self.subscriptionConnectionFactory = subscriptionConnectionFactory
        self.authService = authService
        self.apiAuthProviderFactory = apiAuthProviderFactory
    }

    func createSequence() -> AmplifyAsyncThrowingSequence<InProcess> {
        task = Task { [unowned self] in
            try await withTaskCancellationHandler {
                try await self.run()
            } onCancel: {
                self.cancel()
            }
        }

        let sequence = AmplifyAsyncThrowingSequence<InProcess>(parent: task)
        channel = sequence
        return sequence
    }

    private func send(_ subscriptionEvent: InProcess) {
        channel?.send(subscriptionEvent)
    }

    private func fail(error: Failure) {
        channel?.fail(error)
    }

    private func finish() {
        channel?.finish()
    }

    private func connect(endpointConfig: AWSAPICategoryPluginConfiguration.EndpointConfig,
                         pluginOptions: AWSPluginOptions?) {
        subscriptionQueue.sync {
            do {
                subscriptionConnection = try subscriptionConnectionFactory
                    .getOrCreateConnection(for: endpointConfig,
                                           authService: authService,
                                           authType: pluginOptions?.authType,
                                           apiAuthProviderFactory: apiAuthProviderFactory)
            } catch {
                let error = APIError.operationError("Unable to get connection for api \(endpointConfig.name)", "", error)
                fail(error: error)
                finish()
                return
            }

            // Create subscription
            subscriptionItem = subscriptionConnection?.subscribe(requestString: request.document,
                                                                 variables: request.variables,
                                                                 eventHandler: { [weak self] event, _ in
                self?.onAsyncSubscriptionEvent(event: event)
            })
        }
    }

    private func disconnect() {
        subscriptionQueue.sync {
            if let subscriptionItem = subscriptionItem, let subscriptionConnection = subscriptionConnection {
                subscriptionConnection.unsubscribe(item: subscriptionItem)
                let subscriptionEvent = SubscriptionEvent<GraphQLResponse<R>>.connection(.disconnected)
                send(subscriptionEvent)
            }
        }
    }

    public func cancel() {
        disconnect()
        finish()
    }

    public func run() async throws {
        try Task.checkCancellation()

        // Validate the request
        do {
            try request.validate()
        } catch let error as APIError {
            fail(error: error)
            finish()
            return
        } catch {
            let error = APIError.unknown("Could not validate request", "", nil)
            fail(error: error)
            finish()
            return
        }

        // Retrieve endpoint configuration
        let endpointConfig: AWSAPICategoryPluginConfiguration.EndpointConfig
        do {
            endpointConfig = try pluginConfig.endpoints.getConfig(for: request.apiName, endpointType: .graphQL)
        } catch let error as APIError {
            fail(error: error)
            finish()
            return
        } catch {
            let error = APIError.unknown("Could not get endpoint configuration", "", nil)
            fail(error: error)
            finish()
            return
        }

        // Retrieve request plugin option and
        // auth type in case of a multi-auth setup
        let pluginOptions = request.options.pluginOptions as? AWSPluginOptions

        // Retrieve the subscription connection
        connect(endpointConfig: endpointConfig, pluginOptions: pluginOptions)
    }

    private func onAsyncSubscriptionEvent(event: SubscriptionItemEvent) {
        switch event {
        case .connection(let subscriptionConnectionEvent):
            onSubscriptionEvent(subscriptionConnectionEvent)
        case .data(let data):
            onGraphQLResponseData(data)
        case .failed(let error):
            onSubscriptionFailure(error)
        }
    }

    private func onSubscriptionEvent(_ subscriptionConnectionEvent: SubscriptionConnectionEvent) {
        switch subscriptionConnectionEvent {
        case .connecting:
            let subscriptionEvent = SubscriptionEvent<GraphQLResponse<R>>.connection(.connecting)
            send(subscriptionEvent)
        case .connected:
            let subscriptionEvent = SubscriptionEvent<GraphQLResponse<R>>.connection(.connected)
            send(subscriptionEvent)
        case .disconnected:
            let subscriptionEvent = SubscriptionEvent<GraphQLResponse<R>>.connection(.disconnected)
            send(subscriptionEvent)
            finish()
        }
    }

    private func onSubscriptionConnectionState(_ subscriptionConnectionState: SubscriptionConnectionState) {
        let subscriptionEvent = SubscriptionEvent<GraphQLResponse<R>>.connection(subscriptionConnectionState)
        send(subscriptionEvent)

        if case .disconnected = subscriptionConnectionState {
            finish()
        }
    }

    private func onGraphQLResponseData(_ graphQLResponseData: Data) {
        do {
            let graphQLResponseDecoder = GraphQLResponseDecoder(request: request, response: graphQLResponseData)
            let graphQLResponse = try graphQLResponseDecoder.decodeToGraphQLResponse()
            send(.data(graphQLResponse))
        } catch let error as APIError {
            fail(error: error)
            finish()
        } catch {
            // TODO: Verify with the team that terminating a subscription after failing to decode/cast one
            // payload is the right thing to do. Another option would be to propagate a GraphQL error, but
            // leave the subscription alive.
            let error = APIError.operationError("Failed to deserialize", "", error)
            fail(error: error)
            finish()
        }
    }

    private func onSubscriptionFailure(_ error: Error) {
        var errorDescription = "Subscription item event failed with error"
        if case let ConnectionProviderError.subscription(_, payload) = error,
           let errors = payload?["errors"] as? AppSyncJSONValue,
           let graphQLErrors = try? GraphQLErrorDecoder.decodeAppSyncErrors(errors) {

            if graphQLErrors.hasUnauthorizedError() {
                errorDescription += ": \(APIError.UnauthorizedMessageString)"
            }

            let graphQLResponseError = GraphQLResponseError<R>.error(graphQLErrors)
            let error = APIError.operationError(errorDescription, "", graphQLResponseError)
            fail(error: error)
            finish()
            return
        } else if case ConnectionProviderError.unauthorized = error {
            errorDescription += ": \(APIError.UnauthorizedMessageString)"
        }

        let error = APIError.operationError(errorDescription, "", error)
        fail(error: error)
        finish()
    }
}

//extension Array where Element == GraphQLError {
//    func hasUnauthorizedError() -> Bool {
//        contains { graphQLError in
//            if case let .string(errorTypeValue) = graphQLError.extensions?["errorType"],
//               case .unauthorized = AppSyncErrorType(errorTypeValue) {
//                return true
//            }
//            return false
//        }
//    }
//}
