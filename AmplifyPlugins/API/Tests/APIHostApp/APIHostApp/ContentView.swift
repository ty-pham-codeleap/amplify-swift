//
//  ContentView.swift
//  APIHostApp
//
//  Created by Law, Michael on 7/21/22.
//

import SwiftUI
import Amplify


class MockAPIPlugin: APICategoryGraphQLBehavior {
    
}
class ContentViewModel: ObservableObject {
    
}

struct ContentView: View {
    @StateObject var vm = StateObject()
    
    var body: some View {
        VStack {
            
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
