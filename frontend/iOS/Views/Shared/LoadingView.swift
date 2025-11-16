//
//  LoadingView.swift
//  VibeZ iOS
//
//  Loading overlay view with VibeZ theme
//

import SwiftUI

struct LoadingView: View {
	var body: some View {
		ZStack {
			Color.black.opacity(0.4)
				.ignoresSafeArea()
			
			VStack(spacing: 16) {
				ProgressView()
					.scaleEffect(1.5)
					.tint(Color("VibeZGold"))
				
				Text("Loading...")
					.font(.headline)
					.foregroundColor(.white)
			}
			.padding(24)
			.background(
				RoundedRectangle(cornerRadius: 16)
					.fill(Color("VibeZDeep").opacity(0.95))
					.overlay(
						RoundedRectangle(cornerRadius: 16)
							.stroke(Color("VibeZGold").opacity(0.3), lineWidth: 1)
					)
			)
			.shadow(color: Color.black.opacity(0.3), radius: 20)
		}
		.transition(.opacity)
	}
}

#Preview {
	LoadingView()
}

