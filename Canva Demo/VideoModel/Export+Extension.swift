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
      completion(nil)
      return
    }
    let asset = currentItem.asset
    // Prepare export session
    guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
      completion(nil)
      return
    }
    let outputURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("exportedVideo-\(UUID().uuidString).mp4")
    try? FileManager.default.removeItem(at: outputURL)
    exportSession.outputURL = outputURL
    exportSession.outputFileType = .mp4
    exportSession.videoComposition = currentItem.videoComposition
    exportSession.audioMix = currentItem.audioMix
    
    exportSession.exportAsynchronously {
      DispatchQueue.main.async {
        completion(exportSession.status == .completed ? outputURL : nil)
      }
    }
  }
  
  /// Presents a share sheet (including AirDrop) to share the exported video.
  /// Call this from a UIViewController context.
  func shareExportedVideo(from viewController: UIViewController) {
    exportCurrentVideo { url in
      guard let url = url else { return }
      DispatchQueue.main.async {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        activityVC.excludedActivityTypes = nil
        viewController.present(activityVC, animated: true)
      }
    }
  }
  
}
