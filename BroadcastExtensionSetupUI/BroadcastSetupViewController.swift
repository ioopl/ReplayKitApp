//
//  BroadcastSetupViewController.swift
//  BroadcastExtensionSetupUI
//
//  Created by Umair Hasan on 15/08/2026.
//

import ReplayKit
import UIKit

class BroadcastSetupViewController: UIViewController {

    private var didCompleteSetup = false

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // This setup extension has no user-configurable fields. ReplayKit requires the
        // setup request to be explicitly completed before it starts SampleHandler.
        guard !didCompleteSetup else { return }
        didCompleteSetup = true
        userDidFinishSetup()
    }

    // Call this method when the user has finished interacting with the view controller and a broadcast stream can start
    func userDidFinishSetup() {
        // URL of the resource where broadcast can be viewed that will be returned to the application
        let broadcastURL = URL(string:"http://apple.com/broadcast/streamID")
        
        // Dictionary with setup information that will be provided to broadcast extension when broadcast is started
        let setupInfo: [String : NSCoding & NSObjectProtocol] = ["broadcastName": "example" as NSCoding & NSObjectProtocol]
        
        // Tell ReplayKit that the extension is finished setting up and can begin broadcasting
        self.extensionContext?.completeRequest(withBroadcast: broadcastURL!, setupInfo: setupInfo)
    }
    
    func userDidCancelSetup() {
        let error = NSError(domain: "YouAppDomain", code: -1, userInfo: nil)
        // Tell ReplayKit that the extension was cancelled by the user
        self.extensionContext?.cancelRequest(withError: error)
    }
}
