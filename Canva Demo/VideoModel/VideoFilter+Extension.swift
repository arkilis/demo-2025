//
//  VideoFilter+Extension.swift
//  Canva Demo
//
//  Created by Ben Liu on 22/6/2025.
//

import AVFoundation
import CoreImage

extension VideoPlayerViewModel {
  
  /// Add Video Filters
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
    
    timelineThumbnails.removeAll()
    generateTimelineThumbnails()
  }
}
