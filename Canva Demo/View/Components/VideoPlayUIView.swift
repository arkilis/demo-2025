//
//  VideoPlayUIView.swift
//  Canva Demo
//
//  Created by Ben Liu on 21/6/2025.
//

import UIKit
import SwiftUI
import AVFoundation

class VideoPlayerUIView: UIView {
  
  private let playerLayer = AVPlayerLayer()
  
  var player: AVPlayer? {
    didSet {
      playerLayer.player = player
    }
  }
  
  override class var layerClass: AnyClass {
    AVPlayerLayer.self
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    self.layer.addSublayer(playerLayer)
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    self.layer.addSublayer(playerLayer)
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    playerLayer.frame = bounds
  }
}


struct VideoPlayerView<VM: VideoPlayerViewModelProtocol>: UIViewRepresentable {
  @ObservedObject var viewModel: VM
  
  func makeUIView(context: Context) -> VideoPlayerUIView {
    let view = VideoPlayerUIView(frame: .zero)
    view.player = viewModel.player
    return view
  }
  
  func updateUIView(_ uiView: VideoPlayerUIView, context: Context) {
    uiView.player = viewModel.player
  }
}
