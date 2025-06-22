//
//  InformationSheetView.swift
//  Canva Demo
//
//  Created by Ben Liu on 22/6/2025.
//

import SwiftUI
import Foundation

/// Info sheet showing application details.
struct InfoSheetView: View {
  @Binding var isPresented: Bool
  
  var body: some View {
    VStack(spacing: 20) {
      Text(Constants.infoSheetTitle)
        .font(.headline)
        .fontWeight(.bold)
        .multilineTextAlignment(.center)
      
      VStack(alignment: .center, spacing: 10) {
        Text(Constants.infoThankYou)
          .multilineTextAlignment(.center)
          .lineLimit(nil)
          .fixedSize(horizontal: false, vertical: true)
        
        HStack {
          Text(Constants.infoApplicantLabel).bold()
          Text(Constants.infoApplicantName)
        }
        
        HStack {
          Text(Constants.infoEmailLabel).bold()
          if let url = URL(string: "mailto:\(Constants.infoEmailAddress)?subject=You%20are%20hired!") {
            Link(destination: url) {
              Text(Constants.infoEmailAddress)
                .foregroundColor(.blue)
                .underline()
            }
          } else {
            Text(Constants.infoEmailAddress)
          }
        }
        
        HStack {
          Text(Constants.infoPhoneLabel).bold()
          if let url = URL(string: "tel://\(Constants.infoPhoneNumber)") {
            Link(destination: url) {
              Text(Constants.infoPhoneNumber)
                .foregroundColor(.blue)
                .underline()
            }
          } else {
            Text(Constants.infoPhoneNumber)
          }
        }
      }
      
      Button(Constants.buttonOK) {
        isPresented = false
      }
      .buttonStyle(.borderedProminent)
      .frame(width: 200)
    }
    .padding()
    .presentationDetents([.height(280)])
  }
}
