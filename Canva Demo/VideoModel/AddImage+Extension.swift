//
//  AddImage+Extension.swift
//  Canva Demo
//
//  Created by Ben Liu on 22/6/2025.
//

import AVFoundation
import UIKit

extension VideoPlayerViewModel {
  
  /// Add image overlay to the current video
  func addImageOverlay(imageName: String,
                       position: ElementPosition = .topRight,
                       size: ImageSize = .small,
                       opacity: Float = 1.0,
                       startTime: CMTime = .zero,
                       duration: CMTime? = nil) {
    
    guard let currentItem = player.currentItem else {
      print("❌ No current player item")
      return
    }
    
    // Load image from bundle
    guard let overlayImage = UIImage(named: imageName) else {
      print("❌ Could not find image '\(imageName)' in bundle")
      return
    }
    
    let asset = currentItem.asset
    let imageDuration = duration ?? asset.duration
    
    // Create video composition
    let videoComposition = AVMutableVideoComposition(asset: asset) { request in
      let sourceImage = request.sourceImage
      let renderSize = sourceImage.extent.size
      
      // Check if we should show image at this time
      let currentTime = request.compositionTime
      let endTime = startTime + imageDuration
      let shouldShowImage = currentTime >= startTime && currentTime <= endTime
      
      if shouldShowImage {
        // Create image overlay
        if let processedImage = self.createImageOverlay(
          image: overlayImage,
          position: position,
          size: size,
          opacity: opacity,
          renderSize: renderSize
        ) {
          // Composite image over video
          let compositedImage = processedImage.composited(over: sourceImage)
          request.finish(with: compositedImage, context: nil)
        } else {
          request.finish(with: sourceImage, context: nil)
        }
      } else {
        // No image overlay, return original image
        request.finish(with: sourceImage, context: nil)
      }
    }
    
    // Set video composition properties
    if let videoTrack = asset.tracks(withMediaType: .video).first {
      videoComposition.renderSize = videoTrack.naturalSize
      videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
    }
    
    // Apply to current item
    currentItem.videoComposition = videoComposition
    print("✅ Image overlay added: '\(imageName)' from \(startTime.seconds)s for \(imageDuration.seconds)s")
  }
  
  // MARK: - Image Position and Size Enums
  

  
  // MARK: - Helper Methods
  
  private func createImageOverlay(image: UIImage,
                                  position: ElementPosition,
                                  size: ImageSize,
                                  opacity: Float,
                                  renderSize: CGSize) -> CIImage? {
    
    guard let cgImage = image.cgImage else {
      print("❌ Failed to get CGImage from UIImage")
      return nil
    }
    
    var ciImage = CIImage(cgImage: cgImage)
    
    // Calculate target size
    let targetSize = calculateImageSize(size: size, originalSize: image.size, renderSize: renderSize)
    
    // Scale image if needed
    if targetSize != image.size {
      let scaleX = targetSize.width / image.size.width
      let scaleY = targetSize.height / image.size.height
      ciImage = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
    }
    
    // Apply opacity
    if opacity < 1.0 {
      ciImage = ciImage.applyingFilter("CIColorMatrix", parameters: [
        "inputAVector": CIVector(x: 0, y: 0, z: 0, w: CGFloat(opacity))
      ])
    }
    
    // Calculate position
    let imagePosition = calculateImagePosition(
      position: position,
      imageSize: targetSize,
      renderSize: renderSize
    )
    
    // Position the image
    let positionedImage = ciImage.transformed(
      by: CGAffineTransform(
        translationX: imagePosition.x,
        y: renderSize.height - imagePosition.y - targetSize.height
      )
    )
    
    return positionedImage
  }
  
