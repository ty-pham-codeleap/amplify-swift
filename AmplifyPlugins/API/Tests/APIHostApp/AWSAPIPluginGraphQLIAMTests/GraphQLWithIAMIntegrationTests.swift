//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
import AWSAPIPlugin
import AWSCognitoAuthPlugin

@testable import Amplify
@testable import APIHostApp
import Combine

class GraphQLWithIAMIntegrationTests: XCTestCase {

    let amplifyConfigurationFile = "testconfiguration/GraphQLWithIAMIntegrationTests-amplifyconfiguration"

    let username = "integTest\(UUID().uuidString)"
    let password = "P123@\(UUID().uuidString)"

    override func setUp() async throws {
        do {
            Amplify.Logging.logLevel = .verbose
            try Amplify.add(plugin: AWSAPIPlugin())
            try Amplify.add(plugin: AWSCognitoAuthPlugin())
            let amplifyConfig = try TestConfigHelper.retrieveAmplifyConfiguration(forResource: amplifyConfigurationFile)
            try Amplify.configure(amplifyConfig)

            ModelRegistry.register(modelType: Todo.self)
        } catch {
            XCTFail("Error during setup: \(error)")
        }
        
    }

    override func tearDown() async throws {
        if await isSignedIn() {
            await signOut()
        }
        await Amplify.reset()
    }
        
    func testSignUserOut() async {
        if await isSignedIn() {
            print("User is signed in")
        }

        await signOut()
    }
    
    func createTodoTest() async {
        let completeInvoked = expectation(description: "request completed")

        let expectedId = UUID().uuidString
        let expectedName = "testCreateTodoMutationName"
        let expectedDescription = "testCreateTodoMutationDescription"
        let request = GraphQLRequest(document: CreateTodoMutation.document,
                                     variables: CreateTodoMutation.variables(id: expectedId,
                                                                             name: expectedName,
                                                                             description: expectedDescription),
                                     responseType: CreateTodoMutation.Data.self)
        do {
            let result = try await Amplify.API.mutate(request: request)
            XCTAssertNotNil(result)
            switch result {
            case .success(let data):
                guard let todo = data.createTodo else {
                    XCTFail("Missing Todo")
                    return
                }

                XCTAssertEqual(todo.id, expectedId)
                XCTAssertEqual(todo.name, expectedName)
                XCTAssertEqual(todo.description, expectedDescription)
                XCTAssertEqual(todo.typename, String(describing: Todo.self))

                completeInvoked.fulfill()
            case .failure(let error):
                XCTFail("Unexpected .failed event: \(error)")
            }
        } catch {
            XCTFail("Unexpected .failed event: \(error)")
        }
        await waitForExpectations(timeout: TestCommonConstants.networkTimeout)
    }

    /// A subscription to onCreate todo should receive an event for each create Todo mutation API called. User is not signed in
    ///
    /// - Given:  An onCreate Todo subscription established
    /// - When:
    ///    - Create todo mutations API called
    /// - Then:
    ///    - The subscription should receive mutation events corresponding to the API calls performed.
    ///
    func testOnCreateTodoUnauthRole() async {
        if await isSignedIn() {
            await signOut()
        }
        await onCreateTodoTest()
    }
    
    /// A subscription to onCreate todo should receive an event for each create Todo mutation API called
    ///
    /// - Given:  An onCreate Todo subscription established
    /// - When:
    ///    - Create todo mutations API called
    /// - Then:
    ///    - The subscription should receive mutation events corresponding to the API calls performed.
    ///
    func testOnCreateTodoAuthRole() async {
        await createAuthenticatedUser()
        await onCreateTodoTest()
    }
    
