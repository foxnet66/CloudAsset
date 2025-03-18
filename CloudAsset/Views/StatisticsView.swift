import SwiftUI
import Charts

struct StatisticsView: View {
    @EnvironmentObject private var assetRepository: AssetRepository
    
    @State private var selectedTimeRange: TimeRange = .allTime
    @State private var selectedChartType: ChartType = .category
    
    // 时间范围枚举
    enum TimeRange: String, CaseIterable, Identifiable {
        case lastMonth = "近30天"
        case lastQuarter = "近90天"
        case lastYear = "近一年"
        case allTime = "全部时间"
        
        var id: String { self.rawValue }
        
        var days: Int {
            switch self {
            case .lastMonth: return 30
            case .lastQuarter: return 90
            case .lastYear: return 365
            case .allTime: return 3650 // 约10年，视为全部
            }
        }
    }
    
    // 图表类型枚举
    enum ChartType: String, CaseIterable, Identifiable {
        case category = "类别分布"
        case priceRange = "价格分布"
        case timeDistribution = "时间分布"
        
        var id: String { self.rawValue }
    }
    
    // 获取筛选的时间范围内的资产
    private var filteredAssets: [Asset] {
        if selectedTimeRange == .allTime {
            return assetRepository.assets
        } else {
            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .day, value: -selectedTimeRange.days, to: endDate)!
            return assetRepository.assetsInDateRange(from: startDate, to: endDate)
        }
    }
    
    // 类别统计数据
    private var categoryStats: [CategoryStat] {
        var stats: [CategoryStat] = []
        
        // 按类别分组
        let groupedByCategory = Dictionary(grouping: filteredAssets) { asset in
            asset.category?.wrappedId ?? UUID()
        }
        
        // 计算每个类别的统计数据
        for (categoryId, assets) in groupedByCategory {
            let categoryName = assets.first?.category?.wrappedName ?? "未分类"
            let totalValue = assets.reduce(0) { $0 + $1.price }
            let count = assets.count
            
            stats.append(CategoryStat(
                id: categoryId,
                name: categoryName,
                count: count,
                totalValue: totalValue
            ))
        }
        
        // 按价值排序
        return stats.sorted { $0.totalValue > $1.totalValue }
    }
    
    // 价格区间统计数据
    private var priceRangeStats: [PriceRangeStat] {
        // 定义价格区间
        let ranges: [(min: Double, max: Double, label: String)] = [
            (0, 100, "¥0-100"),
            (100, 500, "¥100-500"),
            (500, 1000, "¥500-1000"),
            (1000, 5000, "¥1000-5000"),
            (5000, 10000, "¥5000-10000"),
            (10000, Double.infinity, "¥10000+")
        ]
        
        var stats: [PriceRangeStat] = []
        
        // 计算每个价格区间的统计数据
        for range in ranges {
            let assetsInRange = filteredAssets.filter { $0.price >= range.min && $0.price < range.max }
            let count = assetsInRange.count
            let totalValue = assetsInRange.reduce(0) { $0 + $1.price }
            
            if count > 0 {
                stats.append(PriceRangeStat(
                    range: range.label,
                    count: count,
                    totalValue: totalValue
                ))
            }
        }
        
        return stats
    }
    
    // 时间分布统计数据
    private var timeDistributionStats: [TimeDistributionStat] {
        // 按购买月份分组
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM"
        
        var monthlyStats: [String: (count: Int, value: Double)] = [:]
        
        for asset in filteredAssets {
            let dateString = dateFormatter.string(from: asset.wrappedPurchaseDate)
            let currentStat = monthlyStats[dateString] ?? (0, 0)
            monthlyStats[dateString] = (currentStat.count + 1, currentStat.value + asset.price)
        }
        
        // 转换为数组并排序
        var stats: [TimeDistributionStat] = monthlyStats.map { dateString, stat in
            TimeDistributionStat(
                period: dateString,
                count: stat.count,
                totalValue: stat.value
            )
        }
        
        // 按日期排序
        stats.sort { $0.period < $1.period }
        
        return stats
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 时间范围选择器
                Picker("时间范围", selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCasesByOrder, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                // 总览卡片
                OverviewCard(
                    assetCount: filteredAssets.count,
                    totalValue: filteredAssets.reduce(0) { $0 + $1.price },
                    inUseCount: filteredAssets.filter { $0.currentlyInUse }.count
                )
                .padding(.horizontal)
                
                // 图表类型选择器
                Picker("图表类型", selection: $selectedChartType) {
                    ForEach(ChartType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                // 图表区域
                VStack(alignment: .leading, spacing: 10) {
                    Text(selectedChartType.rawValue)
                        .font(.headline)
                        .padding(.horizontal)
                    
                    switch selectedChartType {
                    case .category:
                        CategoryChartView(stats: categoryStats)
                    case .priceRange:
                        PriceRangeChartView(stats: priceRangeStats)
                    case .timeDistribution:
                        TimeDistributionChartView(stats: timeDistributionStats)
                    }
                }
                
                // 警告和提示
                if !assetRepository.lowUsageRemainingAssets.isEmpty {
                    WarningCard(
                        title: "使用次数警告",
                        message: "您有 \(assetRepository.lowUsageRemainingAssets.count) 个资产的剩余使用次数较低",
                        systemImage: "exclamationmark.triangle",
                        color: .yellow,
                        assets: assetRepository.lowUsageRemainingAssets
                    )
                    .padding(.horizontal)
                }
                
                if !assetRepository.soonExpiredWarrantyAssets.isEmpty {
                    WarningCard(
                        title: "保修即将到期",
                        message: "您有 \(assetRepository.soonExpiredWarrantyAssets.count) 个资产的保修即将到期",
                        systemImage: "clock",
                        color: .orange,
                        assets: assetRepository.soonExpiredWarrantyAssets
                    )
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("资产统计")
    }
}

// MARK: - 辅助扩展

extension StatisticsView.TimeRange {
    static var allCasesByOrder: [StatisticsView.TimeRange] {
        [.lastMonth, .lastQuarter, .lastYear, .allTime]
    }
}

// MARK: - 统计数据模型

struct CategoryStat: Identifiable {
    let id: UUID
    let name: String
    let count: Int
    let totalValue: Double
    
    var formattedValue: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: totalValue)) ?? "¥0.00"
    }
}