  private func calculateImageSize(size: ImageSize,
                                  originalSize: CGSize,
                                  renderSize: CGSize) -> CGSize {
    switch size {
    case .tiny:
      let width = renderSize.width * 0.05
      let aspectRatio = originalSize.height / originalSize.width
      return CGSize(width: width, height: width * aspectRatio)
      
    case .small:
      let width = renderSize.width * 0.1
      let aspectRatio = originalSize.height / originalSize.width
      return CGSize(width: width, height: width * aspectRatio)
      
    case .medium:
      let width = renderSize.width * 0.2
      let aspectRatio = originalSize.height / originalSize.width
      return CGSize(width: width, height: width * aspectRatio)
      
    case .large:
      let width = renderSize.width * 0.3
      let aspectRatio = originalSize.height / originalSize.width
      return CGSize(width: width, height: width * aspectRatio)
      
    case .original:
      // Scale down if too large, otherwise keep original
      let maxWidth = renderSize.width * 0.5
      let maxHeight = renderSize.height * 0.5
      
      if originalSize.width <= maxWidth && originalSize.height <= maxHeight {
        return originalSize
      } else {
        let scaleX = maxWidth / originalSize.width
        let scaleY = maxHeight / originalSize.height
        let scale = min(scaleX, scaleY)
        return CGSize(width: originalSize.width * scale, height: originalSize.height * scale)
      }
      
    case .custom(let width, let height):
      return CGSize(width: width, height: height)
      
    case .percentage(let widthPercent, let heightPercent):
      return CGSize(
        width: renderSize.width * widthPercent,
        height: renderSize.height * heightPercent
      )
    }
  }
  
  private func calculateImagePosition(position: ElementPosition,
                                      imageSize: CGSize,
                                      renderSize: CGSize) -> CGPoint {
    let margin: CGFloat = 20
    
    switch position {
    case .topLeft:
      return CGPoint(x: margin, y: margin)
    case .topCenter:
      return CGPoint(x: (renderSize.width - imageSize.width) / 2, y: margin)
    case .topRight:
      return CGPoint(x: renderSize.width - imageSize.width - margin, y: margin)
    case .centerLeft:
      return CGPoint(x: margin, y: (renderSize.height - imageSize.height) / 2)
    case .center:
      return CGPoint(
        x: (renderSize.width - imageSize.width) / 2,
        y: (renderSize.height - imageSize.height) / 2
      )
    case .centerRight:
      return CGPoint(
        x: renderSize.width - imageSize.width - margin,
        y: (renderSize.height - imageSize.height) / 2
      )
    case .bottomLeft:
      return CGPoint(x: margin, y: renderSize.height - imageSize.height - margin)
    case .bottomCenter:
      return CGPoint(
        x: (renderSize.width - imageSize.width) / 2,
        y: renderSize.height - imageSize.height - margin
      )
    case .bottomRight:
      return CGPoint(
        x: renderSize.width - imageSize.width - margin,
        y: renderSize.height - imageSize.height - margin
      )
    case .custom(let x, let y):
      return CGPoint(
        x: x * renderSize.width,
        y: y * renderSize.height
      )
    }
  }
  
  // MARK: - Convenience Methods
  
  /// Add image watermark for the entire video duration
  func addWatermark(imageName: String) {
    addImageOverlay(
      imageName: imageName,
      position: .bottomRight,
      size: .small,
      opacity: 0.7
    )
  }
  
  /// Add logo overlay
  func addLogo(imageName: String, position: ElementPosition = .topLeft, size: ImageSize = .medium) {
    addImageOverlay(
      imageName: imageName,
      position: position,
      size: size,
      opacity: 0.9
    )
  }
  
  /// Add image at specific time range
  func addImageOverlay(imageName: String, from startTime: Double, for duration: Double) {
    addImageOverlay(
      imageName: imageName,
      startTime: CMTime(seconds: startTime, preferredTimescale: 600),
      duration: CMTime(seconds: duration, preferredTimescale: 600)
    )
  }
  
