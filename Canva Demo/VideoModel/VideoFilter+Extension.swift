//
//  VideoFilter+Extension.swift
//  Canva Demo
//
//  Created by Ben Liu on 22/6/2025.
//

import AVFoundation
import CoreImage
import Metal
import MetalKit
import UIKit

extension VideoPlayerViewModel {
  
  /// Applies a grayscale filter using Metal shader over the current video item.
  func applyGrayscale() {
    guard let currentItem = player.currentItem else { return }
    let asset = currentItem.asset
    
    // Setup Metal device and command queue
    guard let device = MTLCreateSystemDefaultDevice(),
          let commandQueue = device.makeCommandQueue() else {
      print("❌ Failed to create Metal device")
      return
    }
    
    // Load the Metal library and shader function
    guard let defaultLibrary = device.makeDefaultLibrary(),
          let grayscaleFunction = defaultLibrary.makeFunction(name: "grayscaleShader") else {
      print("❌ Failed to load Metal shader function")
      return
    }
    
    // Create compute pipeline state
    let pipelineState: MTLComputePipelineState
    do {
      pipelineState = try device.makeComputePipelineState(function: grayscaleFunction)
    } catch {
      print("❌ Failed to create compute pipeline state: \(error)")
      return
    }
    
    // Build a video composition that applies the Metal shader
    let videoComposition = AVMutableVideoComposition(asset: asset) { request in
      let sourceImage = request.sourceImage
      let extent = sourceImage.extent
      
      // Convert CIImage to Metal texture
      guard let inputTexture = self.createMetalTexture(from: sourceImage, device: device),
            let outputTexture = self.createEmptyMetalTexture(size: extent.size, device: device) else {
        request.finish(with: sourceImage, context: nil)
        return
      }
      
      // Create command buffer and encoder
      guard let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeComputeCommandEncoder() else {
        request.finish(with: sourceImage, context: nil)
        return
      }
      
      // Configure the compute encoder
      encoder.setComputePipelineState(pipelineState)
      encoder.setTexture(inputTexture, index: 0)
      encoder.setTexture(outputTexture, index: 1)
      
      // Calculate thread group sizes
      let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
      let threadGroups = MTLSize(
        width: (inputTexture.width + threadGroupSize.width - 1) / threadGroupSize.width,
        height: (inputTexture.height + threadGroupSize.height - 1) / threadGroupSize.height,
        depth: 1
      )
      
      // Dispatch the compute shader
      encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
      encoder.endEncoding()
      
      // Commit and wait for completion
      commandBuffer.commit()
      commandBuffer.waitUntilCompleted()
      
      // Convert Metal texture back to CIImage
      if let resultImage = self.createCIImage(from: outputTexture) {
        request.finish(with: resultImage, context: nil)
      } else {
        request.finish(with: sourceImage, context: nil)
      }
    }
    
    // Match render settings
    if let track = asset.tracks(withMediaType: .video).first {
      videoComposition.renderSize = track.naturalSize
      videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
    }
    
    // Apply to player item
    currentItem.videoComposition = videoComposition
    
    timelineThumbnails.removeAll()
    generateTimelineThumbnails()
  }
  
  // MARK: - Metal Texture Helper Methods
  
  /// Creates a Metal texture from a CIImage
  private func createMetalTexture(from ciImage: CIImage, device: MTLDevice) -> MTLTexture? {
    let context = CIContext(mtlDevice: device)
    
    let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: .rgba8Unorm,
      width: Int(ciImage.extent.width),
      height: Int(ciImage.extent.height),
      mipmapped: false
    )
    textureDescriptor.usage = [.shaderRead, .shaderWrite]
    
    guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
      return nil
    }
    
    // Render CIImage to Metal texture
    context.render(ciImage, to: texture, commandBuffer: nil, bounds: ciImage.extent, colorSpace: CGColorSpaceCreateDeviceRGB())
    
    return texture
  }
  
  /// Creates an empty Metal texture for output
  private func createEmptyMetalTexture(size: CGSize, device: MTLDevice) -> MTLTexture? {
    let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: .rgba8Unorm,
      width: Int(size.width),
      height: Int(size.height),
      mipmapped: false
    )
    textureDescriptor.usage = [.shaderRead, .shaderWrite]
    
    return device.makeTexture(descriptor: textureDescriptor)
  }
  
  /// Creates a CIImage from a Metal texture
  private func createCIImage(from texture: MTLTexture) -> CIImage? {
    let context = CIContext()
    return CIImage(mtlTexture: texture, options: [.colorSpace: CGColorSpaceCreateDeviceRGB()])
  }
}

