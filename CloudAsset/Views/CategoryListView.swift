import SwiftUI

struct CategoryListView: View {
    @EnvironmentObject private var assetRepository: AssetRepository
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var showingAddSheet = false
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingProUpgrade = false
    @State private var selectedCategory: Category?
    @State private var refreshID = UUID()
    
    var body: some View {
        List {
            ForEach(assetRepository.categories) { category in
                HStack {
                    Image(systemName: category.wrappedIcon)
                        .foregroundColor(.blue)
                        .frame(width: 30)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.wrappedName)
                            .font(.headline)
                        
                        HStack {
                            Text("\(category.assetArray.count) 个资产")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if category.assetArray.count > 0 {
                                Text("总价值: \(category.formattedTotalValue)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // 只在专业版可以编辑类别
                    if purchaseManager.isPro {
                        Button {
                            selectedCategory = category
                            showingEditSheet = true
                        } label: {
                            Image(systemName: "pencil")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    // 跳转到该类别下的资产列表
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if purchaseManager.isPro {
                        Button(role: .destructive) {
                            selectedCategory = category
                            // 如果没有资产可以直接删除，否则显示警告
                            if category.assetArray.isEmpty {
                                deleteCategory()
                            } else {
                                showingDeleteAlert = true
                            }
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    } else {
                        Button {
                            showingProUpgrade = true
                        } label: {
                            Label("专业版", systemImage: "lock")
                        }
                        .tint(.orange)
                    }
                }
            }
        }
        .id(refreshID)
        .navigationTitle("资产类别")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    if purchaseManager.isPro {
                        showingAddSheet = true
                    } else {
                        showingProUpgrade = true
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            NavigationStack {
                CategoryFormView(mode: .add)
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            if let category = selectedCategory {
                NavigationStack {
                    CategoryFormView(mode: .edit(category: category))
                }
            }
        }
        .sheet(isPresented: $showingProUpgrade) {
            ProUpgradeView()
        }
        .alert("确认删除", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                deleteCategory()
            }
        } message: {
            if let category = selectedCategory {
                Text("确定要删除\"\(category.wrappedName)\"类别吗？该类别下的所有资产也将被删除。")
            } else {
                Text("确定要删除此类别吗？该类别下的所有资产也将被删除。")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("CurrencyChanged"))) { _ in
            refreshID = UUID()
        }
    }
    
    private func deleteCategory() {
        if let category = selectedCategory {
            _ = assetRepository.deleteCategory(id: category.wrappedId)
        }
    }
}

// 类别表单（添加/编辑）
struct CategoryFormView: View {
    enum Mode {
        case add
        case edit(category: Category)
    }
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var assetRepository: AssetRepository
    
    let mode: Mode
    @State private var name = ""
    @State private var icon = "folder"
    @State private var notes = ""
    
    @State private var showingErrors = false
    @State private var errorMessages: [String] = []
    
    // 标题
    private var formTitle: String {
        switch mode {
        case .add:
            return "添加类别"
        case .edit:
            return "编辑类别"
        }
    }
    
    // 系统图标选择 - 资产管理相关图标
    private let iconOptions: [String] = [
        // 电子设备类
        "laptopcomputer", "desktopcomputer", "tv", "display", "headphones",
        "phone", "iphone", "ipad", "applewatch", "airpods", "homepod.fill",
        "gamecontroller", "camera", "video", "printer", "keyboard", "mouse",
        
        // 家居类
        "house", "bed.double", "sofa", "chair", "table.furniture", "lamp", 
        "tv.and.mediabox", "refrigerator", "oven", "washer", "microwave",
        
        // 交通工具
        "car", "bicycle", "airplane", "bus", "tram.fill", "scooter",
        
        // 金融类
        "creditcard", "creditcard.fill", "banknote", "dollarsign.circle", 
        "dollarsign.square", "bag", "cart", "tag", "giftcard", "wallet.pass",
        
        // 办公用品
        "folder", "doc", "book", "newspaper", "briefcase", "case",
        "paperclip", "ruler", "pencil", "highlighter", "scissors", "paintbrush",
        
        // 服装/个人物品
        "tshirt", "backpack", "handbag", "eyeglasses", "watch", "shoe",
        
        // 工具
        "hammer", "wrench", "screwdriver", "powerplug", "lightbulb", "battery.100",
        
        // 收藏品
        "photo", "film", "guitars", "pianokeys", "book.closed", "medal",
        
        // 珠宝/奢侈品
        "diamond", "crown", "seal", "wand.and.stars", "gift", "sparkles"
    ]
    
    // 加载现有数据
    private func loadExistingData() {
        if case .edit(let category) = mode {
            name = category.wrappedName
            icon = category.wrappedIcon
            notes = category.wrappedNotes
        }
    }
    
    // 验证表单
    private func validateForm() -> Bool {
        errorMessages.removeAll()
        
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessages.append("类别名称不能为空")
        }
        
        return errorMessages.isEmpty
    }
    
    // 保存类别
    private func saveCategory() {
        if !validateForm() {
            showingErrors = true
            return
        }
        
        switch mode {
        case .add:
            _ = assetRepository.addCategory(
                name: name,
                icon: icon,
                notes: notes.isEmpty ? nil : notes
            )
        case .edit(let category):
            _ = assetRepository.updateCategory(
                id: category.wrappedId,
                name: name,
                icon: icon,
                notes: notes.isEmpty ? nil : notes
            )
        }
        
        dismiss()
    }
    
    var body: some View {
        Form {
            Section(header: Text("基本信息")) {
                TextField("类别名称", text: $name)
            }
            
            Section(header: Text("图标")) {
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.adaptive(minimum: 55), spacing: 10), count: 5), spacing: 12) {
                        ForEach(0..<iconOptions.count, id: \.self) { index in
                            let iconName = iconOptions[index]
                            Button {
                                withAnimation {
                                    icon = iconName
                                    print("选择了图标: \(iconName)")
                                }
                            } label: {
                                VStack {
                                    ZStack {
                                        Circle()
                                            .fill(icon == iconName ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                                            .frame(width: 50, height: 50)
                                        
                                        Image(systemName: iconName)
                                            .font(.system(size: 22))
                                            .foregroundColor(icon == iconName ? .blue : .primary)
                                    }
                                }
                            }
                            .buttonStyle(BorderlessButtonStyle()) // 阻止点击事件传播
                            .id("icon_\(iconName)")
                        }
                    }
                    .padding(10)
                }
                .frame(height: 270)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
            }
            
            Section(header: Text("备注")) {
                TextEditor(text: $notes)
                    .frame(minHeight: 100)
            }
        }
        .navigationTitle(formTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("取消") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("保存") {
                    saveCategory()
                }
            }
        }
        .onAppear {
            loadExistingData()
        }
        .alert("表单错误", isPresented: $showingErrors) {
            Button("确定") { }
        } message: {
            Text(errorMessages.joined(separator: "\n"))
        }
    }
}

#Preview {
    NavigationStack {
        CategoryListView()
            .environmentObject(AssetRepository(
                context: PersistenceController.preview.container.viewContext,
                purchaseManager: PurchaseManager.preview
            ))
            .environmentObject(PurchaseManager.preview)
    }
}