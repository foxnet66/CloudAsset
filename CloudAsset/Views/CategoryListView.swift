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
    private let iconOptions: [(icon: String, label: String)] = [
        // 电子设备类
        ("laptopcomputer", "笔记本"), ("desktopcomputer", "台式机"), ("tv", "电视"), ("display", "显示器"), ("headphones", "耳机"),
        ("phone", "手机"), ("iphone", "iPhone"), ("ipad", "iPad"), ("applewatch", "智能表"), ("airpods", "耳机"), ("homepod.fill", "音箱"),
        ("gamecontroller", "游戏机"), ("camera", "相机"), ("video", "摄像机"), ("printer", "打印机"), ("keyboard", "键盘"), ("mouse", "鼠标"),
        
        // 家居类
        ("house", "房屋"), ("bed.double", "床"), ("sofa", "沙发"), ("chair", "椅子"), ("table.furniture", "桌子"), ("lamp", "灯"), 
        ("tv.and.mediabox", "影音"), ("refrigerator", "冰箱"), ("oven", "烤箱"), ("washer", "洗衣机"), ("microwave", "微波炉"),
        
        // 交通工具
        ("car", "汽车"), ("bicycle", "自行车"), ("airplane", "飞机"), ("bus", "公交车"), ("tram.fill", "电车"), ("scooter", "滑板车"),
        
        // 金融类
        ("creditcard", "信用卡"), ("creditcard.fill", "信用卡"), ("banknote", "钞票"), ("dollarsign.circle", "货币"), 
        ("dollarsign.square", "货币"), ("bag", "购物袋"), ("cart", "购物车"), ("tag", "标签"), ("giftcard", "礼品卡"), ("wallet.pass", "钱包"),
        
        // 办公用品
        ("folder", "文件夹"), ("doc", "文档"), ("book", "书籍"), ("newspaper", "报纸"), ("briefcase", "公文包"), ("case", "箱子"),
        ("paperclip", "回形针"), ("ruler", "尺子"), ("pencil", "铅笔"), ("highlighter", "荧光笔"), ("scissors", "剪刀"), ("paintbrush", "画笔"),
        
        // 服装/个人物品
        ("tshirt", "衣服"), ("backpack", "背包"), ("handbag", "手提包"), ("eyeglasses", "眼镜"), ("watch", "手表"), ("shoe", "鞋子"),
        
        // 工具
        ("hammer", "锤子"), ("wrench", "扳手"), ("screwdriver", "螺丝刀"), ("powerplug", "电源"), ("lightbulb", "灯泡"), ("battery.100", "电池"),
        
        // 收藏品
        ("photo", "照片"), ("film", "胶片"), ("guitars", "吉他"), ("pianokeys", "钢琴"), ("book.closed", "藏书"), ("medal", "奖牌"),
        
        // 珠宝/奢侈品
        ("diamond", "钻石"), ("crown", "皇冠"), ("seal", "印章"), ("wand.and.stars", "魔杖"), ("gift", "礼物"), ("sparkles", "珠宝")
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
                    LazyVGrid(columns: Array(repeating: GridItem(.adaptive(minimum: 60), spacing: 8), count: 4), spacing: 12) {
                        ForEach(0..<iconOptions.count, id: \.self) { index in
                            let iconData = iconOptions[index]
                            Button {
                                withAnimation {
                                    icon = iconData.icon
                                    print("选择了图标: \(iconData.icon) - \(iconData.label)")
                                }
                            } label: {
                                VStack(spacing: 4) {
                                    ZStack {
                                        Circle()
                                            .fill(icon == iconData.icon ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                                            .frame(width: 48, height: 48)
                                        
                                        Image(systemName: iconData.icon)
                                            .font(.system(size: 20))
                                            .foregroundColor(icon == iconData.icon ? .blue : .primary)
                                    }
                                    
                                    Text(iconData.label)
                                        .font(.system(size: 10))
                                        .foregroundColor(icon == iconData.icon ? .blue : .secondary)
                                        .lineLimit(1)
                                        .fixedSize()
                                }
                                .frame(width: 60, height: 70)
                            }
                            .buttonStyle(BorderlessButtonStyle()) // 阻止点击事件传播
                            .id("icon_\(iconData.icon)")
                        }
                    }
                    .padding(10)
                }
                .frame(height: 320)
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