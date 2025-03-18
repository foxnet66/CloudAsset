import Foundation
import StoreKit
import SwiftUI

class PurchaseManager: ObservableObject {
    static private let proVersionID = "com.cloudasset.proversion"
    
    @Published var isPro: Bool = false
    @Published var purchaseInProgress = false
    @Published var purchaseError: String?
    
    // 资产计数限制
    let freeVersionAssetLimit = 50
    
    private var products: [Product] = []
    private var transactionListener: Task<Void, Error>?
    
    init() {
        // 从 UserDefaults 加载购买状态
        isPro = UserDefaults.standard.bool(forKey: "isPro")
        
        // 启动交易监听器
        transactionListener = listenForTransactions()
        
        // 加载商品
        Task {
            await loadProducts()
        }
    }
    
    deinit {
        transactionListener?.cancel()
    }
    
    // 加载StoreKit商品
    @MainActor
    func loadProducts() async {
        do {
            let storeProducts = try await Product.products(for: [Self.proVersionID])
            self.products = storeProducts
            print("成功加载 \(storeProducts.count) 个商品")
        } catch {
            print("加载商品失败: \(error)")
        }
    }
    
    // 监听交易
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in StoreKit.Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    
                    // 处理交易
                    await self.updatePurchaseStatus(transaction: transaction)
                    
                    // 完成交易
                    await transaction.finish()
                } catch {
                    print("交易验证失败: \(error)")
                }
            }
        }
    }
    
    // 购买专业版
    @MainActor
    func purchaseProVersion() async {
        guard let product = products.first(where: { $0.id == Self.proVersionID }) else {
            self.purchaseError = "找不到专业版商品"
            return
        }
        
        do {
            purchaseInProgress = true
            purchaseError = nil
            
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                // 验证购买
                do {
                    let transaction = try checkVerified(verification)
                    await updatePurchaseStatus(transaction: transaction)
                    await transaction.finish()
                    purchaseInProgress = false
                } catch {
                    purchaseError = "购买验证失败"
                    purchaseInProgress = false
                }
            case .userCancelled:
                purchaseError = "用户取消购买"
                purchaseInProgress = false
            case .pending:
                purchaseError = "购买正在处理中"
                purchaseInProgress = false
            @unknown default:
                purchaseError = "未知错误"
                purchaseInProgress = false
            }
        } catch {
            purchaseError = "购买失败: \(error.localizedDescription)"
            purchaseInProgress = false
        }
    }
    
    // 恢复购买
    @MainActor
    func restorePurchases() async {
        do {
            purchaseInProgress = true
            purchaseError = nil
            
            // 调用App Store的恢复流程
            try await AppStore.sync()
            
            // 检查是否有专业版的交易记录
            let result = await StoreKit.Transaction.currentEntitlements
            
            for await result in result {
                do {
                    let transaction = try checkVerified(result)
                    
                    if transaction.productID == Self.proVersionID {
                        await updatePurchaseStatus(transaction: transaction)
                        purchaseInProgress = false
                        return
                    }
                } catch {
                    print("恢复购买验证失败: \(error)")
                }
            }
            
            purchaseError = "找不到之前的购买记录"
            purchaseInProgress = false
        } catch {
            purchaseError = "恢复购买失败: \(error.localizedDescription)"
            purchaseInProgress = false
        }
    }
    
    // 检查交易验证
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified:
            throw StoreError.failedVerification
        }
    }
    
    // 更新购买状态
    @MainActor
    private func updatePurchaseStatus(transaction: StoreKit.Transaction) async {
        if transaction.productID == Self.proVersionID {
            // 如果交易未被撤销并且未过期，激活专业版
            if transaction.revocationDate == nil && (transaction.expirationDate == nil || transaction.expirationDate! > Date()) {
                self.isPro = true
                UserDefaults.standard.set(true, forKey: "isPro")
            } else {
                self.isPro = false
                UserDefaults.standard.set(false, forKey: "isPro")
            }
        }
    }
    
    // 检查是否超过免费版资产限制
    func hasReachedFreeLimit(assetCount: Int) -> Bool {
        return !isPro && assetCount >= freeVersionAssetLimit
    }
    
    // 获取显示价格
    var proVersionPrice: String {
        if let product = products.first(where: { $0.id == Self.proVersionID }) {
            return product.displayPrice
        }
        return "¥30.00" // 默认价格
    }
}

// 错误定义
enum StoreError: Error {
    case failedVerification
}

// 预览用辅助方法
extension PurchaseManager {
    static var preview: PurchaseManager {
        let manager = PurchaseManager()
        manager.isPro = true
        return manager
    }
    
    static var previewFree: PurchaseManager {
        let manager = PurchaseManager()
        manager.isPro = false
        return manager
    }
} 