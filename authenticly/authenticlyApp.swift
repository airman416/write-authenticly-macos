//
//  authenticlyApp.swift
//  authenticly
//
//  Created by Armaan Agrawal on 8/2/25.
//

import SwiftUI
import SwiftData
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Force light status bar content globally
        UIApplication.shared.setStatusBarStyle(.lightContent, animated: false)
        return true
    }
}

@main
struct authenticlyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            JournalEntry.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    init() {
        // Register all Lato fonts for iOS
        let fontNames = [
            "Lato-Regular",
            "Lato-Bold", 
            "Lato-BoldItalic",
            "Lato-Italic",
            "Lato-Light",
            "Lato-LightItalic", 
            "Lato-Thin",
            "Lato-ThinItalic",
            "Lato-Black",
            "Lato-BlackItalic"
        ]
        
        for fontName in fontNames {
            if let fontURL = Bundle.main.url(forResource: fontName, withExtension: "ttf") {
                registerFont(from: fontURL)
            }
        }
        

    }
    
    private func registerFont(from url: URL) {
        guard let fontDataProvider = CGDataProvider(url: url as CFURL),
              let font = CGFont(fontDataProvider) else {
            print("Failed to load font from \(url)")
            return
        }
        
        var error: Unmanaged<CFError>?
        CTFontManagerRegisterGraphicsFont(font, &error)
        
        if let error = error {
            print("Failed to register font: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light) // Default to light mode for iOS
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .modelContainer(sharedModelContainer)
    }
}
