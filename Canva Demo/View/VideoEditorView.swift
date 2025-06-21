import Foundation
import SwiftUI
import PhotosUI

enum ActiveDialog: Identifiable {
  case filter, addVideo, addMusic
  var id: Int { hashValue }
  var title: String {
    switch self {
    case .filter: return Constants.sheetVideoFilter
    case .addVideo: return Constants.sheetAddVideo
    case .addMusic: return Constants.sheetAddMuisic
    }
  }
}

struct VideoEditorView<VideoPlayerViewModel: VideoPlayerViewModelProtocol>: View {
  
  @State private var selectedVideoURL: URL?
  @State private var isPickerPresented = false
  @State private var exportStatus = ""
  @State private var activeDialog: ActiveDialog?
  
  @StateObject private var videoPlayerViewModel: VideoPlayerViewModel
  
  
  // Sample thumbnails for timeline segments
  let thumbnails = Array(1...5).map { "thumb\($0)" }
  
  public init(videoPlayerViewModel: VideoPlayerViewModel) {
    _videoPlayerViewModel = StateObject(wrappedValue: videoPlayerViewModel)
  }
  
  var body: some View {
    VStack(spacing: 0) {
      // Top toolbar
      HStack {
        Image(systemName: Constants.iconMenu)
        Spacer()
        HStack(spacing: 16) {
          Button(action: {
            if videoPlayerViewModel.isPlaying {
              videoPlayerViewModel.pause()
            } else {
              videoPlayerViewModel.play()
            }
          }) {
            Image(systemName: videoPlayerViewModel.isPlaying ? Constants.iconPlay : Constants.iconPause)
          }
          Image(systemName: Constants.iconShare)
        }
      }
      .foregroundColor(.white)
      .padding(.horizontal)
      .padding(.top, 8) // Simplified padding
      .padding(.bottom, 8)
      .background(LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]),
                                 startPoint: .leading,
                                 endPoint: .trailing))
      
      // Video preview
      ZStack {
        Color.black
        VideoPlayerView(viewModel: videoPlayerViewModel)
          .rotationEffect(.degrees(videoPlayerViewModel.rotationAngle))
      }
      
      // Timeline
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(thumbnails, id: \.self) { name in
            Rectangle()
              .fill(Color.gray)
              .frame(width: 80, height: 60)
              .overlay(Text(name).foregroundColor(.white).font(.caption))
              .cornerRadius(4)
          }
        }
        .padding(.horizontal)
      }
      .frame(height: 80)
      .background(Color(UIColor.systemGray6))
      
      Spacer()
      
      // Bottom toolbar
      BottomToolbarView(
        viewModel: videoPlayerViewModel,
        showingFilterSheet: Binding(
          get: { activeDialog == .filter },
          set: { if $0 { activeDialog = .filter } else { activeDialog = nil } }
        ),
        showingAddVideoSheet: Binding(
          get: { activeDialog == .addVideo },
          set: { if $0 { activeDialog = .addVideo } else { activeDialog = nil } }
        ),
        showingAddMusicSheet: Binding(
          get: { activeDialog == .addMusic },
          set: { if $0 { activeDialog = .addMusic } else { activeDialog = nil } }
        )
      )
      .padding(.vertical, 8)
      .background(Color(UIColor.systemBackground))
    }
    .background(Color.white)
    .confirmationDialog(
      activeDialog?.title ?? "",
      isPresented: Binding<Bool>(
        get: { activeDialog != nil },
        set: { if !$0 { activeDialog = nil } }
      ),
      titleVisibility: .visible
    ) {
      switch activeDialog {
      case .filter:
        Button(Constants.sheetButtonFilterBlackWhite) { videoPlayerViewModel.applyGrayscale() }
      case .addVideo:
        Button(Constants.sheetButtonCat) { videoPlayerViewModel.appendVideo(name: Constants.resourceCat) }
        Button(Constants.sheetButtonDog) { videoPlayerViewModel.appendVideo(name: Constants.resourceDog) }
      case .addMusic:
        Button(Constants.sheetButtonMusic1) { videoPlayerViewModel.addBackgroundMusic(name: Constants.resourceBackground1) }
        Button(Constants.sheetButtonMusic2) { videoPlayerViewModel.addBackgroundMusic(name: Constants.resourceBackground2) }
        Button(Constants.sheetButtonMusic3) { videoPlayerViewModel.addBackgroundMusic(name: Constants.resourceBackground3) }
      case .none:
        EmptyView()
      }
    }
  }
}
