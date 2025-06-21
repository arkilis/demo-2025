//
//  BackgroundMusic+Extension.swift
//  Canva Demo
//
//  Created by Ben Liu on 22/6/2025.
//

import AVFoundation

extension VideoPlayerViewModel {
  
  /// Adds background music to the current video
  func addBackgroundMusic(name: String) {
    // 1. Use the original video asset
    let asset = originalAsset
    
    // 2. Create a new mutable composition
    let composition = AVMutableComposition()
    
    // 3. Insert the video track
    guard let videoTrack = asset.tracks(withMediaType: .video).first,
          let compVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
          )
    else { return }
    
    do {
      try compVideoTrack.insertTimeRange(
        CMTimeRange(start: .zero, duration: asset.duration),
        of: videoTrack,
        at: .zero
      )
      compVideoTrack.preferredTransform = videoTrack.preferredTransform
    } catch {
      print("Video insert failed:", error)
      return
    }
    
    // 4. Insert the selected background audio
    var compAudioTrack: AVMutableCompositionTrack?
    if let musicURL = Bundle.main.url(forResource: name, withExtension: "mp3"),
       let audioAsset = try? AVAsset(url: musicURL),
       let audioTrack = audioAsset.tracks(withMediaType: .audio).first {
      
      compAudioTrack = composition.addMutableTrack(
        withMediaType: .audio,
        preferredTrackID: kCMPersistentTrackID_Invalid
      )
      do {
        try compAudioTrack?.insertTimeRange(
          CMTimeRange(start: .zero, duration: asset.duration),
          of: audioTrack,
          at: .zero
        )
      } catch {
        print("Audio insert failed:", error)
      }
    }
    
    // 5. Create a new player item from the composition
    let newItem = AVPlayerItem(asset: composition)
    
    // 6. Carry over any existing text/filters
    newItem.videoComposition = player.currentItem?.videoComposition
    
    // 7. Build an audio mix if we added audio
    if let compAudio = compAudioTrack {
      let audioMix = AVMutableAudioMix()
      let params = AVMutableAudioMixInputParameters(track: compAudio)
      params.setVolume(0.5, at: .zero)
      audioMix.inputParameters = [params]
      newItem.audioMix = audioMix
    }
    
    // 8. Swap in the new item and play
    player.replaceCurrentItem(with: newItem)
    player.play()
  }
}
