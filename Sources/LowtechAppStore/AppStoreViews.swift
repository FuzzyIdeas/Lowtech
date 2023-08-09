//
//  AppStoreViews.swift
//
//
//  Created by Alin Panaitiu on 02.09.2022.
//

import Foundation
import Lowtech
import SwiftUI

// MARK: - LowtechAppStoreDelegate

open class LowtechAppStoreDelegate: LowtechAppDelegate {
    @MainActor
    @inline(__always)
    open func trialExpired() -> Bool {
        false
    }

    @MainActor
    @inline(__always)
    open func hideTrialOSD() {
        guard trialMode, trialExpired() else {
            return
        }
        trialOSD.ignoresMouseEvents = true
        trialOSD.alphaValue = 0
    }

    @MainActor
    @inline(__always)
    open func toggleTrialOSD() {
        if trialOSD.alphaValue > 0 {
            hideTrialOSD()
        } else {
            showTrialOSD()
        }
    }

    @MainActor
    @inline(__always)
    open func showTrialOSD() {
        guard trialMode, trialExpired() else {
            return
        }
        trialOSD.ignoresMouseEvents = false
        trialOSD.show(closeAfter: 0, fadeAfter: 0, offCenter: 0, centerWindow: false, corner: .bottomRight, screen: .main)
    }

    public lazy var trialOSD = {
        let w = OSDWindow(swiftuiView: TrialOSDContainer().any)
        w.alphaValue = 0
        return w
    }()
}

// MARK: - TrialOSDContainer

public struct TrialOSDContainer: View {
    public init() {}

    public var body: some View {
        HStack {
            if let img = NSImage(named: NSImage.applicationIconName) {
                Image(nsImage: img)
                    .resizable()
                    .frame(width: 90, height: 90)
            }
            VStack(alignment: .leading) {
                Text("Trial period of") + Text(" \(Bundle.main.name ?? "the app") ").bold() + Text("expired for the current session.")
                Text("Buy the full version from") + Text(" App Store ").bold() + Text("to remove this limitation.")

                HStack {
                    if let url = LowtechAppDelegate.instance.appStoreURL {
                        Button("Go to App Store") { NSWorkspace.shared.open(url) }
                            .buttonStyle(FlatButton(color: .blue, textColor: .white))
                    }
                    Button("Quit app") { NSApp.terminate(nil) }
                        .buttonStyle(FlatButton(color: Color.red, textColor: .white))
                }
            }.fixedSize()
        }
        .padding()
        .background(
            .regularMaterial
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(radius: 6, x: 0, y: 3)
        .padding()
    }
}
