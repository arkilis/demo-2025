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

protocol VideoPlayerViewModelProtocol: ObservableObject {
  var player: AVPlayer { get }
  var isPlaying: Bool { get }
  var rotationAngle: Double { get }
  func play()
  func pause()
  func rotate()
  func applyGrayscale()
  func applyText(_ text: String)
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
  
  /// Overlays the given text using a Metal compute shader.
  func applyText(_ text: String) {
      guard let currentItem = player.currentItem else { return }
      let asset = currentItem.asset

      // 1. Determine video size
      guard let track = asset.tracks(withMediaType: .video).first else { return }
      let size = track.naturalSize

      // 2. Create a texture for the rendered text
      let font = UIFont.systemFont(ofSize: 72)
      guard let textTexture = makeTextTexture(text,
                                              font: font,
                                              color: .white,
                                              device: device,
                                              size: size) else {
          return
      }

      // 3. Build video composition with Metal overlay
      let videoComposition = AVMutableVideoComposition(asset: asset) { request in
          let srcImage = request.sourceImage.clampedToExtent()

          // 4. Prepare input/output Metal textures
          let desc = MTLTextureDescriptor.texture2DDescriptor(
              pixelFormat: .bgra8Unorm,
              width: Int(size.width),
              height: Int(size.height),
              mipmapped: false
          )
          desc.usage = [.shaderRead, .shaderWrite]
          guard
              let inTexture = self.makeTexture(from: srcImage, descriptor: desc),
              let outTexture = self.device.makeTexture(descriptor: desc)
          else {
              return request.finish(with: srcImage, context: nil)
          }

          // 5. Compile the overlay compute pipeline
          guard let library = self.device.makeDefaultLibrary() else {
              return request.finish(with: srcImage, context: nil)
          }
          let funcOverlay = library.makeFunction(name: "overlayTextShader")!
          let overlayState = try! self.device.makeComputePipelineState(function: funcOverlay)

          // 6. Encode compute pass
          let cmdBuf = self.commandQueue.makeCommandBuffer()!
          let encoder = cmdBuf.makeComputeCommandEncoder()!
          encoder.setComputePipelineState(overlayState)
          encoder.setTexture(inTexture, index: 0)
          encoder.setTexture(outTexture, index: 1)
          encoder.setTexture(textTexture, index: 2)

          let w = overlayState.threadExecutionWidth
          let h = overlayState.maxTotalThreadsPerThreadgroup / w
          let threadsPerGroup = MTLSize(width: w, height: h, depth: 1)
          let threadGroups = MTLSize(
              width: (Int(size.width)  + w - 1) / w,
              height: (Int(size.height) + h - 1) / h,
              depth: 1
          )
          encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadsPerGroup)
          encoder.endEncoding()
          cmdBuf.commit()
          cmdBuf.waitUntilCompleted()

          // 7. Create CIImage and finish
          let outputCI = CIImage(mtlTexture: outTexture, options: nil)?
                           .cropped(to: srcImage.extent) ?? srcImage
          request.finish(with: outputCI, context: nil)
      }

      // 8. Match render settings
      if let track = asset.tracks(withMediaType: .video).first {
          videoComposition.renderSize = track.naturalSize
          videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
      }

      // 9. Apply to the player item
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
  
  func makeTextTexture(_ text: String,
                       font: UIFont,
                       color: UIColor,
                       device: MTLDevice,
                       size: CGSize) -> MTLTexture? {
    // 1) Create a texture descriptor
    let desc = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: .bgra8Unorm,
      width: Int(size.width),
      height: Int(size.height),
      mipmapped: false
    )
    desc.usage = [.shaderRead, .shaderWrite]
    guard let texture = device.makeTexture(descriptor: desc) else { return nil }
    
    // 2) Create a CoreGraphics context that draws directly into that texture
    let bytesPerRow = 4 * Int(size.width)
    let region = MTLRegionMake2D(0, 0, Int(size.width), Int(size.height))
    let rawData = [UInt8](repeating: 0, count: bytesPerRow * Int(size.height))
    rawData.withUnsafeBytes { ptr in
      guard let ctx = CGContext(
        data: UnsafeMutableRawPointer(mutating: ptr.baseAddress!),
        width: Int(size.width),
        height: Int(size.height),
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      ) else { return }
      
      // Clear & flip
      ctx.clear(CGRect(origin: .zero, size: size))
      ctx.translateBy(x: 0, y: size.height)
      ctx.scaleBy(x: 1, y: -1)
      
      // Draw your text
      let attrs: [NSAttributedString.Key:Any] = [
        .font: font,
        .foregroundColor: color
      ]
      let attrString = NSAttributedString(string: text, attributes: attrs)
      let textRect = CGRect(origin: .zero, size: size)
      attrString.draw(in: textRect)
      
      // Copy pixels into the Metal texture
      texture.replace(region: region,
                      mipmapLevel: 0,
                      withBytes: ptr.baseAddress!,
                      bytesPerRow: bytesPerRow)
    }
    return texture
  }
  
  deinit {
    NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
  }
}
