//
//  VideoPlayerViewModel.swift
//  Canva Demo
//
//  Created by Ben Liu on 21/6/2025.
//

import SwiftUI
import AVFoundation
import Combine
import Metal
import CoreImage
import UIKit
import CoreGraphics

/// Simple enum to pick one of the four corners (or center) for your overlay text.
enum TextPosition {
    case topLeft, topCenter, topRight
    case centerLeft, center, centerRight
    case bottomLeft, bottomCenter, bottomRight
    case custom(x: CGFloat, y: CGFloat) // 0.0 to 1.0 normalized coordinates
}


protocol VideoPlayerViewModelProtocol: ObservableObject {
  var player: AVPlayer { get }
  var isPlaying: Bool { get }
  var rotationAngle: Double { get }
  func play()
  func pause()
  func rotate()
  func applyGrayscale()
  func addBackgroundMusic(name: String)
  func appendVideo(name: String)
  func addTextOverlay(text: String,
                     position: TextPosition,
                     fontSize: CGFloat,
                     textColor: UIColor,
                     backgroundColor: UIColor,
                     startTime: CMTime,
                     duration: CMTime?)
}

final class VideoPlayerViewModel: ObservableObject, VideoPlayerViewModelProtocol {
  
  @Published var player: AVPlayer
  @Published var isPlaying: Bool = false
  @Published var rotationAngle: Double = 0
  
  private let originalVideoURL: URL
  private let originalAsset: AVAsset
  
  private let device: MTLDevice
  private let commandQueue: MTLCommandQueue
  private let pipelineState: MTLComputePipelineState
  
  init() {
    // Metal setup
    device = MTLCreateSystemDefaultDevice()!
    commandQueue = device.makeCommandQueue()!
    let library = device.makeDefaultLibrary()!
    guard let kernelFunction = library.makeFunction(name: "grayscaleShader") else {
      fatalError("grayscaleShader not found in Metal library")
    }
    pipelineState = try! device.makeComputePipelineState(function: kernelFunction)
    
    // Load video asset
    guard let url = Bundle.main.url(forResource: "sample", withExtension: "mp4") else {
      fatalError("sample.mp4 not found in bundle")
    }
    let asset = AVAsset(url: url)
    self.originalVideoURL = url
    self.originalAsset = asset
    let item = AVPlayerItem(asset: asset)
    self.player = AVPlayer(playerItem: item)
    
    // Observe end of playback to reset isPlaying
    NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime,
      object: self.player.currentItem,
      queue: .main
    ) { [weak self] _ in
      self?.isPlaying = false
    }
  }
  
  func play() {
    player.play()
    isPlaying = true
  }
  
  func pause() {
    player.pause()
    isPlaying = false
  }
  
  func rotate() {
    rotationAngle = (rotationAngle + 90).truncatingRemainder(dividingBy: 360)
  }
  
  func applyGrayscale() {
    guard let currentItem = player.currentItem else { return }
    let asset = currentItem.asset
    
    // Build a video composition that applies a custom CIColorKernel
    let videoComposition = AVMutableVideoComposition(asset: asset) { request in
      let srcImage = request.sourceImage
      let extent = srcImage.extent
      
      // Embedded metal-like kernel source for grayscale
      let kernelSource = """
        kernel vec4 grayscaleKernel(__sample s) {
            float gray = dot(s.rgb, vec3(0.299, 0.587, 0.114));
            return vec4(gray, gray, gray, s.a);
        }
        """
      guard let kernel = try? CIColorKernel(source: kernelSource) else {
        return request.finish(with: srcImage, context: nil)
      }
      
      // Apply the kernel
      let args = [srcImage] as [Any]
      guard let output = kernel.apply(extent: extent, arguments: args) else {
        return request.finish(with: srcImage, context: nil)
      }
      
      // Finish with filtered image
      request.finish(with: output, context: nil)
    }
    
    // Match render settings
    if let track = asset.tracks(withMediaType: .video).first {
      videoComposition.renderSize = track.naturalSize
      videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
    }
    
    // Apply to player item
    currentItem.videoComposition = videoComposition
  }
  
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
  
  /// Appends a video named `name.mp4` from the main bundle to the end of the original video.
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
  
  deinit {
    NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
  }
}