struct PriceRangeStat: Identifiable {
    let id = UUID()
    let range: String
    let count: Int
    let totalValue: Double
    
    var formattedValue: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: totalValue)) ?? "¥0.00"
    }
}

struct TimeDistributionStat: Identifiable {
    let id = UUID()
    let period: String
    let count: Int
    let totalValue: Double
    
    var formattedValue: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: totalValue)) ?? "¥0.00"
    }
}

// MARK: - 组件视图

// 总览卡片
struct OverviewCard: View {
    let assetCount: Int
    let totalValue: Double
    let inUseCount: Int
    
    private var formattedTotalValue: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: totalValue)) ?? "¥0.00"
    }
    
    var body: some View {
        VStack {
            Text("资产总览")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 20) {
                StatItem(title: "总数量", value: "\(assetCount)", systemImage: "number", color: .blue)
                
                StatItem(title: "总价值", value: formattedTotalValue, systemImage: "dollarsign.circle", color: .green)
                
                StatItem(title: "使用中", value: "\(inUseCount)", systemImage: "checkmark.circle", color: .orange)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

// 统计项
struct StatItem: View {
    let title: String
    let value: String
    let systemImage: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// 警告卡片
struct WarningCard: View {
    let title: String
    let message: String
    let systemImage: String
    let color: Color
    let assets: [Asset]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            Text(message)
                .font(.subheadline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(assets) { asset in
                        NavigationLink(destination: AssetDetailView(asset: asset)) {
                            WarningAssetCard(asset: asset)
                        }
                    }
                }
            }
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }
}

// 警告资产卡片
struct WarningAssetCard: View {
    let asset: Asset
    
    // 添加一个日期格式化器作为属性
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(asset.wrappedName)
                .font(.caption)
                .fontWeight(.bold)
                .lineLimit(1)
            
            if asset.totalUses > 0 {
                Text("剩余: \(asset.remainingUsesCount)")
                    .font(.caption2)
                    .foregroundColor(asset.isLowOnRemainingUses ? .red : .secondary)
            }
            
            if let warrantyDate = asset.wrappedWarrantyEndDate, asset.warrantyStatus == .expiringSoon {
                Text("保修至: \(dateFormatter.string(from: warrantyDate))")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
        .padding(8)
        .frame(width: 120)
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - 图表视图

// 类别图表
struct CategoryChartView: View {
    let stats: [CategoryStat]
    
    var body: some View {
        VStack {
            // 饼图
            if !stats.isEmpty {
                Chart {
                    ForEach(stats) { stat in
                        SectorMark(
                            angle: .value("总价值", stat.totalValue),
                            innerRadius: .ratio(0.6),
                            angularInset: 1
                        )
                        .foregroundStyle(by: .value("类别", stat.name))
                        .annotation(position: .overlay) {
                            if stat.totalValue / stats.reduce(0, { $0 + $1.totalValue }) > 0.05 {
                                Text("\(Int(stat.totalValue / stats.reduce(0, { $0 + $1.totalValue }) * 100))%")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
                .frame(height: 200)
                .padding(.horizontal)
            } else {
                Text("没有符合条件的数据")
                    .foregroundColor(.secondary)
                    .frame(height: 200)
            }
            
            // 表格
            VStack(spacing: 10) {
                HStack {
                    Text("类别")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("数量")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 60)
                    
                    Text("总价值")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .trailing)
                }
                
                Divider()
                
                ForEach(stats) { stat in
                    HStack {
                        Text(stat.name)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(1)
                        
                        Text("\(stat.count)")
                            .font(.subheadline)
                            .frame(width: 60)
                        
                        Text(stat.formattedValue)
                            .font(.subheadline)
                            .frame(width: 80, alignment: .trailing)
                    }
                    
                    Divider()
                }
            }
            .padding()
        }
    }
}

// 价格区间图表
struct PriceRangeChartView: View {
    let stats: [PriceRangeStat]
    
    var body: some View {
        VStack {
            // 柱状图
            if !stats.isEmpty {
                Chart {
                    ForEach(stats) { stat in
                        BarMark(
                            x: .value("价格区间", stat.range),
                            y: .value("数量", stat.count)
                        )
                        .foregroundStyle(by: .value("价格区间", stat.range))
                    }
                }
                .frame(height: 200)
                .padding(.horizontal)
            } else {
                Text("没有符合条件的数据")
                    .foregroundColor(.secondary)
                    .frame(height: 200)
            }
            
            // 表格
            VStack(spacing: 10) {
                HStack {
                    Text("价格区间")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("数量")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 60)
                    
                    Text("总价值")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .trailing)
                }
                
                Divider()
                
                ForEach(stats) { stat in
                    HStack {
                        Text(stat.range)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text("\(stat.count)")
                            .font(.subheadline)
                            .frame(width: 60)
                        
                        Text(stat.formattedValue)
                            .font(.subheadline)
                            .frame(width: 80, alignment: .trailing)
                    }
                    
                    Divider()
                }
            }
            .padding()
        }
    }
}

// 时间分布图表
struct TimeDistributionChartView: View {
    let stats: [TimeDistributionStat]
    
    var body: some View {
        VStack {
            // 折线图
            if !stats.isEmpty {
                Chart {
                    ForEach(stats) { stat in
                        LineMark(
                            x: .value("时间", stat.period),
                            y: .value("数量", stat.count)
                        )
                        .foregroundStyle(Color.blue)
                        .symbol {
                            Circle()
                                .strokeBorder(Color.blue, lineWidth: 2)
                                .frame(width: 10, height: 10)
                        }
                        
                        AreaMark(
                            x: .value("时间", stat.period),
                            y: .value("数量", stat.count)
                        )
                        .foregroundStyle(Color.blue.opacity(0.1))
                    }
                }
                .frame(height: 200)
                .padding(.horizontal)
            } else {
                Text("没有符合条件的数据")
                    .foregroundColor(.secondary)
                    .frame(height: 200)
            }
            
            // 表格
            VStack(spacing: 10) {
                HStack {
                    Text("时间")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("数量")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 60)
                    
                    Text("总价值")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .trailing)
                }
                
                Divider()
                
                ForEach(stats) { stat in
                    HStack {
                        Text(stat.period)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text("\(stat.count)")
                            .font(.subheadline)
                            .frame(width: 60)
                        
                        Text(stat.formattedValue)
                            .font(.subheadline)
                            .frame(width: 80, alignment: .trailing)
                    }
                    
                    Divider()
                }
            }
            .padding()
        }
    }
}

#Preview {
    NavigationStack {
        StatisticsView()
            .environmentObject(AssetRepository(
                context: PersistenceController.preview.container.viewContext,
                purchaseManager: PurchaseManager.preview
            ))
    }
} 