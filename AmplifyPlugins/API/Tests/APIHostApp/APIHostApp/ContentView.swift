//
//  ContentView.swift
//  APIHostApp
//
//  Created by Law, Michael on 7/21/22.
//

import SwiftUI
import Amplify
import AWSAPIPlugin
import AWSPluginsCore

struct DoubleGenerator<R: Decodable>: AsyncSequence, AsyncIteratorProtocol {
    typealias Element = Int
    var current = 1

    mutating func next() async -> Element? {
        defer { current &*= 2 }

        if current < 0 {
            return nil
        } else {
            return current
        }
    }

    func makeAsyncIterator() -> DoubleGenerator {
        self
    }
}

/*
 class ContentViewModel: ObservableObject {
   @Published var todos = [Todo]()
   var operation: AmplifyInProcessReportingOperaton? = nil
   
   func subscribe() {
     operation = Amplify.API.subscribe(request: .subscription(of: Todo.self, type: .onCreate))
     // How do I achieve data pushed to the app?
     Task {
         for try await element in operation.sequence {
             switch element {
             case .inProcess(let subscriptionEvent):
                 print("Progress: \(subscriptionEvent)")
                 // https://docs.amplify.aws/lib/graphqlapi/subscribe-data/q/platform/ios/
                 switch subscriptionEvent {
                 case .connection(let subscriptionConnectionState):
                     print("Subscription connect state is \(subscriptionConnectionState)")
                 case .data(let result):
                     switch result {
                     case .success(let createdTodo):
                         print("Successfully got todo from subscription: \(createdTodo)")

                         DispatchQueue.main.async {
                              self.todos.append(createdTodo)
                         }
                     case .failure(let error):
                         print("Got failed result with \(error.errorDescription)")
                     }
                 }
             case .success(let success):
                 print("Success: \(success)")
             case .failure(let error):
                 print("Error: \(error)")
             }
         }
     }
   }
 }
 */

class ContentViewModel: ObservableObject {
    
    let apiPlugin: AWSAPIPlugin
    init() {
        apiPlugin = AWSAPIPlugin()
    }
    
    func apiSubscribe<R: Decodable>(_ modelType: R.Type) async throws -> DoubleGenerator<R> {
        DoubleGenerator()
    }
    func subscribe() async {
        do {
//            let operation = try await apiPlugin.subscribe(request:
//                    .subscription(of: Todo.self,
//                                  type: .onCreate))
            
            let sequence = try await apiSubscribe(Todo.self)
            
            // operation.sequence
            for await number in sequence {
                print(number)
            }

        } catch {
            print("Failed to subscribe error: \(error)")
        }
    }
}

struct ContentView: View {
    @StateObject var vm = ContentViewModel()
    
    var body: some View {
        if #available(iOS 15.0, *) {
            VStack {
                
            }.task { await vm.subscribe() }
            
        } else {
            // Fallback on earlier versions
            Text("task is on iOS 15.0")
        }
        
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}



public struct Todo: Model {
    public let id: String
    public var name: String
    public var description: String?

    public init(id: String = UUID().uuidString,
                name: String,
                description: String? = nil) {
        self.id = id
        self.name = name
        self.description = description
    }
}

extension Todo {
  // MARK: - CodingKeys
   public enum CodingKeys: String, ModelKey {
    case id
    case name
    case description
  }

  public static let keys = CodingKeys.self
  //  MARK: - ModelSchema

  public static let schema = defineSchema { model in
    let todo = Todo.keys

    model.listPluralName = "Todos"
    model.syncPluralName = "Todos"

    model.fields(
      .id(),
      .field(todo.name, is: .required, ofType: .string),
      .field(todo.description, is: .optional, ofType: .string))
    }
}
