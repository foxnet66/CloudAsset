import Foundation
import CoreData

extension Asset {
    // 便捷属性
    var wrappedId: UUID {
        id ?? UUID()
    }
    
    var wrappedName: String {
        name ?? "未命名资产"
    }
    
    var wrappedNotes: String {
        notes ?? ""
    }
    
    var wrappedPurchaseDate: Date {
        purchaseDate ?? Date()
    }
    
    var wrappedWarrantyEndDate: Date? {
        warrantyEndDate
    }
    
    var wrappedCreatedAt: Date {
        createdAt ?? Date()
    }
    
    var wrappedUpdatedAt: Date {
        updatedAt ?? Date()
    }
    
    // 计算属性
    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: price)) ?? "¥0.00"
    }
    
    var usageDays: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: wrappedPurchaseDate, to: Date())
        return max(components.day ?? 0, 1) // 至少为1天
    }
    
    var dailyAveragePrice: Double {
        return price / Double(usageDays)
    }
    
    var formattedDailyAveragePrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: dailyAveragePrice)) ?? "¥0.00"
    }
    
    var remainingUsesCount: Int32 {
        totalUses - usedCount
    }
    
    var isLowOnRemainingUses: Bool {
        totalUses > 0 && remainingUsesCount <= 5
    }
    
    var warrantyStatus: WarrantyStatus {
        guard let warrantyDate = wrappedWarrantyEndDate else {
            return .noWarranty
        }
        
        if Date() > warrantyDate {
            return .expired
        } else {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.day], from: Date(), to: warrantyDate)
            if let days = components.day, days <= 30 {
                return .expiringSoon
            } else {
                return .valid
            }
        }
    }
    
    // 添加图片的方法
    func addImage(data: Data) {
        self.imageData = data
        self.updatedAt = Date()
    }
    
    // 更新使用次数
    func incrementUsedCount() {
        self.usedCount += 1
        self.updatedAt = Date()
    }
    
    // 使用状态转换
    func toggleInUse() {
        self.currentlyInUse.toggle()
        self.updatedAt = Date()
    }
}

// 保修状态枚举
enum WarrantyStatus {
    case valid
    case expiringSoon
    case expired
    case noWarranty
    
    var description: String {
        switch self {
        case .valid:
            return "有效"
        case .expiringSoon:
            return "即将到期"
        case .expired:
            return "已过期"
        case .noWarranty:
            return "无保修"
        }
    }
    
    var color: String {
        switch self {
        case .valid:
            return "green"
        case .expiringSoon:
            return "yellow"
        case .expired:
            return "red"
        case .noWarranty:
            return "gray"
        }
    }
} 