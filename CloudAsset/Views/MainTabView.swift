import SwiftUI

struct MainTabView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @EnvironmentObject private var assetRepository: AssetRepository
    @EnvironmentObject private var cameraManager: CameraManager
    
    var body: some View {
        TabView {
            // 资产标签
            NavigationStack {
                AssetListView()
            }
            .tabItem {
                Label("资产", systemImage: "briefcase")
            }
            
            // 类别标签
            NavigationStack {
                CategoryListView()
            }
            .tabItem {
                Label("类别", systemImage: "folder")
            }
            
            // 统计标签
            NavigationStack {
                StatisticsView()
            }
            .tabItem {
                Label("统计", systemImage: "chart.pie")
            }
            
            // 设置标签
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("设置", systemImage: "gear")
            }
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let purchaseManagerInstance = PurchaseManager.preview
    let assetRepository = AssetRepository(
        context: context,
        purchaseManager: purchaseManagerInstance
    )
    
    MainTabView()
        .environment(\.managedObjectContext, context)
        .environmentObject(purchaseManagerInstance)
        .environmentObject(assetRepository)
        .environmentObject(CameraManager())
} 