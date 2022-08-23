//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
#if canImport(Combine)
import Combine
#endif

@testable import Amplify
@testable import AmplifyTestCommon

class AmplifyTaskTests: XCTestCase {
    let queue = OperationQueue()

    func testFastOperation() async throws {
        let input = [1, 2, 3]
        var output: Int = 0
        var thrown: Error? = nil

        do {
            let request = FastOperationRequest(numbers: input)
            let result = try await runFastOperation(request: request)
            output = result.value
        } catch {
            thrown = error
        }

        XCTAssertEqual(input.sum(), output)
        XCTAssertNil(thrown)
    }

#if canImport(Combine)
    func testFastOperationWithPublisher() throws {
        let exp1 = expectation(description: "\(#function)-1")
        let exp2 = expectation(description: "\(#function)-2")
        let input = [1, 2, 3]
        var output: Int = 0
        var thrown: Error? = nil

        let request = FastOperationRequest(numbers: input)
        let publisher = runFastOperationWithPublisher(request: request)

        let sink = publisher.sink { completion in
            switch completion {
            case .failure(let error):
                thrown = error
            case .finished:
                exp1.fulfill()
            }
        } receiveValue: { result in
            output = result.value
            exp2.fulfill()
        }
        defer {
            sink.cancel()
        }

        wait(for: [exp1, exp2], timeout: 5.0)

        XCTAssertEqual(input.sum(), output)
        XCTAssertNil(thrown)
    }
#endif

    func testFastCompositeTask() async throws {
        let done = asyncExpectation(description: "done")
        let taskDone = asyncExpectation(description: "task done")
        let listenerDone = asyncExpectation(description: "listener done")

        Task {
            let input = [1, 2, 3]
            let output = input.sum()
            var taskResult: FastCompositeTask.Success?
            var listenerResult: FastCompositeTask.Success?
            var taskThrown: Error? = nil
            var listenerThrown: Error? = nil

            do {
                let request = FastOperationRequest(numbers: input)
                let task = FastCompositeTask(request: request)
                let token: UnsubscribeToken = task.subscribe { (result: FastCompositeTask.OperationResult) in
                    do {
                        listenerResult = try result.get()
                    } catch {
                        listenerThrown = error
                    }
                    Task {
                        await listenerDone.fulfill()
                    }
                }
                taskResult = try await task.value
                await taskDone.fulfill()
                _ = token // supresses warning for not using variable
            } catch {
                taskThrown = error
            }

            await waitForExpectations([taskDone, listenerDone], timeout: 10.0)

            XCTAssertEqual(taskResult?.value, output)
            XCTAssertEqual(listenerResult?.value, output)
            XCTAssertNil(taskThrown)
            XCTAssertNil(listenerThrown)

            await done.fulfill()
        }

        await waitForExpectations([done], timeout: 10.0)
    }

    func testLongOperation() async throws {
        var success = false
        var output: String? = nil
        var thrown: Error? = nil

        let request = LongOperationRequest(steps: 10, delay: 0.01)
        let longTask = await runLongOperation(request: request)

        Task {
            var progressCount = 0
            var lastProgress: Double = 0

            await longTask.progress.forEach { progress in
                lastProgress = progress.fractionCompleted
                progressCount += 1
            }

            XCTAssertEqual(progressCount, 11)
            XCTAssertEqual(lastProgress, 100)
        }

        do {
            let value = try await longTask.value
            output = value.id
            success = true
        } catch {
            thrown = error
        }

        XCTAssertTrue(success)
        XCTAssertNotNil(output)
        XCTAssertFalse(output.isEmpty)
        XCTAssertNil(thrown)
    }

#if canImport(Combine)
    func testLongOperationWithPublishers() async throws {
        let exp1 = expectation(description: "\(#function)-1")
        let exp2 = expectation(description: "\(#function)-2")

        var success = false
        var output: String? = nil
        var thrown: Error? = nil
        var requestID: String? = nil
        var progressCount = 0
        var lastProgress: Double = 0

        let request = LongOperationRequest(steps: 10, delay: 0.01)
        let longTask = await runLongOperation(request: request)

        let progressPublisher = longTask.inProcessPublisher
        let resultPublisher = longTask.resultPublisher

        let progressSink = progressPublisher.sink { completion in
            switch completion {
            case .failure:
                break
            case .finished:
                exp1.fulfill()
            }
        } receiveValue: { progress in
            lastProgress = progress.fractionCompleted
            progressCount += 1
        }
        defer {
            progressSink.cancel()
        }

        let resultSink = resultPublisher.sink { completion in
            switch completion {
            case .failure(let error):
                thrown = error
            case .finished:
                success = true
            }
        } receiveValue: { result in
            output = result.id
            requestID = longTask.requestID
            exp2.fulfill()
        }
        defer {
            resultSink.cancel()
        }

        wait(for: [exp1, exp2], timeout: 10.0)

        XCTAssertGreaterThanOrEqual(progressCount, 10)
        XCTAssertEqual(lastProgress, 1)

        XCTAssertTrue(success)
        XCTAssertNotNil(output)
        XCTAssertFalse(output.isEmpty)
        XCTAssertNil(thrown)
        XCTAssertFalse(requestID.isEmpty)
        XCTAssertEqual(request.requestID, requestID)
    }
#endif

    func testLongCompositeTask() async throws {
        let taskDone = asyncExpectation(description: "task done")
        let listenerDone = asyncExpectation(description: "listener done")

        Task {
            var listenerCount = 0
            var taskCount = 0
            var lastListenerProgress: Double = 0
            var lastTaskProgress: Double = 0
            let request = LongOperationRequest(steps: 10, delay: 0.01)
            let longTask = LongCompositeTask(request: request)

            let token = longTask.subscribe { progress in
                lastListenerProgress = progress
                listenerCount += 1
                if progress == 1.0 {
                    Task {
                        await listenerDone.fulfill()
                        longTask.sequence.finish()
                    }
                }
            }

            await longTask.progress.forEach { progress in
                lastTaskProgress = progress
                taskCount += 1
            }

            XCTAssertEqual(listenerCount, 11)
            XCTAssertEqual(taskCount, 11)
            XCTAssertEqual(lastListenerProgress, 1.0)
            XCTAssertEqual(lastTaskProgress, 1.0)

            longTask.unsubscribe(token)
            await taskDone.fulfill()
        }

        await waitForExpectations([taskDone, listenerDone], timeout: 10.0)
    }

    private func runFastOperation(request: FastOperationRequest) async throws -> FastTask.Success {
        let operation = FastOperation(request: request)
        let taskAdapter = AmplifyOperationTaskAdapter(operation: operation)
        queue.addOperation(operation)
        return try await taskAdapter.value
    }

    private func runLongOperation(request: LongOperationRequest) async -> LongTask {
        let operation = LongOperation(request: request)
        let taskAdapter = AmplifyInProcessReportingOperationTaskAdapter(operation: operation)
        queue.addOperation(operation)
        return taskAdapter
    }

    private func runFastOperationWithPublisher(request: FastOperationRequest) -> FastResultPublisher {
        let operation = FastOperation(request: request)
        let taskAdapter = AmplifyOperationTaskAdapter(operation: operation)
        let resultPublisher = taskAdapter.resultPublisher
        queue.addOperation(operation)
        return resultPublisher
    }

}
