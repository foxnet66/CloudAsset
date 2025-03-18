import SwiftUI

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
                        
                        // 添加测试按钮（仅在调试模式下显示）
                        #if DEBUG
                        Divider()
                            .padding(.vertical)
                        
                        Button {
                            Task {
                                await purchaseManager.toggleProStatusForTesting()
                                dismiss()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "wrench.fill")
                                Text("测试：切换专业版状态")
                            }
                            .frame(minWidth: 200)
                            .padding()
                            .background(Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        #endif
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
    ProUpgradeView()
        .environmentObject(PurchaseManager.previewFree)
} 