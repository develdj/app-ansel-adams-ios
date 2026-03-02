//
//  ZoneSystemMasterApp.swift
//  Zone System Master - Photo Editor Engine
//  Main app entry point
//

import SwiftUI

@main
struct ZoneSystemMasterApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ZoneSystemEditorView()
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Configure app settings
        setupAppearance()
        setupNotifications()
        
        return true
    }
    
    private func setupAppearance() {
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .systemBackground
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
    
    private func setupNotifications() {
        // Request photo library access
        PHPhotoLibrary.requestAuthorization { status in
            print("Photo library authorization: \(status)")
        }
    }
}

// MARK: - Import Photos

import Photos
