import Foundation
import CoreData
import SwiftUI

extension Category {
    // 便捷属性
    var wrappedId: UUID {
        id ?? UUID()
    }
    
    var wrappedName: String {
        name ?? "未分类"
    }
    
    var wrappedNotes: String {
        notes ?? ""
    }
    
    var wrappedIcon: String {
        icon ?? "folder"
    }
    
    var wrappedCreatedAt: Date {
        createdAt ?? Date()
    }
    
    var wrappedUpdatedAt: Date {
        updatedAt ?? Date()
    }
    
    // 获取该类别下的所有资产
    var assetArray: [Asset] {
        let set = assets as? Set<Asset> ?? []
        return set.sorted {
            $0.wrappedName < $1.wrappedName
        }
    }
    
    // 计算该类别下的资产总价值
    var totalValue: Double {
        let set = assets as? Set<Asset> ?? []
        return set.reduce(0) { $0 + $1.price }
    }
    
    var formattedTotalValue: String {
        return CurrencyFormatter.format(totalValue)
    }
    
    // 计算该类别下正在使用的资产数量
    var inUseAssetsCount: Int {
        let set = assets as? Set<Asset> ?? []
        return set.filter { $0.currentlyInUse }.count
    }
    
    // 静态方法：获取预设的类别
    static func getDefaultCategories(context: NSManagedObjectContext) -> [Category] {
        return [
            createCategory(name: "电子产品", icon: "laptopcomputer", context: context),
            createCategory(name: "家具", icon: "sofa", context: context),
            createCategory(name: "厨房用品", icon: "fork.knife", context: context),
            createCategory(name: "服装", icon: "tshirt", context: context),
            createCategory(name: "运动器材", icon: "sportscourt", context: context),
            createCategory(name: "书籍", icon: "book", context: context),
            createCategory(name: "工具", icon: "wrench.and.screwdriver", context: context),
            createCategory(name: "珠宝", icon: "diamond", context: context)
        ]
    }
    
    // 辅助方法：创建类别
    private static func createCategory(name: String, icon: String, context: NSManagedObjectContext) -> Category {
        let category = Category(context: context)
        category.id = UUID()
        category.name = name
        category.icon = icon
        category.createdAt = Date()
        category.updatedAt = Date()
        category.order = 0
        return category
    }
} 