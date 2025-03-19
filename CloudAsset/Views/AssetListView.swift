import SwiftUI

struct AssetListView: View {
    @EnvironmentObject private var assetRepository: AssetRepository
    @EnvironmentObject private var purchaseManager: PurchaseManager
    
    @State private var searchText = ""
    @State private var selectedCategoryId: UUID?
    @State private var showingAddAsset = false
    @State private var showingProUpgrade = false
    @State private var usageFilterMode: UsageFilterMode = .all // 更改为使用枚举
    @State private var refreshTrigger = UUID() // 使用UUID来强制视图更新
    @State private var isManuallyRefreshing = false // 记录是否正在手动刷新
    @State private var refreshID = UUID() // 添加一个用于刷新视图的ID
    @State private var filterChangeCounter = 0 // 跟踪过滤器更改
    
    // 使用状态过滤模式
    enum UsageFilterMode {
        case all          // 显示所有
        case inUse        // 使用中的资产
        case notInUse     // 未使用的资产
    }
    
    // 异步刷新方法，返回Task以支持取消
    private func performRefresh() async {
        isManuallyRefreshing = true
        
        // 调用刷新资产
        assetRepository.refreshAssets()
        
        // 等待一小段时间，给UI足够的时间响应
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
        
        // 使用主线程更新UI状态
        await MainActor.run {
            refreshTrigger = UUID()
            isManuallyRefreshing = false
        }
    }
    
