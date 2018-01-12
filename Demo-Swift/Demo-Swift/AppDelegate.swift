//
//  AppDelegate.swift
//  Demo-Swift
//
//  Created by Kelvin Lau on 2018-01-11.
//  Copyright © 2018 Kelvin Lau. All rights reserved.
//

import UIKit

@UIApplicationMain
final class AppDelegate: UIResponder {
  
  var window: UIWindow?
}

// MARK: - UIApplicationDelegate
extension AppDelegate: UIApplicationDelegate {
  
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]? = nil) -> Bool {
    window = UIWindow(frame: UIScreen.main.bounds)
    window?.rootViewController = DemoViewController.instantiate()
    window?.makeKeyAndVisible()
    return true
  }
}
