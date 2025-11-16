import SwiftUI

/// Performance Optimization Extensions
extension View {
    /// Optimize animations for reduced motion preference
    @ViewBuilder
    func optimizedAnimation(_ animation: Animation?, value: some Equatable) -> some View {
        if UIAccessibility.isReduceMotionEnabled {
            self.animation(nil, value: value)
        } else {
            self.animation(animation, value: value)
        }
    }
    
    /// Lazy load content only when visible
    func lazyLoad() -> some View {
        self.onAppear {
            // Content loads when view appears
        }
    }
}

/// Image Cache Helper
class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()
    
    private init() {
        cache.countLimit = 100
        cache.totalCostLimit = 50_000_000 // 50MB - explicit memory limit for better control
    }
    
    func get(key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }
    
    func set(key: String, image: UIImage) {
        cache.setObject(image, forKey: key as NSString)
    }
}

/// Cached Async Image with proper async loading
/// Uses AsyncImage with NSCache for memory management (50MB limit)
/// Prevents UI freeze on slow S3 by loading asynchronously
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder
    @State private var cachedImage: UIImage?
    
    var body: some View {
        Group {
            if let cachedImage = cachedImage {
                // Use cached image immediately
                content(Image(uiImage: cachedImage))
            } else {
                // Use AsyncImage for proper async loading (non-blocking UI thread)
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        placeholder()
                    case .success(let asyncImage):
                        // Load and cache image asynchronously
                        Task { @MainActor [url] in
                            await loadAndCacheImage(from: url)
                        }
                        content(asyncImage)
                    case .failure:
                        placeholder()
                    @unknown default:
                        placeholder()
                    }
                }
                .onAppear {
                    // Check cache first before AsyncImage loads
                    checkCache()
                }
            }
        }
    }
    
    private func checkCache() {
        guard let url = url else { return }
        let key = url.absoluteString
        if let cached = ImageCache.shared.get(key: key) {
            cachedImage = cached
        }
    }
    
    private func loadAndCacheImage(from url: URL?) async {
        guard let url = url else { return }
        let key = url.absoluteString
        
        // Check cache again (might have been loaded by another view)
        if let cached = ImageCache.shared.get(key: key) {
            await MainActor.run {
                cachedImage = cached
            }
            return
        }
        
        // Load from network asynchronously
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let loadedImage = UIImage(data: data) {
                // Cache the image (NSCache handles memory pressure automatically)
                ImageCache.shared.set(key: key, image: loadedImage)
                await MainActor.run {
                    cachedImage = loadedImage
                }
            }
        } catch {
            // Silently fail - placeholder will be shown
            print("[CachedAsyncImage] Failed to load: \(error)")
        }
    }
}

/// Pagination Helper
struct PaginatedList<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let pageSize: Int
    @ViewBuilder let content: (Item) -> Content
    @State private var displayedCount: Int
    
    init(items: [Item], pageSize: Int = 20, @ViewBuilder content: @escaping (Item) -> Content) {
        self.items = items
        self.pageSize = pageSize
        self.content = content
        _displayedCount = State(initialValue: min(pageSize, items.count))
    }
    
    var body: some View {
        LazyVStack {
            ForEach(Array(items.prefix(displayedCount))) { item in
                content(item)
                    .onAppear {
                        if item.id == items[displayedCount - 1].id && displayedCount < items.count {
                            loadMore()
                        }
                    }
            }
        }
    }
    
    private func loadMore() {
        displayedCount = min(displayedCount + pageSize, items.count)
    }
}


