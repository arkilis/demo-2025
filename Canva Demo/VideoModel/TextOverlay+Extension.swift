//
//  TextOverlay+Extension.swift
//  Canva Demo
//
//  Created by Ben Liu on 22/6/2025.
//

import UIKit
import AVFoundation

extension VideoPlayerViewModel {
  
  // Adds text overlay to the current video
  func addTextOverlay(text: String,
                      position: TextPosition = .bottomCenter,
                      fontSize: CGFloat = 36,
                      textColor: UIColor = .white,
                      backgroundColor: UIColor = .black.withAlphaComponent(0.5),
                      startTime: CMTime = .zero,
                      duration: CMTime? = nil) {
    
    guard let currentItem = player.currentItem else {
      print("❌ No current player item")
      return
    }
    
    let asset = currentItem.asset
    let videoDuration = duration ?? asset.duration
    
    // Create video composition
    let videoComposition = AVMutableVideoComposition(asset: asset) { request in
      let sourceImage = request.sourceImage
      let renderSize = sourceImage.extent.size
      
      // Check if we should show text at this time
      let currentTime = request.compositionTime
      let endTime = startTime + videoDuration
      let shouldShowText = currentTime >= startTime && currentTime <= endTime
      
      if shouldShowText {
        // Create text overlay
        if let textImage = self.createTextImage(
          text: text,
          fontSize: fontSize,
          textColor: textColor,
          backgroundColor: backgroundColor,
          renderSize: renderSize,
          position: position
        ) {
          // Composite text over video
          let compositedImage = textImage.composited(over: sourceImage)
          request.finish(with: compositedImage, context: nil)
        } else {
          request.finish(with: sourceImage, context: nil)
        }
      } else {
        // No text overlay, return original image
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
    print("✅ Text overlay added: '\(text)' from \(startTime.seconds)s for \(videoDuration.seconds)s")
  }
  
  // MARK: - Helper Methods
  private func createTextImage(text: String,
                               fontSize: CGFloat,
                               textColor: UIColor,
                               backgroundColor: UIColor,
                               renderSize: CGSize,
                               position: TextPosition) -> CIImage? {
    
    // Create attributed string
    let attributes: [NSAttributedString.Key: Any] = [
      .font: UIFont.boldSystemFont(ofSize: fontSize),
      .foregroundColor: textColor,
      .strokeColor: UIColor.black,
      .strokeWidth: -2.0 // Negative for fill and stroke
    ]
    
    let attributedString = NSAttributedString(string: text, attributes: attributes)
    
    // Calculate text size
    let textSize = attributedString.boundingRect(
      with: CGSize(width: renderSize.width * 0.8, height: .greatestFiniteMagnitude),
      options: [.usesLineFragmentOrigin, .usesFontLeading],
      context: nil
    ).size
    
    // Add padding
    let padding: CGFloat = 16
    let backgroundSize = CGSize(
      width: textSize.width + padding * 2,
      height: textSize.height + padding * 2
    )
    
    // Create graphics context
    UIGraphicsBeginImageContextWithOptions(backgroundSize, false, 0)
    guard let context = UIGraphicsGetCurrentContext() else {
      UIGraphicsEndImageContext()
      return nil
    }
    
    // Draw background
    context.setFillColor(backgroundColor.cgColor)
    context.fill(CGRect(origin: .zero, size: backgroundSize))
    
    // Draw text
    let textRect = CGRect(
      x: padding,
      y: padding,
      width: textSize.width,
      height: textSize.height
    )
    attributedString.draw(in: textRect)
    
    // Get image
    guard let textUIImage = UIGraphicsGetImageFromCurrentImageContext() else {
      UIGraphicsEndImageContext()
      return nil
    }
    UIGraphicsEndImageContext()
    
    // Convert to CIImage
    guard let cgImage = textUIImage.cgImage else { return nil }
    let textImage = CIImage(cgImage: cgImage)
    
    // Calculate position
    let textPosition = calculateTextPosition(
      position: position,
      textSize: backgroundSize,
      renderSize: renderSize
    )
    
    // Position the text
    let positionedText = textImage.transformed(
      by: CGAffineTransform(
        translationX: textPosition.x,
        y: renderSize.height - textPosition.y - backgroundSize.height
      )
    )
    
    return positionedText
  }
  
  private func calculateTextPosition(position: TextPosition,
                                     textSize: CGSize,
                                     renderSize: CGSize) -> CGPoint {
    let margin: CGFloat = 20
    
    switch position {
    case .topLeft:
      return CGPoint(x: margin, y: margin)
    case .topCenter:
      return CGPoint(x: (renderSize.width - textSize.width) / 2, y: margin)
    case .topRight:
      return CGPoint(x: renderSize.width - textSize.width - margin, y: margin)
    case .centerLeft:
      return CGPoint(x: margin, y: (renderSize.height - textSize.height) / 2)
    case .center:
      return CGPoint(
        x: (renderSize.width - textSize.width) / 2,
        y: (renderSize.height - textSize.height) / 2
      )
    case .centerRight:
      return CGPoint(
        x: renderSize.width - textSize.width - margin,
        y: (renderSize.height - textSize.height) / 2
      )
    case .bottomLeft:
      return CGPoint(x: margin, y: renderSize.height - textSize.height - margin)
    case .bottomCenter:
      return CGPoint(
        x: (renderSize.width - textSize.width) / 2,
        y: renderSize.height - textSize.height - margin
      )
    case .bottomRight:
      return CGPoint(
        x: renderSize.width - textSize.width - margin,
        y: renderSize.height - textSize.height - margin
      )
    case .custom(let x, let y):
      return CGPoint(
        x: x * renderSize.width,
        y: y * renderSize.height
      )
    }
  }
  
  // MARK: - Convenience Methods
  
  /// Add text for the entire video duration
  func addTextOverlay(text: String) {
    addTextOverlay(text: text, position: .bottomCenter)
  }
  
  /// Add text at specific time range
  func addTextOverlay(text: String, from startTime: Double, for duration: Double) {
    addTextOverlay(
      text: text,
      startTime: CMTime(seconds: startTime, preferredTimescale: 600),
      duration: CMTime(seconds: duration, preferredTimescale: 600)
    )
  }
  
  /// Add multiple text overlays at different times
  func addTextOverlays(_ textOverlays: [(text: String, startTime: Double, duration: Double)]) {
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
      
      // Check each text overlay
      for overlay in textOverlays {
        let startTime = CMTime(seconds: overlay.startTime, preferredTimescale: 600)
        let endTime = startTime + CMTime(seconds: overlay.duration, preferredTimescale: 600)
        
        if currentTime >= startTime && currentTime <= endTime {
          if let textImage = self.createTextImage(
            text: overlay.text,
            fontSize: 36,
            textColor: .white,
            backgroundColor: .black.withAlphaComponent(0.5),
            renderSize: renderSize,
            position: .bottomCenter
          ) {
            resultImage = textImage.composited(over: resultImage)
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
    print("✅ Added \(textOverlays.count) text overlays")
  }
  
}
