import Flutter
import LocalAuthentication
import StoreKit
import UIKit
import UserNotifications

class SceneDelegate: FlutterSceneDelegate {
  private var isBridgesRegistered = false

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    guard !isBridgesRegistered,
          let flutterVC = window?.rootViewController as? FlutterViewController else {
      return
    }
    isBridgesRegistered = true
    let messenger = flutterVC.binaryMessenger
    DoseFlowStoreKitBridge.shared.register(with: messenger)
    DoseFlowBiometricsBridge.shared.register(with: messenger)
    DoseFlowNotificationsBridge.shared.register(with: messenger)
    DoseFlowICloudBridge.shared.register(with: messenger)
  }
}

final class DoseFlowStoreKitBridge {
  static let shared = DoseFlowStoreKitBridge()
  private var updatesTask: Task<Void, Never>?

  private init() {}

  func register(with messenger: FlutterBinaryMessenger) {
    startTransactionListener()
    let channel = FlutterMethodChannel(
      name: "com.doseflow.app/storekit",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "fetchProducts":
        guard let args = call.arguments as? [String: Any],
              let productIds = args["productIds"] as? [String] else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing productIds", details: nil))
          return
        }
        Task { @MainActor in
          do {
            let products = try await Product.products(for: productIds)
            var priceMap: [String: String] = [:]
            for product in products {
              priceMap[product.id] = product.displayPrice
            }
            result(priceMap)
          } catch {
            result(FlutterError(code: "FETCH_ERROR", message: error.localizedDescription, details: nil))
          }
        }
      case "purchaseProduct":
        guard let args = call.arguments as? [String: Any],
              let productId = args["productId"] as? String else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing productId", details: nil))
          return
        }
        Task { @MainActor in
          do {
            let products = try await Product.products(for: [productId])
            guard let product = products.first else {
              result(FlutterError(code: "PRODUCT_NOT_FOUND", message: "Product unavailable: \(productId)", details: nil))
              return
            }
            let purchaseResult = try await product.purchase()
            switch purchaseResult {
            case .success(let verification):
              switch verification {
              case .verified(let transaction):
                await transaction.finish()
                result(verification.jwsRepresentation)
              case .unverified(_, let error):
                result(FlutterError(code: "UNVERIFIED", message: error.localizedDescription, details: nil))
              }
            case .userCancelled:
              result(FlutterError(code: "USER_CANCELLED", message: "Purchase cancelled by user", details: nil))
            case .pending:
              result(FlutterError(code: "PENDING", message: "Purchase pending approval", details: nil))
            @unknown default:
              result(FlutterError(code: "UNKNOWN", message: "Unknown purchase state", details: nil))
            }
          } catch {
            result(FlutterError(code: "PURCHASE_ERROR", message: error.localizedDescription, details: nil))
          }
        }
      case "restorePurchases":
        Task { @MainActor in
          try? await AppStore.sync()
          var activeIds: [String] = []
          for await verification in Transaction.currentEntitlements {
            if case .verified(let tx) = verification, tx.revocationDate == nil {
              activeIds.append(tx.productID)
            }
          }
          result(activeIds)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func startTransactionListener() {
    guard updatesTask == nil else { return }
    updatesTask = Task.detached(priority: .background) {
      for await verification in Transaction.updates {
        if case .verified(let tx) = verification {
          await tx.finish()
        }
      }
    }
  }
}

/// DoseFlow 1.1 原生 Face ID / Touch ID / 裝置密碼鎖橋接
final class DoseFlowBiometricsBridge {
  static let shared = DoseFlowBiometricsBridge()
  private init() {}

  func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.doseflow.app/biometrics",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      let context = LAContext()
      var authError: NSError?
      switch call.method {
      case "isAvailable":
        let canEval = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError)
        result(canEval)
      case "authenticate":
        let args = call.arguments as? [String: Any]
        let reason = args?["reason"] as? String ?? "Verify your identity to access DoseFlow records."
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) {
          context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
            DispatchQueue.main.async {
              result(success)
            }
          }
        } else {
          result(false)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

/// DoseFlow 1.1 原生本地週期施打／換針推播排程橋接
final class DoseFlowNotificationsBridge {
  static let shared = DoseFlowNotificationsBridge()
  private init() {}

  func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.doseflow.app/notifications",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      let center = UNUserNotificationCenter.current()
      switch call.method {
      case "requestPermission":
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
          DispatchQueue.main.async { result(granted) }
        }
      case "cancelAllReminders":
        center.removePendingNotificationRequests(withIdentifiers: [
          "doseflow_weekly_shot",
          "doseflow_needle_prep"
        ])
        result(nil)
      case "scheduleWeeklyReminders":
        guard let args = call.arguments as? [String: Any] else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing args", details: nil))
          return
        }
        let shotEnabled = args["shotEnabled"] as? Bool ?? false
        let prepEnabled = args["prepEnabled"] as? Bool ?? false
        let dartWeekday = args["weekday"] as? Int ?? 5 // 1=Mon..7=Sun
        let hour = args["hour"] as? Int ?? 8
        let minute = args["minute"] as? Int ?? 30
        let shotTitle = args["shotTitle"] as? String ?? "DoseFlow Shot Reminder"
        let shotBody = args["shotBody"] as? String ?? "Time for your weekly GLP-1 dose."
        let prepTitle = args["prepTitle"] as? String ?? "Fresh Needle & Prep"
        let prepBody = args["prepBody"] as? String ?? "Prepare a new sterile needle and alcohol swab."

        // Convert Dart weekday (1=Mon..7=Sun) to Apple Calendar weekday (1=Sun, 2=Mon..7=Sat)
        let appleWeekday = (dartWeekday % 7) + 1

        center.removePendingNotificationRequests(withIdentifiers: [
          "doseflow_weekly_shot",
          "doseflow_needle_prep"
        ])

        if shotEnabled {
          let content = UNMutableNotificationContent()
          content.title = shotTitle
          content.body = shotBody
          content.sound = .default
          var dc = DateComponents()
          dc.weekday = appleWeekday
          dc.hour = hour
          dc.minute = minute
          let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
          let req = UNNotificationRequest(identifier: "doseflow_weekly_shot", content: content, trigger: trigger)
          center.add(req, withCompletionHandler: nil)
        }

        if prepEnabled {
          let totalMin = max(0, hour * 60 + minute - 10)
          let content = UNMutableNotificationContent()
          content.title = prepTitle
          content.body = prepBody
          content.sound = .default
          var dc = DateComponents()
          dc.weekday = appleWeekday
          dc.hour = totalMin / 60
          dc.minute = totalMin % 60
          let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
          let req = UNNotificationRequest(identifier: "doseflow_needle_prep", content: content, trigger: trigger)
          center.add(req, withCompletionHandler: nil)
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

/// DoseFlow 1.1 原生 iCloud Key-Value 個人私密備份橋接
final class DoseFlowICloudBridge {
  static let shared = DoseFlowICloudBridge()
  private let backupKey = "doseflow_encrypted_backup_v1"
  private init() {}

  func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.doseflow.app/icloud",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      let store = NSUbiquitousKeyValueStore.default
      switch call.method {
      case "pushBackup":
        guard let args = call.arguments as? [String: Any],
              let payload = args["payload"] as? String else {
          result(false)
          return
        }
        store.set(payload, forKey: self.backupKey)
        let ok = store.synchronize()
        result(ok)
      case "pullBackup":
        store.synchronize()
        result(store.string(forKey: self.backupKey))
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
