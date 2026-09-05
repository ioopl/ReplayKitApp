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

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let label = UILabel()
        label.text = "ReplayKit broadcast is ready"
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        print("🟡 [BroadcastSetupUI] setup UI loaded; completing broadcast setup")
        completeSetupIfNeeded()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        completeSetupIfNeeded()
    }

    private func completeSetupIfNeeded() {
        guard !didCompleteSetup else { return }
        didCompleteSetup = true
        userDidFinishSetup()
    }

    // Call this method when the user has finished interacting with the view controller and a broadcast stream can start
    func userDidFinishSetup() {
        
        // URL of the resource where broadcast can be viewed that will be returned to the application
        // let broadcastURL = URL(string:"http://apple.com/broadcast/streamID")

        // This is a local recording upload extension, not a network broadcast.
        // Supply a non-network app URL because this SDK requires a URL here.
        let broadcastURL = URL(string: "replaykitapp://local-broadcast")!
        
        // Dictionary with setup information that will be provided to broadcast extension when broadcast is started
        let setupInfo: [String : NSCoding & NSObjectProtocol] = ["broadcastName": "example" as NSCoding & NSObjectProtocol]
        
        // Tell ReplayKit that the extension is finished setting up and can begin broadcasting
        print("🟡 [BroadcastSetupUI] completeRequest sent; SampleHandler should start next")
        self.extensionContext?.completeRequest(withBroadcast: broadcastURL, setupInfo: setupInfo)
    }
    
    func userDidCancelSetup() {
        let error = NSError(domain: "YouAppDomain", code: -1, userInfo: nil)
        // Tell ReplayKit that the extension was cancelled by the user
        self.extensionContext?.cancelRequest(withError: error)
    }
}
