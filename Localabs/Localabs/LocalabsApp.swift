import SwiftUI
import UIKit

@main
struct LocalabsApp: App {
    /// AppDelegate adaptor — needed only so iOS can deliver
    /// background-URLSession relaunch events to us. Without this, a
    /// download finishing while the app is killed wouldn't get a chance
    /// to fire the model-ready notification.
    @UIApplicationDelegateAdaptor(LocalabsAppDelegate.self) private var appDelegate
    @StateObject private var engine = InferenceEngine.shared
    /// Controls the splash → ContentView handoff. The splash plays its
    /// own zoom animation and calls back when done; we cross-fade
    /// ContentView in here so the visual transition isn't abrupt.
    @State private var showSplash: Bool = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(engine)
                    .task {
                        await engine.loadModelIfDownloaded()
                    }

                if showSplash {
                    SplashView {
                        withAnimation(.easeOut(duration: 0.35)) {
                            showSplash = false
                        }
                    }
                    .transition(.opacity)
                }
            }
        }
    }
}

/// Minimal AppDelegate. Its only job is to forward the
/// background-URLSession relaunch handler to ModelDownloader so the
/// shared session can complete event delivery and tell iOS we're done.
final class LocalabsAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Cold-start the keyboard subsystem during launch so the
        // first real text-field tap doesn't pay the ~10s
        // "Result accumulator timeout / Reporter disconnected"
        // delay we were seeing in the chat input. iOS spins up the
        // RemoteTextInput (RTI) daemon lazily on first
        // becomeFirstResponder — by doing that on a throwaway
        // off-screen field at launch, the daemon is already warm by
        // the time the user actually opens a chat.
        DispatchQueue.main.async {
            Self.prewarmKeyboard()
        }
        return true
    }

    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        // Park the completion handler on the downloader; it'll be invoked
        // from urlSessionDidFinishEvents(forBackgroundURLSession:) once
        // the session has flushed all pending events.
        ModelDownloader.shared.backgroundCompletionHandler = completionHandler
        // Eagerly create the background URLSession so iOS can bind the
        // pending events to its delegate — without this, iOS would have
        // a session id with no live delegate to deliver to.
        ModelDownloader.shared.ensureBackgroundSessionReady()
    }

    /// Triggers the iOS keyboard daemon (UIKeyboard / RTI) by briefly
    /// making a hidden, off-screen `UITextField` first responder.
    /// The field is removed immediately after — it never appears
    /// visually — but the system has now done the expensive one-time
    /// keyboard bring-up work, so the first real text-field focus is
    /// instant instead of taking ~10s on launch.
    private static func prewarmKeyboard() {
        guard let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first
        else { return }

        let field = UITextField(frame: CGRect(x: -1000, y: -1000, width: 1, height: 1))
        field.isHidden = true
        window.addSubview(field)
        _ = field.becomeFirstResponder()
        DispatchQueue.main.async {
            field.resignFirstResponder()
            field.removeFromSuperview()
        }
    }
}
