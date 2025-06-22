import Foundation
import SwiftUI
import PhotosUI
import UIKit

enum ActiveDialog: Identifiable {
  case filter, addVideo, addMusic
  var id: Int { hashValue }
  var title: String {
    switch self {
    case .filter:   return Constants.sheetVideoFilter
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
  
  // new state for export/loading
  @State private var shareURL: URL?
  @State private var isShowingShareSheet = false
  @State private var isExporting = false
  
  @StateObject private var videoPlayerViewModel: VideoPlayerViewModel
  
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
          // Play / Pause
          Button {
            if videoPlayerViewModel.isPlaying {
              videoPlayerViewModel.pause()
            } else {
              videoPlayerViewModel.play()
            }
          } label: {
            Image(systemName: videoPlayerViewModel.isPlaying
                  ? Constants.iconPlay
                  : Constants.iconPause)
          }

          // Export & Share
          Button {
            isExporting = true
            videoPlayerViewModel.exportCurrentVideo { url in
              isExporting = false
              if let url = url {
                shareURL = url
                isShowingShareSheet = true
              }
            }
          } label: {
            if isExporting {
              ProgressView()
            } else {
              Image(systemName: Constants.iconShare)
            }
          }
          .disabled(isExporting)
        }
      }
      .foregroundColor(.white)
      .padding(.horizontal)
      .padding(.vertical, 8)
      .background(
        LinearGradient(
          gradient: Gradient(colors: [Color.blue, Color.purple]),
          startPoint: .leading,
          endPoint: .trailing
        )
      )
      
      // Video preview
      ZStack {
        Color.black
        VideoPlayerView(viewModel: videoPlayerViewModel)
          .rotationEffect(.degrees(videoPlayerViewModel.rotationAngle))
      }
      
      // Timeline
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(videoPlayerViewModel.timelineThumbnails, id: \.self) { thumbnail in
            Image(uiImage: thumbnail)
              .resizable()
              .aspectRatio(contentMode: .fill)
              .frame(width: 80, height: 60)
              .clipped()
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
          set: { activeDialog = $0 ? .filter : nil }
        ),
        showingAddVideoSheet: Binding(
          get: { activeDialog == .addVideo },
          set: { activeDialog = $0 ? .addVideo : nil }
        ),
        showingAddMusicSheet: Binding(
          get: { activeDialog == .addMusic },
          set: { activeDialog = $0 ? .addMusic : nil }
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
        Button(Constants.sheetButtonFilterBlackWhite) {
          videoPlayerViewModel.applyGrayscale()
        }
      case .addVideo:
        Button(Constants.sheetButtonCat) {
          videoPlayerViewModel.appendVideo(name: Constants.resourceCat)
        }
        Button(Constants.sheetButtonDog) {
          videoPlayerViewModel.appendVideo(name: Constants.resourceDog)
        }
      case .addMusic:
        Button(Constants.sheetButtonMusic1) {
          videoPlayerViewModel.addBackgroundMusic(name: Constants.resourceBackground1)
        }
        Button(Constants.sheetButtonMusic2) {
          videoPlayerViewModel.addBackgroundMusic(name: Constants.resourceBackground2)
        }
        Button(Constants.sheetButtonMusic3) {
          videoPlayerViewModel.addBackgroundMusic(name: Constants.resourceBackground3)
        }
      case .none:
        EmptyView()
      }
    }
    // Half-screen share sheet
    .sheet(isPresented: $isShowingShareSheet) {
      if let url = shareURL {
        ActivityView(activityItems: [url])
          .presentationDetents([.medium])
          .presentationDragIndicator(.visible)
      }
    }
    .onAppear {
      videoPlayerViewModel.generateTimelineThumbnails()
    }
  }
}
