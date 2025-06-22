//
//  AddVideo+Extension.swift
//  Canva Demo
//
//  Created by Ben Liu on 22/6/2025.
//

import UIKit
import AVFoundation

extension VideoPlayerViewModel {
  
  /// Appends a video named `name.mp4` to the end of the original video using async track loading.
  func appendVideo(name: String) {
    Task { @MainActor in
      let firstAsset = originalAsset

      // Load second asset
      guard let secondURL = Bundle.main.url(forResource: name, withExtension: "mp4") else {
        print("❌ could not find \(name).mp4 in bundle")
        return
      }
      let secondAsset = AVURLAsset(url: secondURL)

      // Load durations using modern API
      let firstDuration: CMTime
      if #available(iOS 16.0, *) {
        firstDuration = (try? await firstAsset.load(.duration)) ?? .zero
      } else {
        firstDuration = firstAsset.duration
      }
      let secondDuration: CMTime
      if #available(iOS 16.0, *) {
        secondDuration = (try? await secondAsset.load(.duration)) ?? .zero
      } else {
        secondDuration = secondAsset.duration
      }

      do {
        // Async load video tracks
        let firstVideoTracks = try await firstAsset.loadTracks(withMediaType: .video)
        let secondVideoTracks = try await secondAsset.loadTracks(withMediaType: .video)

        guard let firstVideoTrack = firstVideoTracks.first else {
          print("❌ First video has no video track")
          return
        }
        guard let secondVideoTrack = secondVideoTracks.first else {
          print("❌ Second video has no video track")
          return
        }

        // Build composition
        let composition = AVMutableComposition()
        guard let compVideoTrack = composition.addMutableTrack(
          withMediaType: .video,
          preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
          print("❌ Failed to create composition video track")
          return
        }

        // Insert first segment
        try compVideoTrack.insertTimeRange(
          CMTimeRange(start: .zero, duration: firstDuration),
          of: firstVideoTrack,
          at: .zero
        )
        
        // Load and apply preferredTransform
        let firstTransform: CGAffineTransform
        if #available(iOS 16.0, *) {
          firstTransform = (try? await firstVideoTrack.load(.preferredTransform)) ?? .identity
        } else {
          firstTransform = firstVideoTrack.preferredTransform
        }
        compVideoTrack.preferredTransform = firstTransform

        // Insert second segment
        try compVideoTrack.insertTimeRange(
          CMTimeRange(start: .zero, duration: secondDuration),
          of: secondVideoTrack,
          at: firstDuration
        )

        // Async load and insert audio tracks similarly
        let compAudioTrack = composition.addMutableTrack(
          withMediaType: .audio,
          preferredTrackID: kCMPersistentTrackID_Invalid
        )
        if let compAudioTrack = compAudioTrack {
          let firstAudioTracks = try await firstAsset.loadTracks(withMediaType: .audio)
          if let firstAudio = firstAudioTracks.first {
            try compAudioTrack.insertTimeRange(
              CMTimeRange(start: .zero, duration: firstDuration),
              of: firstAudio,
              at: .zero
            )
          }
          let secondAudioTracks = try await secondAsset.loadTracks(withMediaType: .audio)
          if let secondAudio = secondAudioTracks.first {
            try compAudioTrack.insertTimeRange(
              CMTimeRange(start: .zero, duration: secondDuration),
              of: secondAudio,
              at: firstDuration
            )
          }
        }

        // Create and play on main thread
        DispatchQueue.main.async {
          let newItem = AVPlayerItem(asset: composition)
          // Preserve existing videoComposition if present
          if let currentVC = self.player.currentItem?.videoComposition {
            let newVC = AVMutableVideoComposition()
            newVC.frameDuration = currentVC.frameDuration
            newVC.renderSize = currentVC.renderSize
            newVC.instructions = currentVC.instructions
            newItem.videoComposition = newVC
          }
          self.player.replaceCurrentItem(with: newItem)
          self.player.play()
        }
      } catch {
        print("❌ Error loading tracks or inserting: \(error)")
      }
    }
  }
}

extension VideoPlayerViewModel: @unchecked Sendable {}
