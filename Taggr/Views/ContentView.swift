//
//  ContentView.swift
//  Taggr
//
//  Created by Ethan Bañez on 2/3/23.
//

import SwiftUI
import CoreData
import MultipeerConnectivity

struct ContentView: View {
  
  /* this grabs the managed object context, aka the persistent store, and stores it in this variable */
  @Environment(\.managedObjectContext) private var viewContext
  
  // we have this taggrSession object that has the taggedStatus property
  @StateObject var taggrSession = TaggrSession()
  
  var body: some View {
    HStack {
      Text("Devices in session: \(taggrSession.deviceCount)").padding()
      Spacer()
//      VStack {
//        Text("Display names: ").padding()
//        ForEach(Array(taggrSession), id: \.self) { key in
//          Text("\(taggrSession.peersInSession[key])")
//        }
//      }
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    
    /* this allows me to pass the peristence controller to all child views!! */
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
  }
}
