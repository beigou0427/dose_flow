import Flutter
import StoreKit
import UIKit
import XCTest
@testable import Runner

final class RunnerTests: XCTestCase {
  func testFreshInstallHasZeroActiveEntitlements() async throws {
    let activeIds = await DoseFlowStoreKitBridge.shared.fetchActiveEntitlementIds(syncWithAppStore: false)
    XCTAssertTrue(
      activeIds.isEmpty,
      "Fresh install must NOT have any unlocked Pro entitlements automatically"
    )
  }

  func testFetchAllThreeLiveAppStoreProducts() async throws {
    let ids = [
      "com.doseflow.app.monthly",
      "com.doseflow.app.annual",
      "com.doseflow.app.lifetime"
    ]
    let prices = try await DoseFlowStoreKitBridge.shared.fetchProductPrices(productIds: ids)
    XCTAssertEqual(prices.count, 3, "All 3 IAP products must be returned by StoreKit 2")
    XCTAssertNotNil(prices["com.doseflow.app.monthly"])
    XCTAssertNotNil(prices["com.doseflow.app.annual"])
    XCTAssertNotNil(prices["com.doseflow.app.lifetime"])
    XCTAssertFalse(prices["com.doseflow.app.monthly"]!.isEmpty)
    XCTAssertFalse(prices["com.doseflow.app.annual"]!.isEmpty)
    XCTAssertFalse(prices["com.doseflow.app.lifetime"]!.isEmpty)
  }

  func testInvalidProductIdThrowsProductNotFoundAndKeepsProLocked() async throws {
    do {
      _ = try await DoseFlowStoreKitBridge.shared.purchaseProduct(productId: "com.doseflow.app.nonexistent")
      XCTFail("Expected PRODUCT_NOT_FOUND error for invalid product ID")
    } catch let error as NSError {
      XCTAssertEqual(error.userInfo["code"] as? String, "PRODUCT_NOT_FOUND")
    }

    let activeIds = await DoseFlowStoreKitBridge.shared.fetchActiveEntitlementIds(syncWithAppStore: false)
    XCTAssertTrue(activeIds.isEmpty, "Failed purchase must keep Pro locked")
  }
}
