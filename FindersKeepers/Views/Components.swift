import EventKit
import EventKitUI
import Photos
import SwiftUI
import UIKit

// MARK: - Images

/// Loads screenshots from Photos.
/// Full-size images are fetched ahead of time during the weekly look, so the next one is ready
/// before you get to it, and two requests for the same screenshot share one download.
@MainActor
enum ImageLoader {
    /// Large enough to show any iPhone screenshot at its real size.
    private static let screenPixels = CGSize(width: 1320, height: 2868)
    private static let thumbnailPixels = CGSize(width: 420, height: 560)

    private static let thumbnails: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 600
        return cache
    }()

    private static let screens: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 8
        return cache
    }()

    private static var loading: [String: Task<UIImage?, Never>] = [:]

    static func thumbnail(for asset: PHAsset) async -> UIImage? {
        let key = asset.localIdentifier as NSString
        if let cached = thumbnails.object(forKey: key) { return cached }
        let image = await PhotoLibrary.image(for: asset, targetSize: thumbnailPixels, contentMode: .aspectFill)
        if let image { thumbnails.setObject(image, forKey: key) }
        return image
    }

    /// The full screenshot. Returns nil only if Photos cannot supply it (for example, iCloud is unreachable).
    static func screen(for asset: PHAsset) async -> UIImage? {
        let id = asset.localIdentifier
        if let cached = screens.object(forKey: id as NSString) { return cached }
        if let inProgress = loading[id] { return await inProgress.value }
        let task = Task { await PhotoLibrary.image(for: asset, targetSize: screenPixels, contentMode: .aspectFit) }
        loading[id] = task
        let image = await task.value
        loading[id] = nil
        if let image { screens.setObject(image, forKey: id as NSString) }
        return image
    }

    /// Starts fetching screenshots that will be needed soon.
    static func prepare(_ assets: some Sequence<PHAsset>) {
        for asset in assets {
            Task { _ = await screen(for: asset) }
        }
    }
}

/// A tile for the grid: a crop of the screenshot with its title underneath,
/// so you can tell what it is without squinting.
struct Thumbnail: View {
    let asset: PHAsset
    var caption: String?
    @State private var image: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Color(.secondarySystemBackground)
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .overlay {
                    if let image {
                        Image(uiImage: image).resizable().scaledToFill()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            if let caption {
                Text(caption)
                    .font(.caption)
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.primary)
            }
        }
        .task(id: asset.localIdentifier) {
            image = await ImageLoader.thumbnail(for: asset)
        }
    }
}

/// A whole screenshot at full quality. Never shows a blurry stand-in: it shows a spinner,
/// then the real image, or says plainly that the image could not be loaded.
struct Screenshot: View {
    let asset: PHAsset
    var cornerRadius: CGFloat = 14
    @State private var image: UIImage?
    @State private var didFail = false

    private var shape: CGFloat {
        asset.pixelHeight > 0 ? CGFloat(asset.pixelWidth) / CGFloat(asset.pixelHeight) : 9.0 / 19.5
    }

    var body: some View {
        ZStack {
            Color(.secondarySystemBackground)
            if let image {
                Image(uiImage: image).resizable()
            } else if didFail {
                VStack(spacing: 8) {
                    Image(systemName: "icloud.slash").font(.title2)
                    Text("Couldn't load this one from iCloud.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(.secondary)
                .padding()
            } else {
                ProgressView()
            }
        }
        .aspectRatio(shape, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task(id: asset.localIdentifier) {
            didFail = false
            image = await ImageLoader.screen(for: asset)
            didFail = image == nil
        }
    }
}

// MARK: - Zooming

/// Full screen, pinch to zoom, double-tap to zoom in on a spot.
struct ZoomViewer: View {
    let asset: PHAsset
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            if let image {
                ZoomableImage(image: image).ignoresSafeArea()
            } else {
                ProgressView().tint(.white).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .padding(12)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("Close")
            .padding()
        }
        .task { image = await ImageLoader.screen(for: asset) }
    }
}

private struct ZoomableImage: UIViewRepresentable {
    let image: UIImage

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> ZoomScrollView {
        let scroll = ZoomScrollView()
        scroll.delegate = context.coordinator
        scroll.imageView.image = image
        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.doubleTapped(_:)))
        doubleTap.numberOfTapsRequired = 2
        scroll.addGestureRecognizer(doubleTap)
        return scroll
    }

    func updateUIView(_ scroll: ZoomScrollView, context: Context) {
        scroll.imageView.image = image
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            (scrollView as? ZoomScrollView)?.imageView
        }

        @objc func doubleTapped(_ gesture: UITapGestureRecognizer) {
            guard let scroll = gesture.view as? ZoomScrollView else { return }
            if scroll.zoomScale > 1 {
                scroll.setZoomScale(1, animated: true)
            } else {
                let point = gesture.location(in: scroll.imageView)
                let size = CGSize(width: scroll.bounds.width / 2.5, height: scroll.bounds.height / 2.5)
                let target = CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2, width: size.width, height: size.height)
                scroll.zoom(to: target, animated: true)
            }
        }
    }
}

/// A scroll view holding one image that fills it until you zoom.
private final class ZoomScrollView: UIScrollView {
    let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        minimumZoomScale = 1
        maximumZoomScale = 5
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        imageView.contentMode = .scaleAspectFit
        addSubview(imageView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("ZoomScrollView is only created in code")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if zoomScale == 1 {
            imageView.frame = CGRect(origin: .zero, size: bounds.size)
        }
    }
}

// MARK: - Small pieces

/// A rounded filter button.
struct Chip: View {
    let title: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isOn ? AnyShapeStyle(.tint) : AnyShapeStyle(.fill.tertiary), in: Capsule())
                .foregroundStyle(isOn ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// A short message that slides up from the bottom and leaves on its own.
private struct Toast: ViewModifier {
    @Binding var message: String?

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let message {
                Text(message)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(.regularMaterial, in: Capsule())
                    .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: message) {
                        try? await Task.sleep(for: .seconds(2.2))
                        withAnimation { self.message = nil }
                    }
            }
        }
        .animation(.spring(duration: 0.3), value: message)
    }
}

extension View {
    func toast(_ message: Binding<String?>) -> some View {
        modifier(Toast(message: message))
    }
}

/// Used wherever a sheet needs to know which screenshot to show.
struct ScreenshotID: Identifiable, Hashable {
    let id: String
}

// MARK: - Calendar

/// Apple's own "New Event" sheet, filled in from a screenshot.
/// You check it and tap Add, so the app never needs access to your calendar.
struct EventEditor: UIViewControllerRepresentable {
    let title: String
    let date: Date
    let notes: String
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: { dismiss() })
    }

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let eventStore = EKEventStore()
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.notes = notes
        event.startDate = date
        let time = Calendar.current.dateComponents([.hour, .minute], from: date)
        if time.hour == 0, time.minute == 0 {
            event.isAllDay = true
            event.endDate = date
        } else {
            event.endDate = date.addingTimeInterval(3_600)
        }

        let editor = EKEventEditViewController()
        editor.eventStore = eventStore
        editor.event = event
        editor.editViewDelegate = context.coordinator
        return editor
    }

    func updateUIViewController(_ editor: EKEventEditViewController, context: Context) {}

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        private let onFinish: () -> Void

        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }

        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            onFinish()
        }
    }
}
