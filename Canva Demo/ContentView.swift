//
//  ContentView.swift
//  Canva Demo
//
//  Created by Ben Liu on 21/6/2025.
//

import SwiftUI

struct ContentView: View {
  var body: some View {
    VStack {
      VideoEditorView(viewModel: VideoPlayerViewModel())
    }
  }
}

#Preview {
  ContentView()
}
