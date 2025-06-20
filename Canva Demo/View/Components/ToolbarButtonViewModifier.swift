//
//  ToolbarButtonViewModifier.swift
//  Canva Demo
//
//  Created by Ben Liu on 21/6/2025.
//

import SwiftUI

struct ToolbarButtonModifier: ViewModifier {
  let action: () -> Void
  func body(content: Content) -> some View {
    Button(action: action) {
      content
    }
    .foregroundColor(.black)
  }
}

extension View {
  func toolbarButton(action: @escaping () -> Void) -> some View {
    self.modifier(ToolbarButtonModifier(action: action))
  }
}
