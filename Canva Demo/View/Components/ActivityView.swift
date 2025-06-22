//
//  ActivityView.swift
//  Canva Demo
//
//  Created by Ben Liu on 22/6/2025.
//

import SwiftUI

/// A SwiftUI wrapper for UIActivityViewController to share items.
struct ActivityView: UIViewControllerRepresentable {
  let activityItems: [Any]
  let applicationActivities: [UIActivity]? = nil

  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
  }

  func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}
