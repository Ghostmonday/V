import SwiftUI

/// Emoji Picker Component
/// Native iOS emoji picker for reactions
struct EmojiPickerView: View {
    let onSelect: (String) -> Void
    
    private let emojis = ["👍", "❤️", "😂", "😮", "😢", "🎉", "🔥", "👏"]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(emojis, id: \.self) { emoji in
                    Button(action: {
                        onSelect(emoji)
                        HapticManager.impact()
                    }) {
                        Text(emoji)
                            .font(.system(size: 24))
                    }
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 50)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(8)
    }
}

/// Haptic Feedback Helper
struct HapticManager {
    static func impact() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

#Preview {
    EmojiPickerView { emoji in
        print("Selected: \(emoji)")
    }
    .padding()
}

