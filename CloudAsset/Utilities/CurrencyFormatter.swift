import Foundation

// 全局货币格式化工具
struct CurrencyFormatter {
    // 标准货币格式化
    static func format(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        
        // 从UserDefaults获取保存的货币区域设置
        let localeIdentifier = UserDefaults.standard.selectedCurrencyLocale
        formatter.locale = Locale(identifier: localeIdentifier)
        
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
    
    // 简短格式（用于大数值）
    static func formatShort(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        
        // 从UserDefaults获取保存的货币区域设置
        let localeIdentifier = UserDefaults.standard.selectedCurrencyLocale
        formatter.locale = Locale(identifier: localeIdentifier)
        
        // 针对大金额使用更简洁的格式
        if value >= 1_000_000 {
            // 对于超过百万的金额，显示为X.XX M（百万）
            let millionValue = value / 1_000_000
            formatter.maximumFractionDigits = 2
            formatter.minimumFractionDigits = 1
            return (formatter.string(from: NSNumber(value: millionValue)) ?? "$0.00") + " M"
        } else if value >= 10_000 {
            // 对于超过1万的金额，显示为X.X K（千）
            let thousandValue = value / 1_000
            formatter.maximumFractionDigits = 1
            formatter.minimumFractionDigits = 1
            return (formatter.string(from: NSNumber(value: thousandValue)) ?? "$0.00") + " K"
        }
        
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
    
    // 获取当前货币符号
    static var currencySymbol: String {
        let localeIdentifier = UserDefaults.standard.selectedCurrencyLocale
        let locale = Locale(identifier: localeIdentifier)
        return locale.currencySymbol ?? "$"
    }
} 