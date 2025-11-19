import SwiftUI

struct ExploreView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    Text("Explore")
                        .vibezHeaderLarge()
                        .padding(.horizontal)
                        .padding(.top, 60)
                    
                    // Featured Carousel (Hero)
                    FeaturedCarousel()
                        .padding(.bottom, 10)
                    
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Color.Vibez.textSecondary)
                        Text("Search vibes, people, topics...")
                            .foregroundColor(Color.Vibez.textSecondary)
                        Spacer()
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.Vibez.deepVoid.opacity(0.5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal)
                    
                    // Categories
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        CategoryCard(title: "Music", icon: "music.note")
                        CategoryCard(title: "Tech", icon: "cpu")
                        CategoryCard(title: "Gaming", icon: "gamecontroller.fill")
                        CategoryCard(title: "Art", icon: "paintbrush.fill")
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 100)
                }
            }
            .background(VibezBackground())
        }
    }
}

struct CategoryCard: View {
    let title: String
    let icon: String
    
    var body: some View {
        GlassCard {
            VStack {
                Image(systemName: icon)
                    .font(.system(size: 30))
                    .foregroundColor(Color.Vibez.electricBlue)
                    .padding(.bottom, 8)
                Text(title)
                    .font(VibezTypography.bodyMedium)
                    .foregroundColor(Color.Vibez.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
    }
}