    func onCreateTodoTest() async {
        let connectedInvoked = expectation(description: "Connection established")
        var onValueHandler: GraphQLSubscriptionOperation<Todo>.InProcessListener = { event in
            switch event {
            case .connection(let state):
                switch state {
                case .connecting, .disconnected:
                    break
                case .connected:
                    connectedInvoked.fulfill()
                }
            case .data:
                break
            }
        }
        
        var onCompleteHandler: (Subscribers.Completion<Error>) -> Void = { event in
            switch event {
            case .failure(let error):
                XCTFail("Unexpected .failed event: \(error)")
            case .finished:
                connectedInvoked.fulfill()
            }
        }
        let subscription = Amplify.API.subscribe(request: .subscription(of: Todo.self, type: .onCreate))
        let sink = Amplify.Publisher.create(subscription)
            .sink(receiveCompletion: { onCompleteHandler($0) },
                  receiveValue: { onValueHandler($0) })
        
        XCTAssertNotNil(sink)
        await waitForExpectations(timeout: TestCommonConstants.networkTimeout)

        let progressInvoked = expectation(description: "progress invoked")
        progressInvoked.expectedFulfillmentCount = 2
        let uuid = UUID().uuidString
        let uuid2 = UUID().uuidString
        let name = String("\(#function)".dropLast(2))
        onValueHandler = { event in
            switch event {
            case .connection:
                break
            case .data(let result):
                switch result {
                case .success(let todo):
                    if todo.id == uuid || todo.id == uuid2 {
                        progressInvoked.fulfill()
                    }
                case .failure(let error):
                    XCTFail("\(error)")
                }
            }
        }
        let createdTodo1 = expectation(description: "created todo")
        let createdTodo2 = expectation(description: "created todo")
        let _ = await createTodo(id: uuid, name: name, expect: createdTodo1)
        let _ = await createTodo(id: uuid2, name: name, expect: createdTodo2)
        await waitForExpectations(timeout: TestCommonConstants.networkTimeout)

        let disconnectedInvoked = expectation(description: "Connection disconnected")
        let completedInvoked = expectation(description: "Completed invoked")
        onValueHandler = { event in
            switch event {
            case .connection(let state):
                switch state {
                case .connecting, .connected:
                    break
                case .disconnected:
                    disconnectedInvoked.fulfill()
                }
            case .data:
                break
            }
        }
        onCompleteHandler = { event in
            switch event {
            case .failure(let error):
                XCTFail("Unexpected .failed event: \(error)")
            case .finished:
                completedInvoked.fulfill()
            }
        }
        subscription.cancel()
        await waitForExpectations(timeout: TestCommonConstants.networkTimeout)
    }

    // MARK: - Helpers
    
    func createTodo(id: String, name: String, expect: XCTestExpectation? = nil) async -> Todo? {
        
        let todo = Todo(id: id, name: name)
        var result: Todo?
        let requestInvokedSuccessfully = expect ?? expectation(description: "request completed")

        do {
            let apiResult = try await Amplify.API.mutate(request: .create(todo))
            switch apiResult {
            case .success(let post):
                result = post
            default:
                XCTFail("Create Post was not successful: \(apiResult)")
            }
            requestInvokedSuccessfully.fulfill()
        } catch {
            XCTFail("Failed with error: \(error)")
        }
        
        if expect == nil {
            await waitForExpectations(timeout: TestCommonConstants.networkTimeout)
        }
        return result
    }

    // MARK: - Auth Helpers
    
    func createAuthenticatedUser() async {
        if await isSignedIn() {
            await signOut()
        }
        await signUp()
        await signIn()
    }
    
    func isSignedIn() async -> Bool {
        let checkIsSignedInCompleted = expectation(description: "retrieve auth session completed")
        var resultOptional: Bool?
        do {
            let authSession = try await Amplify.Auth.fetchAuthSession()
            resultOptional = authSession.isSignedIn
            checkIsSignedInCompleted.fulfill()
        } catch {
            fatalError("Failed to get auth session \(error)")
        }
        
        await waitForExpectations(timeout: 100)
        guard let result = resultOptional else {
            fatalError("Could not get isSignedIn for user")
        }

        return result
    }
    
    func signUp() async {
        let signUpSuccess = expectation(description: "sign up success")
        do {
            let signUpResult = try await Amplify.Auth.signUp(username: username, password: password)
            if signUpResult.isSignUpComplete {
                signUpSuccess.fulfill()
            } else {
                XCTFail("Sign up successful but not complete")
            }
        } catch {
            XCTFail("Failed to sign up \(error)")
        }

        await waitForExpectations(timeout: 100)
    }

    
    func signIn() async {
        let signInSuccess = expectation(description: "sign in success")
        do {
            let signInResult = try await Amplify.Auth.signIn(username: username,
                                    password: password)
            if signInResult.isSignedIn {
                signInSuccess.fulfill()
            } else {
                XCTFail("Sign in successful but not complete")
            }
        } catch {
            XCTFail("Failed to sign in \(error)")
        }
        
        await waitForExpectations(timeout: 100)
    }
    
    func signOut() async {
        let signOutCompleted = expectation(description: "sign out completed")
        let _ = await Amplify.Auth.signOut()
        signOutCompleted.fulfill()
        await waitForExpectations(timeout: 100)
    }

    // MARK: - Model

    struct Todo: Model {
        public let id: String
        public var name: String
        public var description: String?

        init(id: String = UUID().uuidString,
             name: String,
             description: String? = nil) {
            self.id = id
            self.name = name
            self.description = description
        }

        enum CodingKeys: String, ModelKey {
            case id
            case name
            case description
        }

        static let keys = CodingKeys.self

        static let schema = defineSchema { model in
            let todo = Todo.keys

            model.listPluralName = "Todos"
            model.syncPluralName = "Todos"

            model.fields(
                .id(),
                .field(todo.name, is: .required, ofType: .string),
                .field(todo.description, is: .optional, ofType: .string)
            )
        }
    }
}
