import SwiftUI
import UniformTypeIdentifiers

@main
struct MoneyFlowApp: App {
    @StateObject private var dataManager = DataManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataManager)
        }
        #if os(macOS)
        .windowStyle(.automatic)
        .defaultSize(width: 900, height: 600)
        #endif
    }
}

// Custom UTType for MoneyFlow data
extension UTType {
    static var moneyFlowData: UTType {
        UTType(exportedAs: "com.jwkim.moneyflow.data", conformingTo: .json)
    }
}
