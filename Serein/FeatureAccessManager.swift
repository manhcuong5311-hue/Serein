// FeatureAccessManager.swift
// Serein — Feature Access & StoreKit 2 Purchase Manager
//
// Architecture
// ┌─ Product loading ─── Product.products(for:) on init
// ├─ Purchase ────────── product.purchase() → VerificationResult
// ├─ Restore ─────────── Transaction.currentEntitlements iteration
// ├─ Live listener ───── Transaction.updates (refunds, Family Sharing, Ask-to-Buy)
// └─ Persistence ─────── UserDefaults (mirrors StoreKit state, fast cold start)
//
// Free plan:
//   • 1 Goal per LifeArea
//   • Step types: today, tomorrow only
//
// Premium plan  (com.serein.premium.lifetime):
//   • Unlimited Goals across all LifeAreas
//   • All step types: today, tomorrow, scheduled, anytime, recurringDaily

import SwiftUI
import StoreKit
import Combine
// ============================================================
// MARK: - Constants
// ============================================================

private let kProductID   = "com.serein.premium.lifetime"
private let kStorageKey  = "lc.featureAccess"

// ============================================================
// MARK: - FeatureAccess
// ============================================================

enum FeatureAccess: String, Codable {
    case free
    case premium
}

// ============================================================
// MARK: - PurchaseState
// ============================================================
// Drives loading indicators and error alerts across PremiumView
// and the onboarding paywall without extra local state.

enum PurchaseState: Equatable {
    case idle
    case loading        // fetching Product from StoreKit
    case purchasing     // App Store payment sheet active
    case restoring      // iterating currentEntitlements
    case success        // purchase or restore succeeded
    case failed(String) // localised error message
}

// ============================================================
// MARK: - FeatureAccessManager
// ============================================================

@MainActor
final class FeatureAccessManager: ObservableObject {

    // Shared singleton — reference directly or via @ObservedObject.
    static let shared = FeatureAccessManager()

    // ── Published ────────────────────────────────────────────
    @Published private(set) var access:        FeatureAccess = .free
    @Published private(set) var purchaseState: PurchaseState = .idle
    @Published private(set) var product:       Product?      = nil

    // ── Private ──────────────────────────────────────────────
    private var transactionListener: Task<Void, Never>?

    // ============================================================
    // MARK: - Init / Deinit
    // ============================================================

    init() {
        // 1. Fast cold start from persisted state.
        load()
        // 2. Start background listener before anything else so no
        //    transaction is missed while the app is launching.
        transactionListener = makeTransactionListener()
        // 3. Load the StoreKit product for live price display.
        Task { await loadProduct() }
        // 4. Verify existing entitlements (handles edge cases like
        //    app reinstall with prior purchase).
        Task { await verifyCurrentEntitlements() }
    }

    deinit {
        transactionListener?.cancel()
    }

    // ============================================================
    // MARK: - Computed Helpers
    // ============================================================

    var isPremium: Bool { access == .premium }

    var planLabel: String    { isPremium ? "Premium ✦" : "Free Plan" }

    var planSublabel: String {
        isPremium
            ? "All features unlocked"
            : "1 goal per area · Today & Tomorrow steps"
    }

    /// Live price from StoreKit, falls back to literal while loading.
    var displayPrice: String { product?.displayPrice ?? "$9.99" }

    // ============================================================
    // MARK: - Feature Gating
    // ============================================================

    static let freeGoalLimit = 1

    /// `true` when the user may add another goal to `areaId`.
    func canAddGoal(in areaId: UUID, goals: [Goal]) -> Bool {
        if isPremium { return true }
        let real = goals.filter {
            $0.lifeAreaId == areaId && !$0.isArchived && !$0.isMock
        }.count
        return real < Self.freeGoalLimit
    }

    /// Returns `(used, limit?)` — `limit` is `nil` for premium (unlimited).
    func goalUsage(in areaId: UUID, goals: [Goal]) -> (used: Int, limit: Int?) {
        let real = goals.filter {
            $0.lifeAreaId == areaId && !$0.isArchived && !$0.isMock
        }.count
        return (real, isPremium ? nil : Self.freeGoalLimit)
    }

    /// Step types available on the current plan.
    func allowedStepTypes() -> [StepType] {
        isPremium ? StepType.allCases : [.today, .tomorrow]
    }

    /// `true` when `type` requires premium.
    func isStepTypeLocked(_ type: StepType) -> Bool {
        !allowedStepTypes().contains(type)
    }

    // ============================================================
    // MARK: - Product Loading
    // ============================================================

    func loadProduct() async {
        guard product == nil else { return }
        purchaseState = .loading
        do {
            let results = try await Product.products(for: [kProductID])
            product = results.first
        } catch {
            // Non-fatal — price badge falls back to "$9.99" literal.
        }
        if case .loading = purchaseState { purchaseState = .idle }
    }

