//
//  GroupCreationView.swift
//  Taggr
//
//  Created by Ethan Bañez on 2/27/23.
//

import Foundation
import SwiftUI
import CoreBluetooth


/*
 View for when the device is not currently in a game and is looking to either create a group or join a group
 */


/* Should there be two views insdie this view, one for joining and one for creating?? */
struct GroupCreationView: View {
  // need a way of going back from joining creating a group
  @ObservedObject var blegroup = BLEGroup.shared
  //  @State var choice: Bool
  @State private var isShowingDetailView = false
  var body: some View {
    NavigationView {
      VStack {
        Button("Destoy group session", action: {
          blegroup.destroyGroupSession()
        })
        HStack {
          Button("Create Group", action: {
            blegroup.createGroup()
          })
          Button("Join Group", action: {
            blegroup.joinGroup()
          })
        }
      }
      }
  }
}

struct GroupCreationPreview: PreviewProvider {
  static var previews: some View {
    GroupCreationView().frame(minWidth: 800, minHeight: 600)
  }
}
