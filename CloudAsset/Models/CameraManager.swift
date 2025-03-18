import Foundation
import SwiftUI
import AVFoundation
import Photos

class CameraManager: NSObject, ObservableObject {
    @Published var isAuthorized = false
    @Published var session = AVCaptureSession()
    @Published var output = AVCapturePhotoOutput()
    @Published var photoData: Data?
    @Published var previewImage: UIImage?
    @Published var errorMessage: String?
    
    // 照片库访问授权
    @Published var photoLibraryAuthorized = false
    
    override init() {
        super.init()
        checkPermissions()
    }
    
    // 检查相机和照片库权限
    func checkPermissions() {
        // 相机权限
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            self.isAuthorized = true
            self.setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] status in
                DispatchQueue.main.async {
                    self?.isAuthorized = status
                    if status {
                        self?.setupSession()
                    }
                }
            }
        default:
            self.isAuthorized = false
        }
        
        // 照片库权限
        switch PHPhotoLibrary.authorizationStatus() {
        case .authorized, .limited:
            self.photoLibraryAuthorized = true
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { [weak self] status in
                DispatchQueue.main.async {
                    self?.photoLibraryAuthorized = status == .authorized || status == .limited
                }
            }
        default:
            self.photoLibraryAuthorized = false
        }
    }
    
    // 设置相机会话
    func setupSession() {
        do {
            // 先停止会话
            if session.isRunning {
                session.stopRunning()
            }
            
            // 清除现有的输入和输出
            for input in session.inputs {
                session.removeInput(input)
            }
            for output in session.outputs {
                session.removeOutput(output)
            }
            
            self.session.beginConfiguration()
            
            // 添加输入设备
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                self.errorMessage = "无法访问相机"
                self.session.commitConfiguration()
                print("相机初始化错误: 无法访问相机设备")
                return
            }
            
            let input = try AVCaptureDeviceInput(device: device)
            if self.session.canAddInput(input) {
                self.session.addInput(input)
            } else {
                self.errorMessage = "无法添加相机输入"
                print("相机初始化错误: 无法添加相机输入")
            }
            
            // 添加输出
            if self.session.canAddOutput(self.output) {
                self.session.addOutput(self.output)
            } else {
                self.errorMessage = "无法添加相机输出"
                print("相机初始化错误: 无法添加相机输出")
            }
            
            self.session.commitConfiguration()
            print("相机会话配置完成")
        } catch {
            self.errorMessage = error.localizedDescription
            print("相机初始化错误: \(error.localizedDescription)")
        }
    }
    
    // 开始会话
    func startSession() {
        if !self.session.isRunning && self.isAuthorized {
            print("开始启动相机会话")
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                self.session.startRunning()
                DispatchQueue.main.async {
                    print("相机会话已启动: \(self.session.isRunning)")
                }
            }
        } else {
            if !self.isAuthorized {
                print("无法启动相机会话: 未获得授权")
                self.errorMessage = "相机未获授权"
            } else if self.session.isRunning {
                print("相机会话已经在运行中")
            }
        }
    }
    
    // 停止会话
    func stopSession() {
        if self.session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                self.session.stopRunning()
            }
        }
    }
    
    // 拍照
    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        self.output.capturePhoto(with: settings, delegate: self)
    }
    
    // 从照片库选择图片
    func pickPhoto(completion: @escaping (UIImage?) -> Void) {
        // 这里只是定义接口，实际操作在UIKit/SwiftUI视图中完成
    }
    
    // 压缩图像
    func compressImage(_ image: UIImage, maxDimension: CGFloat = 1080) -> Data? {
        let aspectRatio = image.size.width / image.size.height
        
        var newSize: CGSize
        if image.size.width > image.size.height {
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resizedImage?.jpegData(compressionQuality: 0.8)
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            self.errorMessage = error.localizedDescription
            return
        }
        
        guard let data = photo.fileDataRepresentation() else {
            self.errorMessage = "无法获取照片数据"
            return
        }
        
        self.photoData = data
        
        if let image = UIImage(data: data) {
            self.previewImage = image
        }
    }
} 