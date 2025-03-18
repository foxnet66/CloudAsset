//
//  InfoPlistConfig.swift
//  CloudAsset
//
//  Created on 18/3/25.
//

import Foundation

// 这个类设置了应用程序运行时需要的Info.plist权限配置
// 由于我们使用了自动生成的Info.plist，需要在代码中设置一些键值
class InfoPlistConfig {
    // 单例模式
    static let shared = InfoPlistConfig()
    
    private init() {}
    
    // 添加与Info.plist相关的权限描述
    func setupPermissionsInfo() {
        // 添加相机使用权限描述
        if Bundle.main.infoDictionary?["NSCameraUsageDescription"] == nil {
            // 由于Info.plist是在编译时生成的，无法在运行时修改
            // 此处代码仅供参考，实际应用中应在项目配置中设置这些信息
            print("请确保在项目中设置了相机权限描述 (NSCameraUsageDescription)")
            print("相机权限描述：允许访问相机以便您拍摄资产照片")
        }
        
        // 添加照片库使用权限描述
        if Bundle.main.infoDictionary?["NSPhotoLibraryUsageDescription"] == nil {
            print("请确保在项目中设置了照片库权限描述 (NSPhotoLibraryUsageDescription)")
            print("照片库权限描述：允许访问照片库以便您选择资产照片")
        }
        
        // 输出当前应用包含的所有Info.plist键值对，用于调试
        #if DEBUG
        if let infoDictionary = Bundle.main.infoDictionary {
            print("当前Info.plist内容:")
            for (key, value) in infoDictionary {
                print("\(key): \(value)")
            }
        }
        #endif
    }
} 