import Foundation
import CoreData
import SwiftUI

class AssetRepository: ObservableObject {
    private let context: NSManagedObjectContext
    private let purchaseManager: PurchaseManager
    
    @Published var assets: [Asset] = []
    @Published var categories: [Category] = []
    @Published var totalAssetCount: Int = 0
    @Published var totalAssetValue: Double = 0
    @Published var inUseAssetCount: Int = 0
    @Published var lowUsageRemainingAssets: [Asset] = []
    @Published var soonExpiredWarrantyAssets: [Asset] = []
    
    init(context: NSManagedObjectContext, purchaseManager: PurchaseManager) {
        self.context = context
        self.purchaseManager = purchaseManager
        
        // 检查是否首次运行，如果是则添加默认类别
        let categoryFetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
        
        do {
            let categoryCount = try context.count(for: categoryFetchRequest)
            if categoryCount == 0 {
                // 添加默认类别
                createDefaultCategories()
            }
        } catch {
            print("检查类别失败: \(error)")
        }
        
        // 加载数据
        loadData()
    }
    
    // 加载数据
    func loadData() {
        loadAssets()
        loadCategories()
        updateStatistics()
    }
    
    // 加载所有资产
    private func loadAssets() {
        let request: NSFetchRequest<Asset> = Asset.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Asset.name, ascending: true)]
        
        do {
            assets = try context.fetch(request)
            totalAssetCount = assets.count
        } catch {
            print("加载资产失败: \(error)")
        }
    }
    
    // 加载所有类别
    private func loadCategories() {
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Category.order, ascending: true),
            NSSortDescriptor(keyPath: \Category.name, ascending: true)
        ]
        
        do {
            categories = try context.fetch(request)
        } catch {
            print("加载类别失败: \(error)")
        }
    }
    
    // 更新统计数据
    private func updateStatistics() {
        // 计算总资产价值
        totalAssetValue = assets.reduce(0) { $0 + $1.price }
        
        // 计算正在使用的资产数量
        inUseAssetCount = assets.filter { $0.currentlyInUse }.count
        
        // 查找剩余使用次数较低的资产
        lowUsageRemainingAssets = assets.filter { $0.isLowOnRemainingUses }
        
        // 查找即将过期的保修资产
        soonExpiredWarrantyAssets = assets.filter { $0.warrantyStatus == .expiringSoon }
    }
    
    // 创建默认类别
    private func createDefaultCategories() {
        let defaultCategories = Category.getDefaultCategories(context: context)
        
        do {
            try context.save()
        } catch {
            print("保存默认类别失败: \(error)")
        }
    }
    
    // 添加新资产
    func addAsset(name: String, categoryId: UUID, price: Double, purchaseDate: Date, warrantyEndDate: Date?, totalUses: Int32?, notes: String?, imageData: Data?) -> Asset? {
        // 检查免费版限制
        if purchaseManager.hasReachedFreeLimit(assetCount: totalAssetCount) {
            return nil
        }
        
        let asset = Asset(context: context)
        asset.id = UUID()
        asset.name = name
        asset.price = price
        asset.purchaseDate = purchaseDate
        asset.warrantyEndDate = warrantyEndDate
        asset.totalUses = totalUses ?? 0
        asset.usedCount = 0
        asset.remainingUses = totalUses ?? 0
        asset.notes = notes
        asset.imageData = imageData
        asset.currentlyInUse = false
        asset.createdAt = Date()
        asset.updatedAt = Date()
        
        // 设置类别
        if let category = categories.first(where: { $0.wrappedId == categoryId }) {
            asset.category = category
        }
        
        // 保存
        do {
            try context.save()
            loadData() // 重新加载数据
            return asset
        } catch {
            print("保存资产失败: \(error)")
            return nil
        }
    }
    
    // 更新资产
    func updateAsset(id: UUID, name: String, categoryId: UUID, price: Double, purchaseDate: Date, warrantyEndDate: Date?, totalUses: Int32?, usedCount: Int32, notes: String?, imageData: Data?, currentlyInUse: Bool) -> Bool {
        guard let asset = assets.first(where: { $0.wrappedId == id }) else {
            return false
        }
        
        asset.name = name
        asset.price = price
        asset.purchaseDate = purchaseDate
        asset.warrantyEndDate = warrantyEndDate
        
        // 更新使用次数
        if let total = totalUses {
            asset.totalUses = total
            asset.usedCount = min(usedCount, total) // 确保已用次数不超过总次数
        } else {
            asset.totalUses = 0
            asset.usedCount = 0
        }
        
        asset.notes = notes
        
        // 更新图片（无论是新增、修改还是删除）
        asset.imageData = imageData // 直接赋值，当imageData为nil时会清除原有图片
        
        asset.currentlyInUse = currentlyInUse
        asset.updatedAt = Date()
        
        // 更新类别
        if let category = categories.first(where: { $0.wrappedId == categoryId }) {
            asset.category = category
        }
        
        // 保存
        do {
            try context.save()
            loadData() // 重新加载数据
            return true
        } catch {
            print("更新资产失败: \(error)")
            return false
        }
    }
    
    // 删除资产
    func deleteAsset(id: UUID) -> Bool {
        guard let asset = assets.first(where: { $0.wrappedId == id }) else {
            return false
        }
        
        context.delete(asset)
        
        // 保存
        do {
            try context.save()
            loadData() // 重新加载数据
            return true
        } catch {
            print("删除资产失败: \(error)")
            return false
        }
    }
    
    // 切换资产使用状态
    func toggleAssetInUse(id: UUID) -> Bool {
        guard let asset = assets.first(where: { $0.wrappedId == id }) else {
            return false
        }
        
        asset.toggleInUse()
        
        // 保存
        do {
            try context.save()
            loadData() // 重新加载数据
            return true
        } catch {
            print("更新资产状态失败: \(error)")
            return false
        }
    }
    
    // 增加资产使用次数
    func incrementAssetUsedCount(id: UUID) -> Bool {
        guard let asset = assets.first(where: { $0.wrappedId == id }) else {
            return false
        }
        
        // 确保不超过总次数
        if asset.totalUses > 0 && asset.usedCount < asset.totalUses {
            asset.incrementUsedCount()
            
            // 保存
            do {
                try context.save()
                loadData() // 重新加载数据
                return true
            } catch {
                print("更新资产使用次数失败: \(error)")
                return false
            }
        }
        
        return false
    }
    
    // 添加新类别（仅专业版）
    func addCategory(name: String, icon: String, notes: String?) -> Category? {
        // 仅专业版可添加自定义类别
        if !purchaseManager.isPro {
            return nil
        }
        
        let category = Category(context: context)
        category.id = UUID()
        category.name = name
        category.icon = icon
        category.notes = notes
        category.order = 0
        category.createdAt = Date()
        category.updatedAt = Date()
        
        // 保存
        do {
            try context.save()
            loadData() // 重新加载数据
            return category
        } catch {
            print("保存类别失败: \(error)")
            return nil
        }
    }
    
    // 更新类别（仅专业版）
    func updateCategory(id: UUID, name: String, icon: String, notes: String?) -> Bool {
        // 仅专业版可更新自定义类别
        if !purchaseManager.isPro {
            return false
        }
        
        guard let category = categories.first(where: { $0.wrappedId == id }) else {
            return false
        }
        
        category.name = name
        category.icon = icon
        category.notes = notes
        category.updatedAt = Date()
        
        // 保存
        do {
            try context.save()
            loadData() // 重新加载数据
            return true
        } catch {
            print("更新类别失败: \(error)")
            return false
        }
    }
    
    // 删除类别（仅专业版）
    func deleteCategory(id: UUID) -> Bool {
        // 仅专业版可删除自定义类别
        if !purchaseManager.isPro {
            return false
        }
        
        guard let category = categories.first(where: { $0.wrappedId == id }) else {
            return false
        }
        
        // 检查类别下是否有资产
        if let assets = category.assets as? Set<Asset>, !assets.isEmpty {
            return false
        }
        
        context.delete(category)
        
        // 保存
        do {
            try context.save()
            loadData() // 重新加载数据
            return true
        } catch {
            print("删除类别失败: \(error)")
            return false
        }
    }
    
    // 根据类别过滤资产
    func assetsInCategory(categoryId: UUID) -> [Asset] {
        return assets.filter { $0.category?.wrappedId == categoryId }
    }
    
    // 获取正在使用的资产
    var inUseAssets: [Asset] {
        return assets.filter { $0.currentlyInUse }
    }
    
    // 检查是否已达免费版资产上限
    var hasReachedFreeLimit: Bool {
        return purchaseManager.hasReachedFreeLimit(assetCount: totalAssetCount)
    }
    
    // 按日期范围过滤资产
    func assetsInDateRange(from: Date, to: Date) -> [Asset] {
        return assets.filter { asset in
            let purchaseDate = asset.wrappedPurchaseDate
            return purchaseDate >= from && purchaseDate <= to
        }
    }
    
    // 按价格范围过滤资产
    func assetsInPriceRange(min: Double, max: Double) -> [Asset] {
        return assets.filter { asset in
            return asset.price >= min && asset.price <= max
        }
    }
    
    // 搜索资产
    func searchAssets(query: String) -> [Asset] {
        guard !query.isEmpty else {
            return assets
        }
        
        let lowercaseQuery = query.lowercased()
        
        return assets.filter { asset in
            return asset.wrappedName.lowercased().contains(lowercaseQuery) ||
                   asset.wrappedNotes.lowercased().contains(lowercaseQuery)
        }
    }
    
    // 刷新资产数据
    func refreshAssets() {
        print("开始刷新资产数据...")
        
        // 强制使用新的后台上下文来获取数据，避免缓存问题
        let backgroundContext = PersistenceController.shared.container.newBackgroundContext()
        backgroundContext.automaticallyMergesChangesFromParent = true
        
        // 在后台队列中执行数据刷新，避免UI阻塞
        DispatchQueue.global(qos: .userInitiated).async {
            // 在后台上下文中获取最新数据
            let fetchRequest: NSFetchRequest<Asset> = Asset.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Asset.name, ascending: true)]
            
            do {
                // 使用后台上下文获取数据
                let freshAssets = try backgroundContext.fetch(fetchRequest)
                
                // 在主线程中更新数据
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    // 将获取的数据转换为主上下文中的对象
                    var updatedAssets: [Asset] = []
                    for freshAsset in freshAssets {
                        if let objectID = freshAsset.objectID as? NSManagedObjectID, 
                           let mainAsset = try? self.context.existingObject(with: objectID) as? Asset {
                            updatedAssets.append(mainAsset)
                        }
                    }
                    
                    // 重置和更新集合，触发UI更新
                    self.assets = []
                    
                    // 使用微小延迟，确保UI能捕获到变化
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        // 更新集合
                        self.assets = updatedAssets
                        
                        // 更新统计数据
                        self.updateStatistics()
                        
                        print("资产数据刷新完成。获取到 \(self.assets.count) 个资产。")
                        
                        // 发送完成通知
                        NotificationCenter.default.post(name: NSNotification.Name("AssetDataRefreshCompleted"), object: nil)
                    }
                }
                
                // 刷新类别数据
                let categoryRequest: NSFetchRequest<Category> = Category.fetchRequest()
                categoryRequest.sortDescriptors = [
                    NSSortDescriptor(keyPath: \Category.order, ascending: true),
                    NSSortDescriptor(keyPath: \Category.name, ascending: true)
                ]
                
                let freshCategories = try backgroundContext.fetch(categoryRequest)
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    var updatedCategories: [Category] = []
                    for freshCategory in freshCategories {
                        if let objectID = freshCategory.objectID as? NSManagedObjectID,
                           let mainCategory = try? self.context.existingObject(with: objectID) as? Category {
                            updatedCategories.append(mainCategory)
                        }
                    }
                    
                    self.categories = updatedCategories
                }
            } catch {
                print("刷新资产数据失败: \(error)")
            }
        }
    }
} 