import SwiftUI

struct AssetListView: View {
    @EnvironmentObject private var assetRepository: AssetRepository
    @EnvironmentObject private var purchaseManager: PurchaseManager
    
    @State private var searchText = ""
    @State private var selectedCategoryId: UUID?
    @State private var showingAddAsset = false
    @State private var showingProUpgrade = false
    @State private var filterByInUse = false
    
    private var filteredAssets: [Asset] {
        var result = assetRepository.assets
        
        // 按类别筛选
        if let categoryId = selectedCategoryId {
            result = result.filter { $0.category?.wrappedId == categoryId }
        }
        
        // 按使用状态筛选
        if filterByInUse {
            result = result.filter { $0.currentlyInUse }
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
        VStack {
            // 类别筛选器
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    FilterButton(
                        title: "全部",
                        iconName: "tray",
                        isSelected: selectedCategoryId == nil && !filterByInUse,
                        action: {
                            selectedCategoryId = nil
                            filterByInUse = false
                        }
                    )
                    
                    FilterButton(
                        title: "使用中",
                        iconName: "checkmark.circle",
                        isSelected: filterByInUse,
                        action: {
                            selectedCategoryId = nil
                            filterByInUse = true
                        }
                    )
                    
                    Divider()
                        .frame(height: 20)
                        .padding(.horizontal)
                    
                    ForEach(assetRepository.categories) { category in
                        FilterButton(
                            title: category.wrappedName,
                            iconName: category.wrappedIcon,
                            isSelected: selectedCategoryId == category.wrappedId,
                            action: {
                                selectedCategoryId = category.wrappedId
                                filterByInUse = false
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top, 5)
            
            // 资产列表
            List {
                ForEach(filteredAssets) { asset in
                    NavigationLink(destination: AssetDetailView(asset: asset)) {
                        AssetRow(asset: asset)
                    }
                }
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
        .sheet(isPresented: $showingAddAsset) {
            NavigationStack {
                AssetFormView(mode: .add)
            }
        }
        .sheet(isPresented: $showingProUpgrade) {
            ProUpgradeView()
        }
    }
}

// 筛选按钮
struct FilterButton: View {
    let title: String
    let iconName: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: iconName)
                Text(title)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isSelected ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
            .foregroundColor(isSelected ? .blue : .primary)
            .cornerRadius(10)
        }
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

#Preview {
    AssetListView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(AssetRepository(
            context: PersistenceController.preview.container.viewContext,
            purchaseManager: PurchaseManager.preview
        ))
        .environmentObject(PurchaseManager.preview)
} 