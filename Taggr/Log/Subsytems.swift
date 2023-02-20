//
//  Logger.swift
//  Taggr
//
//  Created by Ethan Bañez on 2/3/23.
//

import Foundation

private let bundleID = Bundle.main.bundleIdentifier!

enum Subsystem: String, CaseIterable, CustomStringConvertible {
  case connectivity, networking, peristence, lifecycle
  
  var description: String {
    switch self {
    case .connectivity:
      return bundleID + ".connectivity"
    case .networking:
      return bundleID + ".networking"
    case .peristence:
      return bundleID + ".persistence"
    case .lifecycle:
      return bundleID + ".lifecycle"
    }
  }
}
