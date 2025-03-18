//
//  CloudAssetApp.swift
//  CloudAsset
//
//  Created by James Wang on 18/3/25.
//

import SwiftUI
import CoreData

// 在此处定义权限描述的键
// 注意：这些键对应于Info.plist中的权限描述
// NSCameraUsageDescription - 相机权限
// NSPhotoLibraryUsageDescription - 照片库权限

@main
struct CloudAssetApp: App {
    // 持久化存储管理器
    let persistenceController = PersistenceController.shared
    
    // 缓存视图上下文，避免在body中使用self.persistenceController
    private let viewContext: NSManagedObjectContext
    
    // 状态对象
    @StateObject private var purchaseManager: PurchaseManager
    @StateObject private var assetRepository: AssetRepository
    @StateObject private var cameraManager: CameraManager
    
    init() {
        // 保存对persistenceController.container.viewContext的引用
        self.viewContext = persistenceController.container.viewContext
        
        // 初始化状态对象
        let purchaseManagerInstance = PurchaseManager()
        _purchaseManager = StateObject(wrappedValue: purchaseManagerInstance)
        
        let assetRepo = AssetRepository(
            context: viewContext,
            purchaseManager: purchaseManagerInstance
        )
        _assetRepository = StateObject(wrappedValue: assetRepo)
        
        _cameraManager = StateObject(wrappedValue: CameraManager())
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(\.managedObjectContext, self.viewContext)
                .environmentObject(self.purchaseManager)
                .environmentObject(self.assetRepository)
                .environmentObject(self.cameraManager)
        }
    }
}

// 持久化存储控制器
struct PersistenceController {
    static let shared = PersistenceController()
    
    let container: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "CloudAssetModel")
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { description, error in
            if let error = error as NSError? {
                fatalError("加载Core Data失败: \(error), \(error.userInfo)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    // 添加预览辅助方法
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        return controller
    }()
} 