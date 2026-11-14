import Flutter
import StoreKit
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private var isStoreKitRegistered = false

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    guard !isStoreKitRegistered,
          let flutterVC = window?.rootViewController as? FlutterViewController else {
      return
    }
    isStoreKitRegistered = true
    DoseFlowStoreKitBridge.shared.register(with: flutterVC.binaryMessenger)
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
