//
//  PeripheralView.swift
//  Taggr
//
//  Created by Ethan Bañez on 2/20/23.
//

import Foundation
import SwiftUI

/*
 Allows the user to select to connect to a specific peripheral
 */
struct PeripheralView: View {
  
  @ObservedObject var blegroup = BLEGroup.shared
  
  @AppStorage("TagServiceUUID", store: .standard) var tagService: String = (UserDefaults.standard.string(forKey: "TagServiceUUID") ?? "")
  @AppStorage("TagCharacteristicUUID", store: .standard) var tagCharacteristic: String = (UserDefaults.standard.string(forKey: "TagCharacteristicUUID") ?? "")
  
  var body: some View {
    VStack(alignment: .center, spacing: 20) {
      if blegroup.ready == true {
        Text("READY")
          .foregroundColor(.green)
          .font(.largeTitle)
          .background(Circle()
            .foregroundColor(.orange)
            .frame(minWidth: 150, minHeight: 150))
      } else {
        Text("WAITING")
          .foregroundColor(.green)
          .font(.largeTitle)
          .background(Circle()
            .foregroundColor(.orange)
            .frame(minWidth: 150, minHeight: 150))
      }
      VStack {
        Text(tagService)
        Text(tagCharacteristic)
      }.padding(.top, 100)
    }
  }
}


struct PeripheralViewsPreviews: PreviewProvider {
  static var previews: some View {
    PeripheralView()
  }
}
