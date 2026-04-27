import Flutter
import UIKit

private final class ContentProtectionManager {
  static let shared = ContentProtectionManager()

  private weak var window: UIWindow?
  private var shieldView: UIView?
  private var isEnabled = false
  private var observersRegistered = false

  func configure(window: UIWindow?) {
    self.window = window
    if isEnabled {
      updateShieldForCurrentState()
    }
  }

  func setEnabled(_ enabled: Bool) {
    isEnabled = enabled

    if enabled {
      registerObservers()
      updateShieldForCurrentState()
    } else {
      unregisterObservers()
      removeShield()
    }
  }

  private func registerObservers() {
    guard !observersRegistered else {
      return
    }

    observersRegistered = true
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleCapturedScreenChanged),
      name: UIScreen.capturedDidChangeNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleAppWillResignActive),
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleAppDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleScreenshotTaken),
      name: UIApplication.userDidTakeScreenshotNotification,
      object: nil
    )
  }

  private func unregisterObservers() {
    guard observersRegistered else {
      return
    }

    observersRegistered = false
    NotificationCenter.default.removeObserver(self)
  }

  @objc private func handleCapturedScreenChanged() {
    updateShieldForCurrentState()
  }

  @objc private func handleAppWillResignActive() {
    guard isEnabled else {
      return
    }

    showShield(message: nil)
  }

  @objc private func handleAppDidBecomeActive() {
    updateShieldForCurrentState()
  }

  @objc private func handleScreenshotTaken() {
    guard isEnabled else {
      return
    }

    showShield(message: "Protected content")
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
      self?.updateShieldForCurrentState()
    }
  }

  private func updateShieldForCurrentState() {
    guard isEnabled else {
      removeShield()
      return
    }

    if UIScreen.main.isCaptured {
      showShield(message: "Screen recording is disabled")
    } else {
      removeShield()
    }
  }

  private func showShield(message: String?) {
    guard let window else {
      return
    }

    let shield = shieldView ?? buildShieldView(frame: window.bounds)
    shield.frame = window.bounds

    if shield.superview !== window {
      window.addSubview(shield)
    }

    if let label = shield.viewWithTag(1001) as? UILabel {
      label.text = message ?? "Protected content"
      label.isHidden = message == nil
    }

    shield.alpha = 1
  }

  private func removeShield() {
    shieldView?.removeFromSuperview()
  }

  private func buildShieldView(frame: CGRect) -> UIView {
    let view = UIView(frame: frame)
    view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view.backgroundColor = .black

    let label = UILabel()
    label.tag = 1001
    label.translatesAutoresizingMaskIntoConstraints = false
    label.textColor = .white
    label.textAlignment = .center
    label.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
    label.numberOfLines = 0
    view.addSubview(label)

    NSLayoutConstraint.activate([
      label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
      label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
    ])

    shieldView = view
    return view
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let contentProtectionChannel = "com.onlybl.app/content_protection"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let didFinishLaunching = super.application(
      application,
      didFinishLaunchingWithOptions: launchOptions
    )

    ContentProtectionManager.shared.configure(window: window)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: contentProtectionChannel,
        binaryMessenger: controller.binaryMessenger
      )

      channel.setMethodCallHandler { call, result in
        switch call.method {
        case "setProtectionEnabled":
          guard
            let arguments = call.arguments as? [String: Any],
            let enabled = arguments["enabled"] as? Bool
          else {
            result(
              FlutterError(
                code: "invalid-arguments",
                message: "Expected a boolean enabled flag.",
                details: nil
              )
            )
            return
          }

          ContentProtectionManager.shared.setEnabled(enabled)
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return didFinishLaunching
  }
}
