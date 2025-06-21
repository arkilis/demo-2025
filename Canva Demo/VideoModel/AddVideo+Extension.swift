//
//  AddVideo+Extension.swift
//  Canva Demo
//
//  Created by Ben Liu on 22/6/2025.
//

import AVFoundation

extension VideoPlayerViewModel {
  
  /// Appends a video to the end of the original video
  func appendVideo(name: String) {
    // 1. First segment: original asset
    let firstAsset = originalAsset
    
    // 2. Second segment: load from bundle
    guard let secondURL = Bundle.main.url(forResource: name, withExtension: "mp4") else {
      print("❌ could not find \(name).mp4 in bundle")
      return
    }
    let secondAsset = AVAsset(url: secondURL)
    
    // 3. Build composition
    let composition = AVMutableComposition()
    
    // 4. Create a SINGLE video track for both videos
    guard let compVideoTrack = composition.addMutableTrack(
      withMediaType: .video,
      preferredTrackID: kCMPersistentTrackID_Invalid
    ) else {
      print("❌ Failed to create composition video track")
      return
    }
    
    // 5. Insert first video into the single track
    guard let firstVideoTrack = firstAsset.tracks(withMediaType: .video).first else {
      print("❌ First video has no video track")
      return
    }
    
    do {
      try compVideoTrack.insertTimeRange(
        CMTimeRange(start: .zero, duration: firstAsset.duration),
        of: firstVideoTrack,
        at: .zero
      )
      compVideoTrack.preferredTransform = firstVideoTrack.preferredTransform
      print("✅ First video inserted: duration \(firstAsset.duration.seconds)s")
    } catch {
      print("❌ Failed to insert first video: \(error)")
      return
    }
    
    // 6. Insert second video into the SAME track at the end of first video
    guard let secondVideoTrack = secondAsset.tracks(withMediaType: .video).first else {
      print("❌ Second video has no video track")
      return
    }
    
    do {
      try compVideoTrack.insertTimeRange(
        CMTimeRange(start: .zero, duration: secondAsset.duration),
        of: secondVideoTrack,
        at: firstAsset.duration  // Start at end of first video
      )
      print("✅ Second video inserted: duration \(secondAsset.duration.seconds)s at time \(firstAsset.duration.seconds)s")
    } catch {
      print("❌ Failed to insert second video: \(error)")
      return
    }
    
    // 7. Create a SINGLE audio track for both audio streams
    if let compAudioTrack = composition.addMutableTrack(
      withMediaType: .audio,
      preferredTrackID: kCMPersistentTrackID_Invalid
    ) {
      // Insert first audio
      if let firstAudio = firstAsset.tracks(withMediaType: .audio).first {
        do {
          try compAudioTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: firstAsset.duration),
            of: firstAudio,
            at: .zero
          )
          print("✅ First audio inserted")
        } catch {
          print("⚠️ Failed to insert first audio: \(error)")
        }
      }
      
      // Insert second audio at end of first
      if let secondAudio = secondAsset.tracks(withMediaType: .audio).first {
        do {
          try compAudioTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: secondAsset.duration),
            of: secondAudio,
            at: firstAsset.duration
          )
          print("✅ Second audio inserted")
        } catch {
          print("⚠️ Failed to insert second audio: \(error)")
        }
      }
    }
    
    // 8. Log total composition duration
    let totalDuration = firstAsset.duration + secondAsset.duration
    print("✅ Total composition duration: \(totalDuration.seconds)s")
    
    // 9. Create new player item and replace current item
    let newItem = AVPlayerItem(asset: composition)
    
    // 10. Preserve any existing video composition (filters, etc.)
    if let currentVideoComposition = player.currentItem?.videoComposition {
      // Create a new video composition for the concatenated video
      let newVideoComposition = AVMutableVideoComposition()
      newVideoComposition.frameDuration = currentVideoComposition.frameDuration
      newVideoComposition.renderSize = currentVideoComposition.renderSize
      newVideoComposition.instructions = currentVideoComposition.instructions
      newItem.videoComposition = newVideoComposition
    }
    
    // 11. Replace and play
    player.replaceCurrentItem(with: newItem)
    print("✅ Player item replaced, starting playback")
    player.play()
  }
}