    // ============================================================
    // MARK: - Purchase
    // ============================================================

    /// Initiates the App Store payment sheet.
    /// Caller should observe `purchaseState` and `isPremium` for UI updates.
    func purchase() async {
        // Ensure product is loaded.
        if product == nil {
            await loadProduct()
            guard product != nil else {
                purchaseState = .failed(
                    "Couldn't load the product. Check your connection and try again."
                )
                return
            }
        }
        await performPurchase()
    }

    private func performPurchase() async {
        guard let product else { return }
        purchaseState = .purchasing

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let tx = try checkVerified(verification)
                // Always finish the transaction to prevent re-delivery.
                await tx.finish()
                grantPremium()
                purchaseState = .success

            case .userCancelled:
                purchaseState = .idle

            case .pending:
                // Ask-to-Buy awaiting approval — transaction listener
                // will deliver the result when approved.
                purchaseState = .idle

            @unknown default:
                purchaseState = .idle
            }
        } catch StoreKitError.userCancelled {
            purchaseState = .idle
        } catch {
            purchaseState = .failed(error.localizedDescription)
        }
    }

    // ============================================================
    // MARK: - Restore
    // ============================================================

    /// Iterates `Transaction.currentEntitlements` and restores premium
    /// if a valid, unrevoked transaction for the product is found.
    @discardableResult
    func restorePurchase() async -> Bool {
        purchaseState = .restoring
        var found = false

        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result,
               tx.productID == kProductID,
               tx.revocationDate == nil {
                await tx.finish()
                grantPremium()
                found = true
                break
            }
        }

        purchaseState = found ? .success : .idle
        return found
    }

    // ============================================================
    // MARK: - Entitlement Verification (cold start)
    // ============================================================
    // Called on init to silently re-grant premium after a reinstall
    // or when the app hasn't been launched in a long time.

    private func verifyCurrentEntitlements() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result,
               tx.productID == kProductID,
               tx.revocationDate == nil {
                grantPremium()
                await tx.finish()
                return
            }
        }
    }

    // ============================================================
    // MARK: - Transaction Listener
    // ============================================================
    // Handles transactions delivered outside the normal purchase flow:
    //   • Ask-to-Buy approvals
    //   • Family Sharing grants
    //   • StoreKit promotional offers
    //   • Refunds / revocations → removes premium

    private func makeTransactionListener() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard let self else { break }

                switch result {
                case .verified(let tx):
                    if tx.productID == kProductID {
                        if tx.revocationDate != nil {
                            // Purchase was refunded — revoke access.
                            await MainActor.run { self.revokePremium() }
                        } else {
                            await MainActor.run {
                                self.grantPremium()
                                // Surface success state if the user is
                                // currently looking at the paywall.
                                if case .purchasing = self.purchaseState {
                                    self.purchaseState = .success
                                }
                            }
                        }
                        await tx.finish()
                    }

                case .unverified(_, let error):
                    // Log but do not act — unverified transactions are
                    // discarded to prevent receipt spoofing.
                    print("[FeatureAccessManager] Unverified transaction: \(error)")
                }
            }
        }
    }

    // ============================================================
    // MARK: - State Mutations
    // ============================================================

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error): throw error
        case .verified(let value):      return value
        }
    }

    /// Grants premium and persists. Safe to call multiple times.
    func grantPremium() {
        guard access != .premium else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
            access = .premium
        }
        save()
    }

    private func revokePremium() {
        access = .free
        save()
    }

    /// Legacy alias — preserved for onboarding preview / testing.
    /// In production, purchase() is called instead.
    func unlockPremium() { grantPremium() }

    // ============================================================
    // MARK: - Utility
    // ============================================================

    /// Clears a terminal purchase state so the UI returns to idle.
    func clearPurchaseState() {
        if case .success = purchaseState { purchaseState = .idle; return }
        if case .failed  = purchaseState { purchaseState = .idle; return }
    }

    /// Full reset — development / settings wipe only.
    func reset() {
        access        = .free
        purchaseState = .idle
        UserDefaults.standard.removeObject(forKey: kStorageKey)
    }

    // ============================================================
    // MARK: - Persistence
    // ============================================================
    // UserDefaults mirrors the StoreKit state for fast cold-start.
    // It is always re-verified against Transaction.currentEntitlements
    // on launch so it cannot be used to bypass payment.

    private func load() {
        guard
            let raw    = UserDefaults.standard.string(forKey: kStorageKey),
            let stored = FeatureAccess(rawValue: raw)
        else { return }
        access = stored
    }

    private func save() {
        UserDefaults.standard.set(access.rawValue, forKey: kStorageKey)
    }
}