  /// Add multiple image overlays at different times
  func addImageOverlays(_ imageOverlays: [(imageName: String, position: ElementPosition, startTime: Double, duration: Double)]) {
    guard let currentItem = player.currentItem else {
      print("❌ No current player item")
      return
    }
    
    let asset = currentItem.asset
    
    let videoComposition = AVMutableVideoComposition(asset: asset) { request in
      let sourceImage = request.sourceImage
      let renderSize = sourceImage.extent.size
      let currentTime = request.compositionTime
      
      var resultImage = sourceImage
      
      // Check each image overlay
      for overlay in imageOverlays {
        let startTime = CMTime(seconds: overlay.startTime, preferredTimescale: 600)
        let endTime = startTime + CMTime(seconds: overlay.duration, preferredTimescale: 600)
        
        if currentTime >= startTime && currentTime <= endTime {
          if let overlayUIImage = UIImage(named: overlay.imageName),
             let processedImage = self.createImageOverlay(
              image: overlayUIImage,
              position: overlay.position,
              size: .small,
              opacity: 0.8,
              renderSize: renderSize
             ) {
            resultImage = processedImage.composited(over: resultImage)
          }
        }
      }
      
      request.finish(with: resultImage, context: nil)
    }
    
    // Set video composition properties
    if let videoTrack = asset.tracks(withMediaType: .video).first {
      videoComposition.renderSize = videoTrack.naturalSize
      videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
    }
    
    currentItem.videoComposition = videoComposition
    print("✅ Added \(imageOverlays.count) image overlays")
  }
  
  /// Add animated image overlay (for simple animations like fade in/out)
  func addAnimatedImageOverlay(imageName: String,
                               position: ElementPosition = .topRight,
                               size: ImageSize = .small,
                               startTime: Double,
                               duration: Double,
                               animation: ImageAnimation = .fadeInOut) {
    
    guard let currentItem = player.currentItem else {
      print("❌ No current player item")
      return
    }
    
    guard let overlayImage = UIImage(named: imageName) else {
      print("❌ Could not find image '\(imageName)' in bundle")
      return
    }
    
    let asset = currentItem.asset
    let startCMTime = CMTime(seconds: startTime, preferredTimescale: 600)
    let durationCMTime = CMTime(seconds: duration, preferredTimescale: 600)
    
    let videoComposition = AVMutableVideoComposition(asset: asset) { request in
      let sourceImage = request.sourceImage
      let renderSize = sourceImage.extent.size
      let currentTime = request.compositionTime
      let endTime = startCMTime + durationCMTime
      
      if currentTime >= startCMTime && currentTime <= endTime {
        // Calculate animation progress (0.0 to 1.0)
        let progress = (currentTime - startCMTime).seconds / durationCMTime.seconds
        let opacity = self.calculateAnimationOpacity(animation: animation, progress: progress)
        
        if let processedImage = self.createImageOverlay(
          image: overlayImage,
          position: position,
          size: size,
          opacity: Float(opacity),
          renderSize: renderSize
        ) {
          let compositedImage = processedImage.composited(over: sourceImage)
          request.finish(with: compositedImage, context: nil)
        } else {
          request.finish(with: sourceImage, context: nil)
        }
      } else {
        request.finish(with: sourceImage, context: nil)
      }
    }
    
    if let videoTrack = asset.tracks(withMediaType: .video).first {
      videoComposition.renderSize = videoTrack.naturalSize
      videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
    }
    
    currentItem.videoComposition = videoComposition
    print("✅ Animated image overlay added: '\(imageName)' with \(animation)")
  }
  
  // MARK: - Animation Support
  
  enum ImageAnimation {
    case fadeIn
    case fadeOut
    case fadeInOut
    case none
  }
  
  private func calculateAnimationOpacity(animation: ImageAnimation, progress: Double) -> Double {
    switch animation {
    case .fadeIn:
      return progress
    case .fadeOut:
      return 1.0 - progress
    case .fadeInOut:
      if progress < 0.5 {
        return progress * 2.0 // Fade in first half
      } else {
        return (1.0 - progress) * 2.0 // Fade out second half
      }
    case .none:
      return 1.0
    }
  }
}
