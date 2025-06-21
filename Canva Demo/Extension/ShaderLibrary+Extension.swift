//
//  ShaderLibrary+Extension.swift
//  Canva Demo
//
//  Created by Ben Liu on 21/6/2025.
//

import SwiftUI

extension ShaderLibrary {
  
  static var moduleLibrary: ShaderLibrary { .bundle(.main) }
  
  static func grayscaleShader() -> Shader {
    moduleLibrary.grayscale()
  }
  
  static func invertColorShader() -> Shader {
    moduleLibrary.invertColor()
  }
}

