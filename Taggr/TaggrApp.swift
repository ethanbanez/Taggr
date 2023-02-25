//
//  TaggrApp.swift
//  Taggr
//
//  Created by Ethan Bañez on 2/3/23.
//

import SwiftUI
import os

@main
struct TaggrApp: App {
  private var log = Logger(subsystem: Subsystem.lifecycle.description, category: "App")
  
  /* delegate for reinstantiating BLECentral and BLEPeripheral */
  @UIApplicationDelegateAdaptor private var taggrAppDelegate: TaggrAppDelegate
  
  let defaults = UserDefaults.standard
  
  /* persistence used for leaderboard stats and pins */
  let persistenceController = PersistenceController.shared
  
  /* we need to reinstantiate central and peripheral and insert it into a manager */
  
  /* here we define one bluetooth manager to be created and sent into the environment */
  
  init() {
    log.info("App is being initialized")
    /* used to initialize anything the app needs */
    if !defaults.bool(forKey: "isTagged") {
      // sets the tag status to false at the launch of the app
      defaults.set(false, forKey: "isTagged")
    }
  }
  var body: some Scene {
    WindowGroup {
      StatusView()
        .environment(\.managedObjectContext, persistenceController.container.viewContext)
//        .environmentObject(bluetoothManager)        /* this puts a single instance of bluetoothManager in the environment for all views to access */
    }
  }
}
