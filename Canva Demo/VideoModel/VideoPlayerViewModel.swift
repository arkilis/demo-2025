//
//  VideoPlayerViewModel.swift
//  Canva Demo
//
//  Created by Ben Liu on 21/6/2025.
//

import SwiftUI
import AVFoundation
import Combine
import UIKit

/// Simple enum to pick one of the four corners (or center) for your overlay text.
enum ElementPosition {
    case topLeft, topCenter, topRight
    case centerLeft, center, centerRight
    case bottomLeft, bottomCenter, bottomRight
    case custom(x: CGFloat, y: CGFloat) // 0.0 to 1.0 normalized coordinates
}

enum ImageSize {
  case tiny        // 5% of video width
  case small       // 10% of video width
  case medium      // 20% of video width
  case large       // 30% of video width
  case original    // Keep original size (scaled to fit if too large)
  case custom(width: CGFloat, height: CGFloat) // Specific pixel dimensions
  case percentage(widthPercent: CGFloat, heightPercent: CGFloat) // % of video size
}

protocol VideoPlayerViewModelProtocol: ObservableObject {
  var player: AVPlayer { get }
  var isPlaying: Bool { get }
  var rotationAngle: Double { get }
  var timelineThumbnails: [UIImage] { get }
  func play()
  func pause()
  func rotate()
  func applyGrayscale()
  func addBackgroundMusic(name: String)
  func appendVideo(name: String)
  func addTextOverlay(text: String,
                     position: ElementPosition,
                     fontSize: CGFloat,
                     textColor: UIColor,
                     backgroundColor: UIColor,
                     startTime: CMTime,
                     duration: CMTime?)
  func addImageOverlay(imageName: String,
                       position: ElementPosition,
                       size: ImageSize,
                       opacity: Float,
                       startTime: CMTime,
                       duration: CMTime?)
  func exportCurrentVideo(completion: @escaping (URL?) -> Void)
  func generateTimelineThumbnails()
}

final class VideoPlayerViewModel: ObservableObject, VideoPlayerViewModelProtocol {
  
  @Published var player: AVPlayer
  @Published var isPlaying: Bool = false
  @Published var rotationAngle: Double = 0
  @Published var timelineThumbnails: [UIImage] = []
  
  let originalVideoURL: URL
  let originalAsset: AVAsset
  
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
    timelineThumbnails.removeAll()
    generateTimelineThumbnails()
  }
  
  // Update the timeline thumbnails
  func generateTimelineThumbnails() {
    let asset = player.currentItem?.asset ?? originalAsset
    let imageGenerator = AVAssetImageGenerator(asset: asset)
    imageGenerator.appliesPreferredTrackTransform = true

    // Ensure overlays and filters are applied in thumbnails
    if let videoComp = player.currentItem?.videoComposition {
        imageGenerator.videoComposition = videoComp
    }

    let durationSeconds = CMTimeGetSeconds(asset.duration)
    let thumbnailCount = 10
    let interval = durationSeconds / Double(thumbnailCount)
    let times = (0..<thumbnailCount).map { index in
      CMTime(seconds: Double(index) * interval, preferredTimescale: 600) as NSValue
    }

    imageGenerator.generateCGImagesAsynchronously(forTimes: times) { _, cgImage, _, result, _ in
      if let cgImage = cgImage, result == .succeeded {
        let uiImage = UIImage(cgImage: cgImage)
        DispatchQueue.main.async {
          self.timelineThumbnails.append(uiImage)
        }
      }
    }
  }
  
  deinit {
    NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
  }
}
