//
//  BottomToolbarView.swift
//  Canva Demo
//
//  Created by Ben Liu on 22/6/2025.
//
import SwiftUI
import Foundation

struct BottomToolbarView<VideoPlayerViewModel: VideoPlayerViewModelProtocol>: View {
  @ObservedObject var viewModel: VideoPlayerViewModel
  @Binding var showingFilterSheet: Bool
  @Binding var showingAddVideoSheet: Bool
  @Binding var showingAddMusicSheet: Bool
  
  var body: some View {
    HStack {
      Spacer()
      VStack(spacing: 4) {
        Image(systemName: Constants.iconAddEffect)
        Text(Constants.tabMenuAddEffect).font(.caption)
      }
      .toolbarButton {
        showingFilterSheet = true
      }
      Spacer()
      VStack(spacing: 4) {
        Image(systemName: Constants.iconAddVideo)
        Text(Constants.tabMenuAddVideo).font(.caption)
      }
      .toolbarButton {
        showingAddVideoSheet = true
      }
      Spacer()
      VStack(spacing: 4) {
        Image(systemName: Constants.iconAddText)
        Text(Constants.tabMenuAddText).font(.caption)
      }
      .toolbarButton {
        viewModel.addTextOverlay(
          text: Constants.textPlaceholder,
          position: .center,
          fontSize: 50,
          textColor: .white,
          backgroundColor: .clear,
          startTime: .zero,
          duration: nil
        )
      }
      Spacer()
      VStack(spacing: 4) {
        Image(systemName: Constants.iconAddImage)
        Text(Constants.tabMenuAddImage).font(.caption)
      }
      .toolbarButton {
        viewModel.addImageOverlay(
          imageName: Constants.imagePlaceholder,
          position: .center,
          size: .medium,
          opacity: 1.0,
          startTime: .zero,
          duration: nil
        )
      }
      Spacer()
      VStack(spacing: 4) {
        Image(systemName: Constants.iconAddMusic)
        Text(Constants.tabMenuAddMusic).font(.caption)
      }
      .toolbarButton {
        showingAddMusicSheet = true
      }
      Spacer()
      VStack(spacing: 4) {
        Image(systemName: Constants.iconRotate)
        Text(Constants.tabMenuRotate).font(.caption)
      }
      .toolbarButton {
        viewModel.rotate()
      }
      Spacer()
    }
    .padding(.vertical, 8)
    .background(Color(UIColor.systemBackground))
  }
}
