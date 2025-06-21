import SwiftUI
import PhotosUI

struct VideoEditorView<VideoPlayerViewModel: VideoPlayerViewModelProtocol>: View {
  
  @State private var selectedVideoURL: URL?
  @State private var isPickerPresented = false
  @State private var exportStatus = ""
  @State private var showingFilterSheet = false
  @State private var showingAddMusicSheet = false
  
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
        Image(systemName: "line.horizontal.3")
        Spacer()
        HStack(spacing: 16) {
          Button(action: {
            if videoPlayerViewModel.isPlaying {
              videoPlayerViewModel.pause()
            } else {
              videoPlayerViewModel.play()
            }
          }) {
            Image(systemName: videoPlayerViewModel.isPlaying ? "pause.fill" : "play.fill")
          }
          Image(systemName: "square.and.arrow.up")
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
      HStack {
        Spacer()
        VStack(spacing: 4) { Image(systemName: "video"); Text("Add Effect").font(.caption) }
          .toolbarButton {
            showingFilterSheet = true
          }
        Spacer()
        VStack(spacing: 4) { Image(systemName: "video.fill"); Text("Add Video").font(.caption) }
        Spacer()
        VStack(spacing: 4) { Image(systemName: "textformat"); Text("Add Text").font(.caption) }
          .toolbarButton {
            videoPlayerViewModel.applyText("Hi there!")
          }
        Spacer()
        VStack(spacing: 4) { Image(systemName: "photo.on.rectangle"); Text("Add Image").font(.caption) }
        Spacer()
        VStack(spacing: 4) { Image(systemName: "music.note"); Text("Add Music").font(.caption) }
          .toolbarButton {
            showingAddMusicSheet = true
          }
        Spacer()
        VStack(spacing: 4) { Image(systemName: "arrow.clockwise"); Text("Rotate").font(.caption) }
          .toolbarButton {
            videoPlayerViewModel.rotate()
          }
        
        Spacer()
      }
      .padding(.vertical, 8)
      .background(Color(UIColor.systemBackground))
    }
    .background(Color.white)
    .confirmationDialog(
      "Choose Filter",
      isPresented: $showingFilterSheet,
      titleVisibility: .visible
    ) {
      Button("Black and White") {
        videoPlayerViewModel.applyGrayscale()
      }
    }
    .confirmationDialog(
      "Add Background Music",
      isPresented: $showingAddMusicSheet,
      titleVisibility: .visible
    ) {
      Button("Music 1") {
        videoPlayerViewModel.addBackgroundMusic(name: "background1")
      }
      Button("Music 2") {
        videoPlayerViewModel.addBackgroundMusic(name: "background2")
      }
      Button("Music 3") {
        videoPlayerViewModel.addBackgroundMusic(name: "background3")
      }
    }
  }
}
