//
//  TaggrSession.swift
//  Taggr
//
//  Created by Ethan Bañez on 2/3/23.
//

import Foundation
import MultipeerConnectivity
import struct os.Logger

// my own session class
class TaggrSession: NSObject, ObservableObject {
  /* I can use a unique service type for each taggr_group to specify specific devices */
  private let serviceType = "taggr-session"
  private let peerID = MCPeerID(displayName: UIDevice.current.name)
  private let taggrSession: MCSession
  private let taggrBrowser: MCNearbyServiceBrowser
  private let taggrAdvertiser: MCNearbyServiceAdvertiser
  
  
  // should this be private??
  private let log = Logger(subsystem: Subsystem.connectivity.description, category: "session")
  
  override init() {
    
    taggrSession = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
    taggrBrowser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
    taggrAdvertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: serviceType)
    
    super.init()
    
    taggrSession.delegate = self
    taggrBrowser.delegate = self
    taggrAdvertiser.delegate = self
    
    taggrBrowser.startBrowsingForPeers()
    taggrAdvertiser.startAdvertisingPeer()
  }
  deinit {
    taggrAdvertiser.stopAdvertisingPeer()
    taggrBrowser.startBrowsingForPeers()
  }
  
  // published so the view can see
  @Published var taggedStatus: String = "no status"
  
  // some better properties that work with my phone would be seeing how many nearby are connected…?
  @Published var deviceCount: Int = 0
  @Published var peersInSession: [MCPeerID: String] = [:]
  
  func send(message: String) {
    log.debug("Action:  send() - Message: \(message) - To: \(self.taggrSession.connectedPeers).")
    if !self.taggrSession.connectedPeers.isEmpty {
      do {
        try taggrSession.send(message.data(using: .utf8)!, toPeers: self.taggrSession.connectedPeers, with: .reliable)
      } catch {
        log.error("Error: \(error)")
      }
    }
  }
  
}

/* these are all events that are called that I can have special instructions when they happen*/
extension TaggrSession: MCSessionDelegate {
  /* shows who is connected */
  func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
    switch state {
    case MCSessionState.connected:
      log.info("Session didChange .connected: \(peerID) connected.")
      DispatchQueue.main.async {
        self.deviceCount = session.connectedPeers.count
      }
    case MCSessionState.notConnected:
      DispatchQueue.main.async {
        self.deviceCount = self.peersInSession.count
      }
    default:
      log.debug("Session didChange .connecting: \(peerID) connecting.")
    }
  }
  
  func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
    /* implement this function to handle receiving data from a peer */
//    if let string = String(data: data, encoding: .utf8) {
//      log.debug("message received: \(string) from peer: \(peerID)")
//      DispatchQueue.main.async {
//        self.taggedStatus = string
//      }
//    } else {
//      log.error("error: message not a string")
//    }
  }
  
  func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
    
  }
  
  func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
    
  }
  
  func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
    
  }
}

extension TaggrSession: MCNearbyServiceBrowserDelegate {
  func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
    log.debug("ServiceBrowser didNotStartBrowsingForPeers: \(String(describing: error))")
  }
  
  func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
    log.debug("peer: \(peerID) found.")
    if !peersInSession.values.contains(peerID.displayName) {
      browser.invitePeer(peerID, to: taggrSession, withContext: nil, timeout: 30)
    }
  }
  
  func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
    log.debug("connection to \(peerID) lost")
  }
  
}


extension TaggrSession: MCNearbyServiceAdvertiserDelegate {
  func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
    
    /* the method provides a function, invitationHandler, that we need to implement
        that holds the logic for how we want to deal with invitations.
        this code just accepts right away… */
    invitationHandler(true, taggrSession)
  }
  
  func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
    log.debug("ServiceAdvertiser didNotStartAdvertisingPeer \(String(describing: error))")
  }
  
}
