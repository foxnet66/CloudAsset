import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @EnvironmentObject private var assetRepository: AssetRepository
    
    @State private var showingProUpgrade = false
    @State private var showingAbout = false
    @State private var showingExportOptions = false
    @State private var exportText = ""
    @State private var showingExportResult = false
    
    // 获取App版本
    private var appVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    // 获取构建号
    private var buildNumber: String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    var body: some View {
        List {
            // 用户信息部分
            Section(header: Text("账户")) {
                HStack {
                    Image(systemName: purchaseManager.isPro ? "person.fill.checkmark" : "person")
                        .foregroundColor(purchaseManager.isPro ? .blue : .gray)
                        .font(.title)
                        .frame(width: 40, height: 40)
                        .background(purchaseManager.isPro ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                        .cornerRadius(20)
                    
                    VStack(alignment: .leading) {
                        Text(purchaseManager.isPro ? "专业版用户" : "免费版用户")
                            .font(.headline)
                        
                        if !purchaseManager.isPro {
                            Text("已使用 \(assetRepository.totalAssetCount)/\(purchaseManager.freeVersionAssetLimit) 个资产")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if !purchaseManager.isPro {
                        Button("升级") {
                            showingProUpgrade = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                    }
                }
                .padding(.vertical, 4)
                
                if purchaseManager.isPro {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                        Text("您已解锁所有高级功能")
                            .foregroundColor(.green)
                    }
                } else {
                    Button {
                        showingProUpgrade = true
                    } label: {
                        HStack {
                            Image(systemName: "crown")
                            Text("升级到专业版")
                            Spacer()
                            Text(purchaseManager.proVersionPrice)
                                .fontWeight(.semibold)
                        }
                    }
                    
                    Button {
                        Task {
                            await purchaseManager.restorePurchases()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("恢复购买")
                        }
                    }
                }
            }
            
            // 数据管理
            Section(header: Text("数据管理")) {
                Button {
                    showingExportOptions = true
                } label: {
                    Label("导出数据", systemImage: "arrow.up.doc")
                }
                
                NavigationLink {
                    AboutDataPrivacyView()
                } label: {
                    Label("数据隐私", systemImage: "shield")
                }
            }
            
            // 关于
            Section(header: Text("关于")) {
                Button {
                    showingAbout = true
                } label: {
                    Label("关于CloudAsset", systemImage: "info.circle")
                }
                
                HStack {
                    Text("版本")
                    Spacer()
                    Text("\(appVersion) (\(buildNumber))")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("设置")
        .sheet(isPresented: $showingProUpgrade) {
            ProUpgradeView()
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
        .alert("导出选项", isPresented: $showingExportOptions) {
            Button("导出CSV") {
                exportText = exportToCSV()
                showingExportResult = true
            }
            Button("导出JSON") {
                exportText = exportToJSON()
                showingExportResult = true
            }
            Button("取消", role: .cancel) {}
        }
        .alert("导出数据", isPresented: $showingExportResult) {
            Button("确定") {}
            Button("复制到剪贴板") {
                UIPasteboard.general.string = exportText
            }
        } message: {
            Text("数据已成功导出。您可以复制到剪贴板使用。")
        }
        .alert(isPresented: .constant(purchaseManager.purchaseError != nil)) {
            Alert(
                title: Text("购买错误"),
                message: Text(purchaseManager.purchaseError ?? "未知错误"),
                dismissButton: .default(Text("确定"))
            )
        }
    }
    
    // 导出CSV
    private func exportToCSV() -> String {
        var csv = "名称,类别,价格,购买日期,保修截止,总次数,已用次数,正在使用,备注\n"
        
        for asset in assetRepository.assets {
            let name = asset.wrappedName.replacingOccurrences(of: ",", with: " ")
            let category = asset.category?.wrappedName.replacingOccurrences(of: ",", with: " ") ?? "未分类"
            let price = String(asset.price)
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            let purchaseDate = dateFormatter.string(from: asset.wrappedPurchaseDate)
            let warrantyDate = asset.wrappedWarrantyEndDate != nil ? dateFormatter.string(from: asset.wrappedWarrantyEndDate!) : ""
            
            let totalUses = String(asset.totalUses)
            let usedCount = String(asset.usedCount)
            let inUse = asset.currentlyInUse ? "是" : "否"
            let notes = asset.wrappedNotes.replacingOccurrences(of: ",", with: " ")
            
            csv += "\(name),\(category),\(price),\(purchaseDate),\(warrantyDate),\(totalUses),\(usedCount),\(inUse),\(notes)\n"
        }
        
        return csv
    }
    
    // 导出JSON
    private func exportToJSON() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        
        var assetsArray: [[String: Any]] = []
        
        for asset in assetRepository.assets {
            var assetDict: [String: Any] = [
                "id": asset.wrappedId.uuidString,
                "name": asset.wrappedName,
                "price": asset.price,
                "purchaseDate": dateFormatter.string(from: asset.wrappedPurchaseDate),
                "currentlyInUse": asset.currentlyInUse,
                "totalUses": asset.totalUses,
                "usedCount": asset.usedCount,
                "notes": asset.wrappedNotes
            ]
            
            if let warrantyDate = asset.wrappedWarrantyEndDate {
                assetDict["warrantyEndDate"] = dateFormatter.string(from: warrantyDate)
            }
            
            if let category = asset.category {
                assetDict["category"] = [
                    "id": category.wrappedId.uuidString,
                    "name": category.wrappedName,
                    "icon": category.wrappedIcon
                ]
            }
            
            assetsArray.append(assetDict)
        }
        
        let rootDict: [String: Any] = [
            "assets": assetsArray,
            "exportDate": dateFormatter.string(from: Date()),
            "appVersion": appVersion
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: rootDict, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        
        return "{\"error\": \"导出失败\"}"
    }
}

// 关于视图
struct AboutView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 15) {
                        Image(systemName: "briefcase.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("CloudAsset")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("个人资产管理工具")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("版本 1.0")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
                
                Section(header: Text("开发者")) {
                    HStack {
                        Text("开发者")
                        Spacer()
                        Text("James Wang")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("版权所有")
                        Spacer()
                        Text("© 2025 Cloud Asset")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("联系我们")) {
                    Button {
                        // 发送邮件
                        if let url = URL(string: "mailto:support@cloudasset.com") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Text("电子邮件")
                            Spacer()
                            Text("support@cloudasset.com")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Button {
                        // 打开网站
                        if let url = URL(string: "https://www.cloudasset.com") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Text("网站")
                            Spacer()
                            Text("www.cloudasset.com")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("关于")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        // 关闭视图
                    }
                }
            }
        }
    }
}

// 数据隐私视图
struct AboutDataPrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Group {
                    Text("数据隐私声明")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("最后更新: 2025年3月17日")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("CloudAsset 应用程序尊重并保护您的隐私。本隐私政策概述了我们如何收集、使用和保护您的信息。")
                        .padding(.top)
                    
                    Text("数据存储")
                        .font(.headline)
                        .padding(.top)
                    
                    Text("• 您的所有资产数据默认存储在您的设备上。\n• 免费版不提供云同步功能，所有数据仅保存在本地。\n• 专业版用户可以选择使用云同步功能，将数据备份到 iCloud。")
                    
                    Text("我们收集的数据")
                        .font(.headline)
                        .padding(.top)
                    
                    Text("• 我们不收集任何用户个人信息，除非您选择使用云同步功能。\n• 云同步功能仅用于将您的资产数据备份到您的 iCloud 账户，我们无法访问这些数据。\n• 我们可能会收集匿名使用统计数据，以帮助我们改进应用程序。")
                    
                    Text("内购")
                        .font(.headline)
                        .padding(.top)
                    
                    Text("• 购买专业版时，交易由 Apple 处理，我们不收集或存储您的付款信息。\n• 我们会保存您的购买状态，以便为您提供相应的功能。")
                }
                
                Group {
                    Text("相机和照片权限")
                        .font(.headline)
                        .padding(.top)
                    
                    Text("• 我们请求相机权限，以便您可以拍摄资产照片。\n• 我们请求照片库权限，以便您可以从相册中选择图片。\n• 所有照片数据仅存储在本地和/或您的 iCloud 账户（如果您启用了云同步）。")
                    
                    Text("数据删除")
                        .font(.headline)
                        .padding(.top)
                    
                    Text("• 您可以随时从应用程序中删除任何资产或类别。\n• 卸载应用程序将删除所有本地存储的数据。\n• 如果您使用云同步，您可以通过 iCloud 设置管理或删除备份数据。")
                    
                    Text("联系我们")
                        .font(.headline)
                        .padding(.top)
                    
                    Text("如果您对隐私政策有任何疑问，请通过 support@cloudasset.com 联系我们。")
                }
            }
            .padding()
        }
        .navigationTitle("数据隐私")
    }
}

// 专业版升级视图
struct ProUpgradeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var purchaseManager: PurchaseManager
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 30) {
                    // 标题
                    VStack(spacing: 15) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.yellow)
                        
                        Text("升级到专业版")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("解锁全部功能，体验更优质的资产管理")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 20)
                    
                    // 功能对比
                    VStack(spacing: 20) {
                        FeatureComparisonRow(title: "资产上限", free: "50个", pro: "无限")
                        FeatureComparisonRow(title: "类别管理", free: "预设分类", pro: "自定义分类")
                        FeatureComparisonRow(title: "高级图标", free: "基础图标", pro: "完整图标库")
                        FeatureComparisonRow(title: "云同步", free: "不支持", pro: "支持")
                        FeatureComparisonRow(title: "导出格式", free: "CSV", pro: "CSV和JSON")
                        FeatureComparisonRow(title: "更新", free: "基础更新", pro: "优先更新")
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    // 价格和购买按钮
                    VStack(spacing: 15) {
                        Text(purchaseManager.proVersionPrice)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("一次性购买，终身使用")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Button {
                            Task {
                                await purchaseManager.purchaseProVersion()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "crown.fill")
                                Text("立即升级")
                            }
                            .frame(minWidth: 200)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(purchaseManager.purchaseInProgress)
                        .overlay {
                            if purchaseManager.purchaseInProgress {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                        }
                        
                        Button {
                            Task {
                                await purchaseManager.restorePurchases()
                            }
                        } label: {
                            Text("恢复购买")
                                .foregroundColor(.blue)
                        }
                        .disabled(purchaseManager.purchaseInProgress)
                    }
                    .padding(.vertical)
                }
                .padding(.bottom, 30)
            }
            .navigationTitle("专业版")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if purchaseManager.isPro {
                    // 已经是专业版，关闭窗口
                    dismiss()
                }
            }
        }
    }
}

// 功能对比行
struct FeatureComparisonRow: View {
    let title: String
    let free: String
    let pro: String
    
    var body: some View {
        HStack {
            Text(title)
                .frame(width: 100, alignment: .leading)
            
            Spacer()
            
            VStack {
                Text("免费版")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(free)
                    .fontWeight(.medium)
            }
            .frame(width: 100)
            
            Spacer()
            
            VStack {
                Text("专业版")
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Text(pro)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
            .frame(width: 100)
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(PurchaseManager.preview)
            .environmentObject(AssetRepository(
                context: PersistenceController.preview.container.viewContext,
                purchaseManager: PurchaseManager.preview
            ))
    }
}

#Preview("Pro Upgrade View") {
    ProUpgradeView()
        .environmentObject(PurchaseManager.previewFree)
} 