// MARK: - Alternative Metal Implementation with CIContext Rendering

extension VideoPlayerViewModel {
  
  /// Alternative Metal shader implementation using CIContext for better integration
  func applyGrayscaleWithMetalCIContext() {
    guard let currentItem = player.currentItem else { return }
    let asset = currentItem.asset
    
    // Setup Metal device and command queue
    guard let device = MTLCreateSystemDefaultDevice(),
          let commandQueue = device.makeCommandQueue() else {
      print("❌ Failed to create Metal device")
      return
    }
    
    // Load the Metal library and shader function
    guard let defaultLibrary = device.makeDefaultLibrary(),
          let grayscaleFunction = defaultLibrary.makeFunction(name: "grayscaleShader") else {
      print("❌ Failed to load Metal shader function")
      return
    }
    
    // Create compute pipeline state
    let pipelineState: MTLComputePipelineState
    do {
      pipelineState = try device.makeComputePipelineState(function: grayscaleFunction)
    } catch {
      print("❌ Failed to create compute pipeline state: \(error)")
      return
    }
    
    // Create CIContext with Metal device for better performance
    let ciContext = CIContext(mtlDevice: device)
    
    // Build a video composition that applies the Metal shader
    let videoComposition = AVMutableVideoComposition(asset: asset) { request in
      let sourceImage = request.sourceImage
      let extent = sourceImage.extent
      
      // Create Metal textures
      guard let inputTexture = self.createMetalTextureFromCIImage(sourceImage, device: device, context: ciContext),
            let outputTexture = self.createEmptyMetalTexture(size: extent.size, device: device) else {
        request.finish(with: sourceImage, context: nil)
        return
      }
      
      // Create command buffer and encoder
      guard let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeComputeCommandEncoder() else {
        request.finish(with: sourceImage, context: nil)
        return
      }
      
      // Configure the compute encoder
      encoder.setComputePipelineState(pipelineState)
      encoder.setTexture(inputTexture, index: 0)
      encoder.setTexture(outputTexture, index: 1)
      
      // Calculate thread group sizes
      let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
      let threadGroups = MTLSize(
        width: (inputTexture.width + threadGroupSize.width - 1) / threadGroupSize.width,
        height: (inputTexture.height + threadGroupSize.height - 1) / threadGroupSize.height,
        depth: 1
      )
      
      // Dispatch the compute shader
      encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
      encoder.endEncoding()
      
      // Commit and wait for completion
      commandBuffer.commit()
      commandBuffer.waitUntilCompleted()
      
      // Convert Metal texture back to CIImage using the same context
      if let resultImage = self.createCIImageFromMetalTexture(outputTexture, context: ciContext) {
        request.finish(with: resultImage, context: ciContext)
      } else {
        request.finish(with: sourceImage, context: nil)
      }
    }
    
    // Match render settings
    if let track = asset.tracks(withMediaType: .video).first {
      videoComposition.renderSize = track.naturalSize
      videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
    }
    
    // Apply to player item
    currentItem.videoComposition = videoComposition
    
    timelineThumbnails.removeAll()
    generateTimelineThumbnails()
  }
  
  // MARK: - Improved Metal Texture Helper Methods
  
  /// Creates a Metal texture from CIImage using CIContext for better performance
  private func createMetalTextureFromCIImage(_ ciImage: CIImage, device: MTLDevice, context: CIContext) -> MTLTexture? {
    let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: .rgba8Unorm,
      width: Int(ciImage.extent.width),
      height: Int(ciImage.extent.height),
      mipmapped: false
    )
    textureDescriptor.usage = [.shaderRead, .shaderWrite]
    
    guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
      return nil
    }
    
    // Use the same context for rendering to avoid context switching overhead
    context.render(ciImage, to: texture, commandBuffer: nil, bounds: ciImage.extent, colorSpace: CGColorSpaceCreateDeviceRGB())
    
    return texture
  }
  
  /// Creates a CIImage from Metal texture using the provided context
  private func createCIImageFromMetalTexture(_ texture: MTLTexture, context: CIContext) -> CIImage? {
    return CIImage(mtlTexture: texture, options: [.colorSpace: CGColorSpaceCreateDeviceRGB()])
  }
}
