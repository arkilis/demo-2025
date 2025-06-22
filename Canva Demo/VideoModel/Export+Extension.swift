//
//  Export+Extension.swift
//  Canva Demo
//
//  Created by Ben Liu on 22/6/2025.
//

import AVFoundation
import UIKit

extension VideoPlayerViewModel {
  /// Exports the current video (with any overlays or edits) to a temporary MP4 file.
  func exportCurrentVideo(completion: @escaping (URL?) -> Void) {
    guard let currentItem = player.currentItem else {
      return
    }
    let asset = currentItem.asset
    
    // Prepare export session
    guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
      return
    }
    let outputURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("exportedVideo-\(UUID().uuidString).mp4")
    try? FileManager.default.removeItem(at: outputURL)
    exportSession.outputURL = outputURL
    exportSession.outputFileType = .mp4
    exportSession.videoComposition = currentItem.videoComposition
    exportSession.audioMix = currentItem.audioMix
    
    Task {
      do {
        // Perform export (async throws)
        try await exportSession.export(to: outputURL, as: .mp4)
        // Export succeeded
        DispatchQueue.main.async {
          completion(outputURL)
        }
      } catch {
        // Export failed
        DispatchQueue.main.async {
          completion(nil)
        }
      }
    }
  }
}
