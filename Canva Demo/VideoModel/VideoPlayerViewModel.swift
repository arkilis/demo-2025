//
//  VideoEditorViewModel.swift
//  Canva Demo
//
//  Created by Ben Liu on 21/6/2025.
//
import Combine
import AVFoundation

protocol VideoEditorViewModelProtocol: ObservableObject {
  var player: AVPlayer { get }
  var isPlaying: Bool { get }
  func play()
  func pause()
}

final class VideoPlayerViewModel: VideoEditorViewModelProtocol {
  @Published var player: AVPlayer
  
  @Published var isPlaying: Bool = false

  init() {
      guard let url = Bundle.main.url(forResource: "sample", withExtension: "mp4") else {
          fatalError("sample.mp4 not found in bundle")
      }
      self.player = AVPlayer(url: url)
  }
  
  func play() {
    player.play()
    isPlaying = true
  }
  
  func pause() {
    player.pause()
    isPlaying = false
  }
}
