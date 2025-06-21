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

protocol VideoPlayerViewModelProtocol: ObservableObject {
  var player: AVPlayer { get }
  var isPlaying: Bool { get }
  var rotationAngle: Double { get }
  func play()
  func pause()
  func rotate()
  func applyGrayscale()
}

final class VideoPlayerViewModel: ObservableObject, VideoPlayerViewModelProtocol {

  @Published var player: AVPlayer
  @Published var isPlaying: Bool = false
  @Published var rotationAngle: Double = 0

  
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
    let item = AVPlayerItem(asset: asset)
    self.player = AVPlayer(playerItem: item)
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
  
  private func makeTexture(from ciImage: CIImage,
                           descriptor: MTLTextureDescriptor) -> MTLTexture? {
    let context = CIContext(mtlDevice: device)
    guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
    context.render(
      ciImage,
      to: texture,
      commandBuffer: nil,
      bounds: ciImage.extent,
      colorSpace: CGColorSpaceCreateDeviceRGB()
    )
    return texture
  }
}
