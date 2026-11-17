import EventKit
import EventKitUI
import Photos
import SwiftUI
import UIKit

// MARK: - Images

/// Loads screenshots from Photos and remembers small ones, so scrolling back up is instant.
@MainActor
enum ImageLoader {
    private static let thumbnails: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 500
        return cache
    }()

    static func thumbnail(for asset: PHAsset) async -> UIImage? {
        let key = asset.localIdentifier as NSString
        if let cached = thumbnails.object(forKey: key) { return cached }
        let image = await PhotoLibrary.image(for: asset, targetSize: CGSize(width: 360, height: 780), contentMode: .aspectFill)
        if let image { thumbnails.setObject(image, forKey: key) }
        return image
    }

    static func screen(for asset: PHAsset) async -> UIImage? {
        await PhotoLibrary.image(for: asset, targetSize: CGSize(width: 1290, height: 2796), contentMode: .aspectFit)
    }
}

/// A small tile for the grid.
struct Thumbnail: View {
    let asset: PHAsset
    @State private var image: UIImage?

    var body: some View {
        Color.white.opacity(0.06)
            .aspectRatio(9.0 / 19.5, contentMode: .fit)
            .overlay {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .task(id: asset.localIdentifier) {
                image = await ImageLoader.thumbnail(for: asset)
            }
    }
}

/// A whole screenshot, sized to fit. Holds its shape while loading so nothing jumps.
struct Screenshot: View {
    let asset: PHAsset
    @State private var image: UIImage?

    private var shape: CGFloat {
        asset.pixelHeight > 0 ? CGFloat(asset.pixelWidth) / CGFloat(asset.pixelHeight) : 9.0 / 19.5
    }

    var body: some View {
        ZStack {
            Color.panel
            if let image {
                Image(uiImage: image).resizable()
            } else {
                ProgressView().tint(Color.gold)
            }
        }
        .aspectRatio(shape, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .task(id: asset.localIdentifier) {
            image = await ImageLoader.screen(for: asset)
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
                ProgressView().tint(Color.gold).frame(maxWidth: .infinity, maxHeight: .infinity)
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
                .background(isOn ? Color.gold : Color.white.opacity(0.10), in: Capsule())
                .foregroundStyle(isOn ? Color.ink : Color.white)
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
                    .background(Color.paper, in: Capsule())
                    .foregroundStyle(Color.ink)
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