    private var filteredAssets: [Asset] {
        var result = assetRepository.assets
        
        // 按类别筛选
        if let categoryId = selectedCategoryId {
            result = result.filter { $0.category?.wrappedId == categoryId }
        }
        
        // 按使用状态筛选
        if usageFilterMode == .inUse {
            result = result.filter { $0.currentlyInUse }
        } else if usageFilterMode == .notInUse {
            result = result.filter { !$0.currentlyInUse }
        }
        
        // 按搜索文本筛选
        if !searchText.isEmpty {
            result = result.filter {
                $0.wrappedName.localizedCaseInsensitiveContains(searchText) ||
                $0.wrappedNotes.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return result
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 下拉列表筛选器
            VStack(spacing: 4) {
                // 直接显示下拉列表，删除标题栏
                HStack(spacing: 12) {
                    // 类别下拉列表
                    Menu {
                        Button {
                            selectedCategoryId = nil
                            filterChangeCounter += 1
                        } label: {
                            HStack {
                                Text("全部类别")
                                if selectedCategoryId == nil {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        
                        Divider()
                        
                        ForEach(assetRepository.categories) { category in
                            Button {
                                selectedCategoryId = category.wrappedId
                                filterChangeCounter += 1
                            } label: {
                                HStack {
                                    Image(systemName: category.wrappedIcon)
                                    Text(category.wrappedName)
                                    if selectedCategoryId == category.wrappedId {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            if let categoryId = selectedCategoryId,
                               let category = assetRepository.categories.first(where: { $0.wrappedId == categoryId }) {
                                Image(systemName: category.wrappedIcon)
                                    .foregroundColor(.blue)
                                Text(category.wrappedName)
                                    .foregroundColor(.primary)
                            } else {
                                Image(systemName: "folder")
                                    .foregroundColor(.blue)
                                Text("选择类别")
                                    .foregroundColor(.primary)
                            }
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                    }
                    
                    // 使用状态下拉列表
                    Menu {
                        Button {
                            usageFilterMode = .all
                            filterChangeCounter += 1
                        } label: {
                            HStack {
                                Text("全部状态")
                                if usageFilterMode == .all {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        
                        Button {
                            usageFilterMode = .inUse
                            filterChangeCounter += 1
                        } label: {
                            HStack {
                                Text("使用中")
                                if usageFilterMode == .inUse {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        
                        Button {
                            usageFilterMode = .notInUse
                            filterChangeCounter += 1
                        } label: {
                            HStack {
                                Text("未使用")
                                if usageFilterMode == .notInUse {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: usageFilterMode == .all ? "circle.grid.2x2" : 
                                            usageFilterMode == .inUse ? "checkmark.circle.fill" : "xmark.circle")
                                .foregroundColor(.blue)
                            Text(usageFilterMode == .all ? "全部状态" : 
                                 usageFilterMode == .inUse ? "使用中" : "未使用")
                                .foregroundColor(.primary)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 4)
                
                // 显示当前选中的过滤条件指示器
                if selectedCategoryId != nil || usageFilterMode != .all {
                    HStack(spacing: 8) {
                        // 显示选中的类别
                        if let categoryId = selectedCategoryId, 
                          let selectedCategory = assetRepository.categories.first(where: { $0.wrappedId == categoryId }) {
                            Chip(
                                label: "类别: \(selectedCategory.wrappedName)",
                                icon: selectedCategory.wrappedIcon,
                                onClear: { 
                                    selectedCategoryId = nil
                                    filterChangeCounter += 1
                                }
                            )
                        }
                        
                        // 显示选中的使用状态
                        if usageFilterMode != .all {
                            let (statusLabel, statusIcon) = usageFilterMode == .inUse ? 
                                ("状态: 使用中", "checkmark.circle.fill") : 
                                ("状态: 未使用", "xmark.circle")
                                
                            Chip(
                                label: statusLabel,
                                icon: statusIcon,
                                onClear: { 
                                    usageFilterMode = .all
                                    filterChangeCounter += 1
                                }
                            )
                        }
                        
                        Spacer()
                        
                        // 清除所有筛选条件按钮
                        if selectedCategoryId != nil && usageFilterMode != .all {
                            Button("清除全部") {
                                selectedCategoryId = nil
                                usageFilterMode = .all
                                filterChangeCounter += 1
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                    .transition(.opacity)
                    .animation(.easeInOut, value: filterChangeCounter)
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 4)
            .background(Color(.systemBackground))
            
            // 资产列表 - 添加下拉刷新
            List {
                ForEach(filteredAssets) { asset in
                    NavigationLink(destination: AssetDetailView(asset: asset)) {
                        AssetRow(asset: asset)
                    }
                }
            }
            .id(refreshTrigger) // 使用id修饰符强制整个列表刷新
            .refreshable {
                // 添加下拉刷新功能
                await performRefresh()
            }
            .searchable(text: $searchText, prompt: "搜索资产")
            .overlay {
                if filteredAssets.isEmpty {
                    ContentUnavailableView(
                        label: {
                            Label(
                                searchText.isEmpty ? "没有资产" : "未找到匹配的资产",
                                systemImage: searchText.isEmpty ? "tray" : "magnifyingglass"
                            )
                        },
                        description: {
                            Text(searchText.isEmpty ? "点击右上角的 + 添加新资产" : "尝试其他搜索词")
                        },
                        actions: {
                            if searchText.isEmpty {
                                Button("添加资产") {
                                    showingAddAsset = true
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    )
                }
            }
        }
        .navigationTitle("我的资产")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    // 添加刷新按钮
                    Button {
                        // 手动刷新数据
                        Task {
                            await performRefresh()
                        }
                    } label: {
                        if isManuallyRefreshing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    
                    // 添加资产按钮
                    Button {
                        if assetRepository.hasReachedFreeLimit {
                            showingProUpgrade = true
                        } else {
                            showingAddAsset = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddAsset, onDismiss: {
            // 表单关闭时刷新数据
            assetRepository.refreshAssets()
            
            // 短暂延迟后更新UI
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                refreshTrigger = UUID()
            }
        }) {
            NavigationStack {
                AssetFormView(mode: .add)
            }
        }
        .sheet(isPresented: $showingProUpgrade) {
            ProUpgradeView()
        }
        .onAppear {
            // 每次视图出现时刷新数据
            Task {
                await performRefresh()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AssetDataChanged"))) { _ in
            // 接收到数据变化通知后刷新
            Task {
                await performRefresh()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AssetDataChanging"))) { _ in
            // 接收到数据即将变化的通知，标记正在刷新状态
            isManuallyRefreshing = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AssetDataRefreshCompleted"))) { _ in
            // 数据刷新完成后更新UI
            refreshTrigger = UUID()
            isManuallyRefreshing = false
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("CurrencyChanged"))) { _ in
            // 货币设置改变时，通过更新refreshID来强制视图刷新
            refreshID = UUID()
        }
    }
}

// 优化的筛选按钮
struct FilterButton: View {
    let title: String
    let iconName: String
    let isSelected: Bool
    let action: () -> Void
    var textColor: Color { isSelected ? .blue : .primary }
    var backgroundColor: Color { isSelected ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1) }
    var showBadge: Bool = false  // 可以在需要时显示提示标记
    var badgeCount: Int = 0
    var compactMode: Bool = false  // 在空间有限时可以启用紧凑模式
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: compactMode ? 4 : 6) {
                Image(systemName: iconName)
                    .font(compactMode ? .footnote : .body)
                
                if !compactMode {
                    Text(title)
                        .lineLimit(1)
                }
                
                // 可选的徽章
                if showBadge && badgeCount > 0 {
                    Text("\(badgeCount)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
            }
            .padding(.vertical, compactMode ? 6 : 8)
            .padding(.horizontal, compactMode ? 8 : 12)
            .background(backgroundColor)
            .foregroundColor(textColor)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .shadow(color: isSelected ? Color.blue.opacity(0.3) : Color.clear, radius: 2, x: 0, y: 1)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// 资产行
struct AssetRow: View {
    let asset: Asset
    
    var body: some View {
        HStack {
            // 缩略图
            if let imageData = asset.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: asset.category?.wrappedIcon ?? "square")
                        .font(.system(size: 24))
                        .foregroundColor(.gray)
                }
            }
            
            // 资产信息
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(asset.wrappedName)
                        .font(.headline)
                    
                    if asset.currentlyInUse {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
                
                Text(asset.formattedPrice)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    if let category = asset.category {
                        HStack(spacing: 2) {
                            Image(systemName: category.wrappedIcon)
                                .font(.caption2)
                            Text(category.wrappedName)
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // 次数和使用信息（如果有）
                    if asset.totalUses > 0 {
                        Text("剩余: \(asset.remainingUsesCount)")
                            .font(.caption)
                            .foregroundColor(asset.isLowOnRemainingUses ? .red : .secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// CategoryFilterButton - 带长按手势的类别筛选按钮
struct CategoryFilterButton: View {
    let category: Category
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var showingDetails = false
    @State private var longPressInProgress = false

    var body: some View {
        FilterButton(
            title: category.wrappedName,
            iconName: category.wrappedIcon,
            isSelected: isSelected,
            action: onTap
        )
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    hapticFeedback()
                    showingDetails = true
                }
        )
        .popover(isPresented: $showingDetails) {
            CategoryInfoPopover(category: category)
        }
        .scaleEffect(longPressInProgress ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: longPressInProgress)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    longPressInProgress = true
                }
                .onEnded { _ in
                    longPressInProgress = false
                }
        )
    }
    
    private func hapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

// 类别信息弹出框
struct CategoryInfoPopover: View {
    let category: Category
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: category.wrappedIcon)
                    .font(.title)
                    .foregroundColor(.blue)
                
                Text(category.wrappedName)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            .padding(.bottom, 5)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "archivebox")
                    Text("\(category.assetArray.count) 个资产")
                }
                
                if category.assetArray.count > 0 {
                    HStack {
                        Image(systemName: "banknote")
                        Text("总价值: \(category.formattedTotalValue)")
                    }
                }
                
                // 可以显示更多类别统计信息
                if !category.wrappedNotes.isEmpty {
                    Divider()
                    
                    VStack(alignment: .leading) {
                        Text("备注")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(category.wrappedNotes)
                            .padding(.top, 2)
                    }
                }
            }
        }
        .padding()
        .frame(width: 250)
    }
}

// Chip 组件 - 用于显示过滤条件
struct Chip: View {
    let label: String
    let icon: String
    let onClear: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            
            Text(label)
                .font(.caption)
                .lineLimit(1)
            
            Button(action: onClear) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color.blue.opacity(0.1))
        .foregroundColor(.blue)
        .cornerRadius(16)
    }
}

#Preview {
    AssetListView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(AssetRepository(
            context: PersistenceController.preview.container.viewContext,
            purchaseManager: PurchaseManager.preview
        ))
        .environmentObject(PurchaseManager.preview)
} 