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

class ContentViewModel: ObservableObject {
    
    let apiPlugin: AWSAPIPlugin
    init() {
        apiPlugin = AWSAPIPlugin()
    }
    
    func subscribe() async {
        do {
            let operation = try await Amplify.API.subscribe(request:
                    .subscription(of: Todo.self,
                                  type: .onCreate))
            // operation.sequence
            
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
