//
//  Persistence.swift
//  Taggr
//
//  Created by Ethan Bañez on 2/3/23.
//

import CoreData
import struct os.Logger

let log = Logger(subsystem: Subsystem.peristence.description, category: "controller")

struct PersistenceController {
  static let shared = PersistenceController()
  
  static var preview: PersistenceController = {
    let result = PersistenceController(inMemory: true)
    let viewContext = result.container.viewContext
    for _ in 0..<10 {
      let newItem = Item(context: viewContext)
      newItem.timestamp = Date()
    }
    do {
      try viewContext.save()
    } catch {
      // Replace this implementation with code to handle the error appropriately.
      // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
      let nsError = error as NSError
      log.error("Unresolved error \(nsError), \(nsError.localizedDescription)")
      print("Core Data failed to load: \(nsError.localizedDescription)")
    }
    return result
  }()
  
  let container: NSPersistentContainer
  /* initializes the persistence controller by grabbing the desired container
      specifies where to store it in memory
      what to do when */
  init(inMemory: Bool = false) {
    container = NSPersistentContainer(name: "Taggr")
    if inMemory {
      // we do want to read and write to a specific place on disk.
      // everything we are working with should be stored to disk…
      
      container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")    // would /Library/Application support/CoreData work??
    }
    container.loadPersistentStores(completionHandler: { (storeDescription, error) in
      if let error = error as NSError? {
        // Replace this implementation with code to handle the error appropriately.
        // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
        
        /*
         Typical reasons for an error here include:
         * The parent directory does not exist, cannot be created, or disallows writing.
         * The persistent store is not accessible, due to permissions or data protection when the device is locked.
         * The device is out of space.
         * The store could not be migrated to the current model version.
         Check the error message to determine what the actual problem was.
         */
        fatalError("Unresolved error \(error), \(error.userInfo)")
      }
    })
    container.viewContext.automaticallyMergesChangesFromParent = true
  }
}
