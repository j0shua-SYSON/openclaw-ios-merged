//
//  AppDelegate.swift
//  Folium
//
//  Created by Jarrod Norwell on 3/6/2026.
//

import UIKit

// @main stripped: FoliumMode is embedded as a framework in OpenClaw, not its own app.
// Its scene/bootstrap logic is invoked by the host when switching to the Folium mode.
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        true
    }

    // MARK: UISceneSession Lifecycle
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {}
}
