import SwiftUI
import AVFoundation

struct OnboardingFlowView: View {
    @Environment(\.dismiss) var dismiss
    @State private var currentPage = 0
    @State private var showSin = false
    @State private var sinSpeaking = false
    
    let synthesizer = AVSpeechSynthesizer()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [.black, Color(red: 0.1, green: 0.1, blue: 0.3)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                if currentPage == 0 {
                    welcomePage
                } else if currentPage == 1 {
                    roomsPage
                } else if currentPage == 2 {
                    voicePage
                } else if showSin {
                    sinIntroductionPage
                }
            }
        }
    }
    
    var welcomePage: some View {
        VStack(spacing: 30) {
            Text("Welcome to VibeZ")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Button("Let's go") {
                withAnimation {
                    currentPage = 1
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
    
    var roomsPage: some View {
        VStack(spacing: 30) {
            Text("Tap Rooms to join")
                .font(.title)
                .foregroundColor(.white)
            
            Text("People are live right now")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Button("Next") {
                withAnimation {
                    currentPage = 2
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    var voicePage: some View {
        VStack(spacing: 30) {
            Text("Hold mic for voice")
                .font(.title)
                .foregroundColor(.white)
            
            Text("Tap speaker to listen")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Button("Meet Sin") {
                showSin = true
                speakSinGreeting()
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    var sinIntroductionPage: some View {
        VStack(spacing: 40) {
            // Sin avatar - floating circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)
                .overlay(
                    Text("Sin")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                )
                .shadow(color: .yellow.opacity(0.5), radius: 20)
                .scaleEffect(sinSpeaking ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: sinSpeaking)
            
            Text("Hey, it's Sin. Ready to chat?")
                .font(.title2)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding()
            
            Button("Start Chatting") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .fullScreenCover(isPresented: $showSin) {
            // Full screen Sin interaction
        }
    }
    
    func speakSinGreeting() {
        let utterance = AVSpeechUtterance(string: "Hey, it's Sin. Ready to chat?")
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        
        sinSpeaking = true
        synthesizer.speak(utterance)
        
        // Stop animation after speech
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            sinSpeaking = false
        }
    }
}

#Preview {
    OnboardingFlowView()
}

