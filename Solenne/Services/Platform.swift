import AVFoundation
import Observation
import StoreKit
import SwiftUI
import UserNotifications

// MARK: - Notifications

enum Notifications {
    static let reminderID = "solenne.daily-reminder"

    @discardableResult
    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func scheduleDaily(at time: ReminderTime, name: String) async -> Bool {
        guard await requestPermission() else { return false }
        let content = UNMutableNotificationContent()
        content.title = "Solenne"
        content.body = name.isEmpty
            ? "Your story for today is ready. Keep the flame."
            : "\(name), your story for today is ready. Keep the flame."
        content.sound = .default
        var comps = DateComponents()
        comps.hour = time.hour
        comps.minute = time.minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: reminderID, content: content, trigger: trigger)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reminderID])
        do {
            try await center.add(request)
            return true
        } catch {
            return false
        }
    }

    static func cancelReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderID])
    }
}

// MARK: - Purchases (StoreKit 2)

/// Subscriptions via StoreKit 2. Products are defined in `Solenne.storekit` for local testing;
/// create the same product ids in App Store Connect for release. (RevenueCat can wrap these later.)
@Observable
final class PurchaseManager {
    static let productIDs = ["solenne.pro.weekly", "solenne.pro.yearly"]

    private(set) var products: [Product] = []
    private(set) var isPro = false
    var lastError: String?

    @ObservationIgnored private var updates: Task<Void, Never>?

    init() {
        #if DEBUG
        isPro = UserDefaults.standard.bool(forKey: "debug.pro")
        #endif
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self?.refreshEntitlements()
                }
            }
        }
    }

    deinit { updates?.cancel() }

    @MainActor
    func load() async {
        do {
            let loaded = try await Product.products(for: Self.productIDs)
            products = loaded.sorted { $0.price < $1.price }
        } catch {
            lastError = error.localizedDescription
        }
        await refreshEntitlements()
    }

    @MainActor
    func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, Self.productIDs.contains(t.productID), t.revocationDate == nil {
                active = true
            }
        }
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "debug.pro") { active = true }
        #endif
        isPro = active
    }

    @MainActor
    func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refreshEntitlements()
                    return isPro
                }
                lastError = "We couldn't verify that purchase."
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            lastError = error.localizedDescription
        }
        return false
    }

    @MainActor
    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    #if DEBUG
    @MainActor
    func setDebugPro(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: "debug.pro")
        isPro = on
    }
    #endif
}

// MARK: - Voice recording

@Observable
final class VoiceRecorder {
    static let sampleSeconds: TimeInterval = 10

    private(set) var isRecording = false
    private(set) var elapsed: TimeInterval = 0
    private(set) var level: Double = 0
    private(set) var recordingURL: URL?

    @ObservationIgnored private var recorder: AVAudioRecorder?
    @ObservationIgnored private var timer: Timer?

    static func requestPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    func start() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try? session.setActive(true)

        let url = URL.documentsDirectory.appending(path: "voice-sample.m4a")
        try? FileManager.default.removeItem(at: url)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        guard let recorder = try? AVAudioRecorder(url: url, settings: settings) else { return }
        recorder.isMeteringEnabled = true
        recorder.record(forDuration: Self.sampleSeconds)
        self.recorder = recorder
        recordingURL = nil
        isRecording = true
        elapsed = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, let recorder = self.recorder else { return }
            recorder.updateMeters()
            let power = recorder.averagePower(forChannel: 0) // -160...0 dB
            self.level = max(0, min(1, (Double(power) + 50) / 50))
            self.elapsed = recorder.currentTime
            if !recorder.isRecording { self.finish() }
        }
    }

    func stop() {
        recorder?.stop()
        finish()
    }

    private func finish() {
        guard isRecording else { return }
        timer?.invalidate()
        isRecording = false
        level = 0
        recordingURL = recorder?.url
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
    }
}

// MARK: - Sharing helpers

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

enum ShareHelper {
    @MainActor
    static func render<V: View>(_ view: V, width: CGFloat = 360) -> UIImage? {
        let renderer = ImageRenderer(content: view.frame(width: width))
        renderer.scale = 3
        return renderer.uiImage
    }

    /// Opens Instagram's story composer with the image as background.
    /// Needs a Meta app id in `Config.instagramAppID`; returns false if it couldn't open.
    @MainActor
    static func shareToInstagramStories(_ image: UIImage) -> Bool {
        guard !Config.instagramAppID.isEmpty,
              let url = URL(string: "instagram-stories://share?source_application=\(Config.instagramAppID)"),
              UIApplication.shared.canOpenURL(url),
              let data = image.pngData() else { return false }
        UIPasteboard.general.setItems(
            [["com.instagram.sharedSticker.backgroundImage": data]],
            options: [.expirationDate: Date.now.addingTimeInterval(300)]
        )
        UIApplication.shared.open(url)
        return true
    }

    static func saveToPhotos(_ image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }

    static func link(for story: Story) -> URL {
        URL(string: "solenne://story/\(story.id.uuidString)")!
    }
}
