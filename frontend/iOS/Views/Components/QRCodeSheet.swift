import SwiftUI

struct QRCodeSheet: View {
    @Environment(\.dismiss) var dismiss
    let inviteLink = "https://vibez.app/invite/alex-chen"
    
    var body: some View {
        ZStack {
            VibezBackground()
            
            VStack(spacing: 30) {
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 40, height: 4)
                    .padding(.top, 20)
                
                Text("Invite to VibeZ")
                    .vibezHeaderMedium()
                
                // QR Code Card
                GlassCard {
                    VStack(spacing: 20) {
                        Image(systemName: "qrcode") // Placeholder for actual QR generation
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .frame(width: 200, height: 200)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(16)
                        
                        Text("@alex-chen")
                            .font(VibezTypography.headerSmall)
                            .foregroundColor(Color.Vibez.electricBlue)
                    }
                    .padding()
                }
                .padding(.horizontal, 40)
                
                // Share Link
                Button(action: {
                    // Share logic
                }) {
                    HStack {
                        Text(inviteLink)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        
                        Spacer()
                        
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(Color.Vibez.electricBlue)
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Text("Done")
                        .font(VibezTypography.button)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.Vibez.electricBlue)
                        .cornerRadius(16)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 40)
            }
        }
    }
}

