//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

public protocol AmplifyIdentifiableTask {
    associatedtype Request: AmplifyOperationRequest
    var id: UUID { get }
    var request: Request { get }
    var categoryType: CategoryType { get }
    var eventName: HubPayloadEventName { get }
}

public protocol AmplifyResultTask {
    associatedtype Success
    associatedtype Failure: AmplifyError
    typealias TaskResult = Result<Success, Failure>
    var result: TaskResult { get async }
}

public protocol AmplifyValueTask {
    associatedtype Success
    associatedtype Failure: AmplifyError
    var value: Success { get async throws }
}

public protocol AmplifyInProcessTask {
    associatedtype InProcess: Sendable
    var inProcess: AmplifyAsyncSequence<InProcess> { get async }
}

public protocol AmplifySequenceTask {
    associatedtype InProcess: Sendable
    var sequence: AmplifyAsyncSequence<InProcess> { get }
}

public protocol AmplifyThrowingSequenceTask {
    associatedtype InProcess: Sendable
    var sequence: AmplifyAsyncThrowingSequence<InProcess> { get }
}

public protocol AmplifyControlledTask {
    func pause()
    func resume()
    func cancel()
}

public protocol AmplifyHubResultTask {
    associatedtype Request: AmplifyOperationRequest
    associatedtype Success
    associatedtype Failure: AmplifyError

    typealias OperationResult = Result<Success, Failure>
    typealias ResultListener = (OperationResult) -> Void

    func subscribe(resultListener: @escaping ResultListener) -> UnsubscribeToken
    func unsubscribe(_ token: UnsubscribeToken)
    func dispatch(result: OperationResult)
}

public protocol AmplifyHubInProcessTask {
    associatedtype Request: AmplifyOperationRequest
    associatedtype InProcess: Sendable

    typealias InProcessListener = (InProcess) -> Void

    func subscribe(inProcessListener: @escaping InProcessListener) -> UnsubscribeToken
    func unsubscribe(_ token: UnsubscribeToken)
    func dispatch(inProcess: InProcess)
}

// MARK: - Default Implementations -

public extension AmplifyValueTask where Self: AmplifyResultTask {
    var value: Success {
        get async throws {
            try await result.get()
        }
    }
}

public extension AmplifyIdentifiableTask {

    var idFilter: HubFilter {
        let filter: HubFilter = { payload in
            guard let context = payload.context as? AmplifyOperationContext<Request> else {
                return false
            }

            return context.operationId == id
        }

        return filter
    }

}

public extension AmplifyHubResultTask {
    func unsubscribe(_ token: UnsubscribeToken) {
        Amplify.Hub.removeListener(token)
    }
}

public extension AmplifyHubInProcessTask {
    func unsubscribe(_ token: UnsubscribeToken) {
        Amplify.Hub.removeListener(token)
    }
}

public extension AmplifyHubResultTask where Self: AmplifyIdentifiableTask & AmplifyResultTask {

    func subscribe(resultListener: @escaping ResultListener) -> UnsubscribeToken {
        let channel = HubChannel(from: categoryType)

        var unsubscribe: (() -> Void)?
        let resultHubListener: HubListener = { payload in
            guard let result = payload.data as? TaskResult else {
                return
            }
            resultListener(result)
            // Automatically unsubscribe when event is received
            unsubscribe?()
        }
        let token = Amplify.Hub.listen(to: channel,
                                       isIncluded: idFilter,
                                       listener: resultHubListener)
        unsubscribe = {
            Amplify.Hub.removeListener(token)
        }
        return token
    }

    func dispatch(result: TaskResult) {
        let channel = HubChannel(from: categoryType)
        let context = AmplifyOperationContext(operationId: id, request: request)
        let payload = HubPayload(eventName: eventName, context: context, data: result)
        Amplify.Hub.dispatch(to: channel, payload: payload)
    }

}

public extension AmplifyHubInProcessTask where Self: AmplifyIdentifiableTask & AmplifyInProcessTask {

    func subscribe(inProcessListener: @escaping InProcessListener) -> UnsubscribeToken {
        let channel = HubChannel(from: categoryType)

        let inProcessHubListener: HubListener = { payload in
            if let inProcessData = payload.data as? InProcess {
                inProcessListener(inProcessData)
                return
            }
        }
        let token = Amplify.Hub.listen(to: channel,
                                       isIncluded: idFilter,
                                       listener: inProcessHubListener)
        return token
    }

    func dispatch(inProcess: InProcess) {
        let channel = HubChannel(from: categoryType)
        let context = AmplifyOperationContext(operationId: id, request: request)
        let payload = HubPayload(eventName: eventName, context: context, data: inProcess)
        Amplify.Hub.dispatch(to: channel, payload: payload)
    }

}

public extension AmplifyHubInProcessTask where Self: AmplifyIdentifiableTask & AmplifyResultTask & AmplifyInProcessTask {

    func subscribe(inProcessListener: @escaping InProcessListener) -> UnsubscribeToken {
        let channel = HubChannel(from: categoryType)

        var unsubscribe: (() -> Void)?
        let inProcessHubListener: HubListener = { payload in
            if let inProcessData = payload.data as? InProcess {
                inProcessListener(inProcessData)
                return
            }

            // Remove listener if we see a result come through
            if payload.data is TaskResult {
                unsubscribe?()
            }
        }
        let token = Amplify.Hub.listen(to: channel,
                                       isIncluded: idFilter,
                                       listener: inProcessHubListener)
        unsubscribe = {
            Amplify.Hub.removeListener(token)
        }
        return token
    }

}

public extension AmplifyHubInProcessTask where Self: AmplifyIdentifiableTask {

    func subscribe(inProcessListener: @escaping InProcessListener) -> UnsubscribeToken {
        let channel = HubChannel(from: categoryType)
        let filterById = idFilter

        let inProcessHubListener: HubListener = { payload in
            if let inProcessData = payload.data as? InProcess {
                inProcessListener(inProcessData)
                return
            }
        }
        let token = Amplify.Hub.listen(to: channel,
                                       isIncluded: filterById,
                                       listener: inProcessHubListener)
        return token
    }

    func dispatch(inProcess: InProcess) {
        let channel = HubChannel(from: categoryType)
        let context = AmplifyOperationContext(operationId: id, request: request)
        let payload = HubPayload(eventName: eventName, context: context, data: inProcess)
        Amplify.Hub.dispatch(to: channel, payload: payload)
    }
}

public extension AmplifyHubInProcessTask where Self: AmplifyIdentifiableTask & AmplifyResultTask {

    func subscribe(inProcessListener: @escaping InProcessListener) -> UnsubscribeToken {
        let channel = HubChannel(from: categoryType)
        let filterById = idFilter

        var unsubscribe: (() -> Void)?
        let inProcessHubListener: HubListener = { payload in
            if let inProcessData = payload.data as? InProcess {
                inProcessListener(inProcessData)
                return
            }

            // Remove listener if we see a result come through
            if payload.data is TaskResult {
                unsubscribe?()
            }
        }
        let token = Amplify.Hub.listen(to: channel,
                                       isIncluded: filterById,
                                       listener: inProcessHubListener)
        unsubscribe = {
            Amplify.Hub.removeListener(token)
        }
        return token
    }

}
