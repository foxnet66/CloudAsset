import SwiftUI

struct AssetDetailView: View {
    @EnvironmentObject private var assetRepository: AssetRepository
    
    let asset: Asset
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingImageViewer = false
    @State private var selectedImage: UIImage?
    
    // 格式化日期的辅助方法
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 状态和价格
                HStack {
                    if asset.currentlyInUse {
                        StatusBadge(text: "正在使用", color: .green)
                    }
                    
                    Spacer()
                    
                    Text(asset.formattedPrice)
                        .font(.title)
                        .fontWeight(.bold)
                }
                .padding(.top)
                
                // 如果有图片，显示图片
                if let imageData = asset.imageData, let uiImage = UIImage(data: imageData) {
                    Button {
                        selectedImage = uiImage
                        showingImageViewer = true
                    } label: {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 300)
                            .cornerRadius(12)
                    }
                }
                
                // 资产信息部分
                GroupBox("基本信息") {
                    VStack(alignment: .leading, spacing: 12) {
                        DetailRow(label: "类别", value: asset.category?.wrappedName ?? "未分类")
                        DetailRow(label: "购买日期", value: dateFormatter.string(from: asset.wrappedPurchaseDate))
                        
                        if let warrantyDate = asset.wrappedWarrantyEndDate {
                            HStack {
                                Text("保修截止")
                                Spacer()
                                HStack {
                                    Text(dateFormatter.string(from: warrantyDate))
                                    WarrantyBadge(status: asset.warrantyStatus)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // 使用情况
                if asset.totalUses > 0 {
                    GroupBox("使用情况") {
                        VStack(alignment: .leading, spacing: 12) {
                            DetailRow(label: "总次数", value: "\(asset.totalUses)")
                            DetailRow(label: "已用次数", value: "\(asset.usedCount)")
                            DetailRow(label: "剩余次数", value: "\(asset.remainingUsesCount)")
                            
                            if asset.remainingUsesCount > 0 {
                                Button {
                                    _ = assetRepository.incrementAssetUsedCount(id: asset.wrappedId)
                                } label: {
                                    Label("增加使用次数", systemImage: "plus.circle")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .padding(.top, 4)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // 效率指标
                GroupBox("使用效率") {
                    VStack(alignment: .leading, spacing: 12) {
                        DetailRow(label: "使用天数", value: "\(asset.usageDays) 天")
                        DetailRow(label: "日均成本", value: asset.formattedDailyAveragePrice)
                    }
                    .padding(.vertical, 4)
                }
                
                // 备注
                if !asset.wrappedNotes.isEmpty {
                    GroupBox("备注") {
                        Text(asset.wrappedNotes)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                    }
                }
                
                // 按钮区域
                GroupBox {
                    VStack(spacing: 12) {
                        Button {
                            _ = assetRepository.toggleAssetInUse(id: asset.wrappedId)
                        } label: {
                            Label(
                                asset.currentlyInUse ? "标记为未使用" : "标记为正在使用",
                                systemImage: asset.currentlyInUse ? "xmark.circle" : "checkmark.circle"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        
                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            Label("删除资产", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding()
        }
        .navigationTitle(asset.wrappedName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingEditSheet = true
                } label: {
                    Text("编辑")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            NavigationStack {
                AssetFormView(mode: .edit(asset: asset))
            }
        }
        .sheet(isPresented: $showingImageViewer) {
            if let image = selectedImage {
                ImageViewerView(image: image)
            }
        }
        .alert("确认删除", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                _ = assetRepository.deleteAsset(id: asset.wrappedId)
            }
        } message: {
            Text("确定要删除\"\(asset.wrappedName)\"吗？该操作不可撤销。")
        }
    }
}

// 详情行
struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

// 保修状态徽章
struct WarrantyBadge: View {
    let status: WarrantyStatus
    
    var color: Color {
        switch status {
        case .valid:
            return .green
        case .expiringSoon:
            return .yellow
        case .expired:
            return .red
        case .noWarranty:
            return .gray
        }
    }
    
    var body: some View {
        Text(status.description)
            .font(.caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}

// 状态徽章
struct StatusBadge: View {
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// 图片查看器
struct ImageViewerView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .padding()
                    }
                }
                Spacer()
            }
        }
    }
}

// 预览包装器结构体
struct AssetDetailPreview: View {
    var body: some View {
        let context = PersistenceController.preview.container.viewContext
        
        let asset = Asset(context: context)
        asset.id = UUID()
        asset.name = "MacBook Pro 16寸"
        asset.price = 18999
        asset.purchaseDate = Date()
        asset.warrantyEndDate = Calendar.current.date(byAdding: .year, value: 1, to: Date())
        asset.totalUses = 100
        asset.usedCount = 45
        asset.currentlyInUse = true
        asset.notes = "公司配发的工作电脑，性能很好"
        asset.createdAt = Date()
        asset.updatedAt = Date()
        
        let purchaseManager = PurchaseManager.preview
        let repository = AssetRepository(
            context: context, 
            purchaseManager: purchaseManager
        )
        
        return NavigationStack {
            AssetDetailView(asset: asset)
                .environmentObject(repository)
                .environment(\.managedObjectContext, context)
        }
    }
}

// 预览
#Preview {
    AssetDetailPreview()
} 