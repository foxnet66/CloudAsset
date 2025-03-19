import SwiftUI
import PhotosUI
import CoreImage
import CoreImage.CIFilterBuiltins

// 表单模式
enum AssetFormMode {
    case add
    case edit(asset: Asset)
}

// 简单滤镜类型
enum FilterType: String, CaseIterable, Identifiable {
    case original = "原图"
    case mono = "黑白"
    case sepia = "复古"
    case vibrant = "鲜艳"
    case cool = "冷色调"
    case warm = "暖色调"
    
    var id: String { self.rawValue }
}

// UIImage 的扩展，用于创建图像副本
extension UIImage {
    func safeCopy() -> UIImage? {
        guard let cgImage = self.cgImage else {
            return nil
        }
        return UIImage(cgImage: cgImage, scale: self.scale, orientation: self.imageOrientation)
    }
}

struct AssetFormView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var assetRepository: AssetRepository
    @EnvironmentObject private var cameraManager: CameraManager
    
    let mode: AssetFormMode
    
    // 表单字段
    @State private var name = ""
    @State private var selectedCategoryId: UUID?
    @State private var price = ""
    @State private var purchaseDate = Date()
    @State private var hasWarranty = false
    @State private var warrantyEndDate = Date().addingTimeInterval(86400 * 365) // 默认一年
    @State private var hasTotalUses = false
    @State private var totalUses = ""
    @State private var usedCount = ""
    @State private var currentlyInUse = false
    @State private var notes = ""
    
    // 图片相关
    @State private var selectedImage: UIImage?
    @State private var imageData: Data?
    @State private var showingImagePicker = false
    @State private var showingCameraSheet = false
    @State private var showingImageActionSheet = false
    @State private var showingPhotoEditor = false
    @State private var imageToEdit: UIImage?
    
    // 用于强制刷新视图
    @State private var refreshID = UUID()
    
    // 验证和错误
    @State private var showingErrors = false
    @State private var errorMessages: [String] = []
    
    // 处理编辑后的图像
    private func onImageCaptured(_ image: UIImage) {
        // 使用主线程更新UI
        DispatchQueue.main.async {
            self.selectedImage = image
            self.imageData = self.cameraManager.compressImage(image)
            // 强制UI刷新
            self.refreshID = UUID()
        }
    }
    
    // 标题
    private var formTitle: String {
        switch mode {
        case .add:
            return "添加资产"
        case .edit:
            return "编辑资产"
        }
    }
    
    // 加载现有数据
    private func loadExistingData() {
        if case .edit(let asset) = mode {
            name = asset.wrappedName
            selectedCategoryId = asset.category?.wrappedId
            price = String(format: "%.2f", asset.price)
            purchaseDate = asset.wrappedPurchaseDate
            
            if let warrantyDate = asset.wrappedWarrantyEndDate {
                hasWarranty = true
                warrantyEndDate = warrantyDate
            }
            
            if asset.totalUses > 0 {
                hasTotalUses = true
                totalUses = "\(asset.totalUses)"
                usedCount = "\(asset.usedCount)"
            }
            
            currentlyInUse = asset.currentlyInUse
            notes = asset.wrappedNotes
            
            if let data = asset.imageData, let image = UIImage(data: data) {
                selectedImage = image
                imageData = data
            }
        } else {
            // 默认选择第一个类别
            if let firstCategory = assetRepository.categories.first {
                selectedCategoryId = firstCategory.wrappedId
            }
        }
    }
    
    // 验证表单
    private func validateForm() -> Bool {
        errorMessages.removeAll()
        
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessages.append("名称不能为空")
        }
        
        if selectedCategoryId == nil {
            errorMessages.append("请选择一个类别")
        }
        
        if let priceValue = Double(price), priceValue <= 0 {
            errorMessages.append("价格必须大于0")
        } else if Double(price) == nil {
            errorMessages.append("价格格式无效")
        }
        
        if hasTotalUses {
            if let totalUsesValue = Int(totalUses), totalUsesValue <= 0 {
                errorMessages.append("总次数必须大于0")
            } else if Int(totalUses) == nil {
                errorMessages.append("总次数格式无效")
            }
            
            if let usedCountValue = Int(usedCount), let totalUsesValue = Int(totalUses),
               usedCountValue > totalUsesValue {
                errorMessages.append("已用次数不能大于总次数")
            } else if Int(usedCount) == nil {
                errorMessages.append("已用次数格式无效")
            }
        }
        
        return errorMessages.isEmpty
    }
    
    // 保存资产
    private func saveAsset() {
        if !validateForm() {
            showingErrors = true
            return
        }
        
        guard let categoryId = selectedCategoryId,
              let priceValue = Double(price) else {
            return
        }
        
        let warrantyDate = hasWarranty ? warrantyEndDate : nil
        let totalUsesValue: Int32? = hasTotalUses ? Int32(totalUses) ?? 0 : nil
        let usedCountValue: Int32 = hasTotalUses ? Int32(usedCount) ?? 0 : 0
        
        // 确保图片数据被正确压缩和保存
        var finalImageData: Data?
        
        // 检查selectedImage是否存在，如果为nil则表示照片已被删除
        if let image = selectedImage {
            // 如果图片太大，进行压缩
            let maxDimension: CGFloat = 1200.0
            var processedImage = image
            
            if image.size.width > maxDimension || image.size.height > maxDimension {
                let scale: CGFloat
                if image.size.width > image.size.height {
                    scale = maxDimension / image.size.width
                } else {
                    scale = maxDimension / image.size.height
                }
                
                let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
                image.draw(in: CGRect(origin: .zero, size: newSize))
                if let resizedImage = UIGraphicsGetImageFromCurrentImageContext() {
                    processedImage = resizedImage
                }
                UIGraphicsEndImageContext()
            }
            
            // 压缩图片数据
            finalImageData = processedImage.jpegData(compressionQuality: 0.8)
        } else {
            // 如果selectedImage为nil，则确保finalImageData也为nil (照片已被删除)
            finalImageData = nil
            print("照片已被删除，设置finalImageData为nil")
        }
        
        // 异步保存以避免UI阻塞
        DispatchQueue.global(qos: .userInitiated).async {
            var success = false
            
            // 添加调试日志
            print("保存前的状态: selectedImage=\(self.selectedImage == nil ? "nil" : "有图片"), finalImageData=\(finalImageData == nil ? "nil" : "有数据")")
            
            switch self.mode {
            case .add:
                if self.assetRepository.addAsset(
                    name: self.name,
                    categoryId: categoryId,
                    price: priceValue,
                    purchaseDate: self.purchaseDate,
                    warrantyEndDate: warrantyDate,
                    totalUses: totalUsesValue,
                    notes: self.notes.isEmpty ? nil : self.notes,
                    imageData: finalImageData,
                    currentlyInUse: self.currentlyInUse
                ) != nil {
                    success = true
                }
            case .edit(let asset):
                success = self.assetRepository.updateAsset(
                    id: asset.wrappedId,
                    name: self.name,
                    categoryId: categoryId,
                    price: priceValue,
                    purchaseDate: self.purchaseDate,
                    warrantyEndDate: warrantyDate,
                    totalUses: totalUsesValue,
                    usedCount: usedCountValue,
                    notes: self.notes.isEmpty ? nil : self.notes,
                    imageData: finalImageData,
                    currentlyInUse: self.currentlyInUse
                )
            }
            
            // 在主线程上执行UI操作
            DispatchQueue.main.async {
                // 保存后立即刷新数据
                if success {
                    // 先发送通知，通知列表页准备刷新
                    NotificationCenter.default.post(name: NSNotification.Name("AssetDataChanging"), object: nil)
                    
                    // 强制同步保存和刷新（这很重要）
                    try? self.viewContext.save()
                    self.assetRepository.refreshAssets()
                    
                    // 短暂延迟后再次通知列表页刷新数据已完成
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        NotificationCenter.default.post(name: NSNotification.Name("AssetDataChanged"), object: nil)
                    }
                }
                
                self.dismiss()
            }
        }
    }
    
    var body: some View {
        Form {
            // 基本信息部分
            Section(header: Text("基本信息")) {
                TextField("资产名称", text: $name)
                
                Picker("类别", selection: $selectedCategoryId) {
                    ForEach(assetRepository.categories) { category in
                        HStack {
                            Image(systemName: category.wrappedIcon)
                            Text(category.wrappedName)
                        }
                        .tag(Optional(category.wrappedId))
                    }
                }
                
                HStack {
                    Text("价格")
                    TextField("0.00", text: $price)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                
                DatePicker("购买日期", selection: $purchaseDate, displayedComponents: .date)
            }
            
            // 保修部分
            Section(header: Text("保修期")) {
                Toggle("有保修期", isOn: $hasWarranty)
                
                if hasWarranty {
                    DatePicker("保修截止日期", selection: $warrantyEndDate, displayedComponents: .date)
                }
            }
            
            // 使用次数部分
            Section(header: Text("使用次数")) {
                Toggle("按次数记录", isOn: $hasTotalUses)
                
                if hasTotalUses {
                    HStack {
                        Text("总次数")
                        TextField("0", text: $totalUses)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    if case .edit = mode {
                        HStack {
                            Text("已用次数")
                            TextField("0", text: $usedCount)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
            }
            
            // 使用状态部分
            Section(header: Text("使用状态")) {
                Toggle("正在使用", isOn: $currentlyInUse)
            }
            
            // 图片部分
            Section(header: Text("照片")) {
                HStack {
                    Spacer()
                    
                    Group {
                        if let image = selectedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 200)
                                .cornerRadius(8)
                                .onTapGesture {
                                    imageToEdit = image
                                    showingPhotoEditor = true
                                }
                        } else {
                            Image(systemName: "photo")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                                .frame(height: 200)
                        }
                    }
                    .id(refreshID) // 使用ID强制在refreshID变化时重新渲染
                    
                    Spacer()
                }
                
                Button {
                    showingImageActionSheet = true
                } label: {
                    HStack {
                        Image(systemName: "camera")
                        Text(selectedImage == nil ? "添加照片" : "更换照片")
                    }
                    .frame(maxWidth: .infinity)
                }
                
                if selectedImage != nil {
                    Button {
                        imageToEdit = selectedImage
                        showingPhotoEditor = true
                    } label: {
                        HStack {
                            Image(systemName: "slider.horizontal.3")
                            Text("编辑照片")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    Button(role: .destructive) {
                        // 强制清空照片数据 - 确保所有相关变量都被设置为nil
                        DispatchQueue.main.async {
                            withAnimation {
                                // 显式赋值为nil，确保状态被更新
                                self.selectedImage = nil
                                self.imageData = nil
                                self.imageToEdit = nil
                                
                                // 重要：确保CoreData模型中的imageData会被正确清除
                                if case .edit(let asset) = self.mode {
                                    print("正在编辑资产，标记照片已删除")
                                }
                                
                                // 刷新视图ID以强制重新渲染
                                self.refreshID = UUID()
                                
                                // 添加一个debugPrint用于检查状态清除是否正确执行
                                print("照片已删除，当前状态: selectedImage=\(self.selectedImage == nil ? "nil" : "not nil"), imageData=\(self.imageData == nil ? "nil" : "not nil")")
                                
                                // 延迟再次刷新，确保UI更新
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    self.refreshID = UUID()
                                    print("延迟刷新执行")
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("删除照片")
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .id(refreshID) // 整个Section都使用同一个ID以确保完全刷新
            
            // 备注部分
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
                    saveAsset()
                }
            }
        }
        .onAppear {
            loadExistingData()
        }
        .sheet(isPresented: $showingImagePicker) {
            PhotosPicker(selectedImage: $selectedImage)
        }
        .sheet(isPresented: $showingCameraSheet, onDismiss: {
            // 确保在关闭相机表单时重置状态
            cameraManager.resetCamera()
        }) {
            CameraView { image in
                if let image = image {
                    selectedImage = image
                    imageData = cameraManager.compressImage(image)
                }
            }
        }
        .confirmationDialog("选择照片来源", isPresented: $showingImageActionSheet) {
            Button("拍照") {
                showingCameraSheet = true
                // 确保在打开相机前重置状态
                cameraManager.resetCamera()
            }
            
            Button("从相册选择") {
                showingImagePicker = true
            }
            
            Button("取消", role: .cancel) { }
        }
        .alert("表单错误", isPresented: $showingErrors) {
            Button("确定") { }
        } message: {
            Text(errorMessages.joined(separator: "\n"))
        }
        .sheet(isPresented: $showingPhotoEditor) {
            if let editImage = imageToEdit, 
               let imageCopy = editImage.safeCopy() as? UIImage {
                PhotoEditView(image: .constant(imageCopy), onComplete: { editedImage in
                    // 编辑完成后在主线程安全地更新图像
                    DispatchQueue.main.async {
                        self.selectedImage = editedImage
                        self.imageData = self.cameraManager.compressImage(editedImage)
                        self.refreshID = UUID() // 强制刷新UI
                    }
                })
            } else {
                // 如果无法创建图像副本，显示一个空视图
                EmptyView()
            }
        }
        .onDisappear {
            cameraManager.stopSession()
        }
    }
}

// 拍照视图
struct CameraView: View {
    @EnvironmentObject private var cameraManager: CameraManager
    @Environment(\.dismiss) private var dismiss
    let onImageCaptured: (UIImage?) -> Void
    
    // 添加状态变量来跟踪相机状态
    @State private var isInitializing = true
    @State private var showingPhotoEditor = false
    
    var body: some View {
        ZStack {
            // 相机预览
            CameraPreviewView(session: cameraManager.session)
                .edgesIgnoringSafeArea(.all)
            
            // 相机控制UI
            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding()
                    }
                    
                    Spacer()
                    
                    // 添加相机状态指示
                    if let error = cameraManager.errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .padding()
                    }
                }
                
                if isInitializing {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(2)
                    Text("初始化相机...")
                        .foregroundColor(.white)
                        .padding()
                    Spacer()
                }
                
                Spacer()
                
                if !isInitializing {
                    Button {
                        cameraManager.capturePhoto()
                    } label: {
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                            .frame(width: 70, height: 70)
                            .overlay(
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 60, height: 60)
                            )
                    }
                    .padding(.bottom, 40)
                }
            }
            
            if let previewImage = cameraManager.previewImage {
                Color.black.edgesIgnoringSafeArea(.all)
                
                VStack {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    HStack {
                        Button {
                            // 完全重置相机状态
                            cameraManager.photoData = nil
                            cameraManager.previewImage = nil
                            // 如果相机会话没有运行，重新启动它
                            if !cameraManager.session.isRunning {
                                cameraManager.startSession()
                            }
                        } label: {
                            Text("重拍")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.red)
                                .cornerRadius(8)
                        }
                        
                        Spacer()
                        
                        Button {
                            showingPhotoEditor = true
                        } label: {
                            Text("编辑")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                        
                        Spacer()
                        
                        Button {
                            onImageCaptured(previewImage)
                            dismiss()
                        } label: {
                            Text("使用")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.green)
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            // 重置相机状态，清除之前的照片数据
            cameraManager.resetCamera()
            // 启动相机会话
            cameraManager.startSession()
            // 添加延迟，给相机初始化一些时间
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                isInitializing = false
            }
        }
        .onDisappear {
            cameraManager.stopSession()
        }
        .sheet(isPresented: $showingPhotoEditor) {
            if let previewImage = cameraManager.previewImage, 
               let imageCopy = previewImage.safeCopy() as? UIImage {
                PhotoEditView(image: .constant(imageCopy), onComplete: { editedImage in
                    // 安全地在主线程处理回调
                    DispatchQueue.main.async {
                        // 调用回调函数传递编辑后的图像
                        onImageCaptured(editedImage)
                        // 短暂延迟后关闭相机视图，返回到表单
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            dismiss()
                        }
                    }
                })
            } else {
                // 如果无法创建图像副本，显示一个空视图
                EmptyView()
            }
        }
    }
}

// 相机预览视图
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds // 确保初始尺寸已设置
        view.layer.addSublayer(previewLayer)
        
        // 添加观察者以监听视图尺寸变化
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            // 确保在主线程更新UI
            if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
                previewLayer.frame = uiView.bounds
            }
        }
    }
}

// 相册选择器
struct PhotosPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
        // 不需要更新
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotosPicker
        
        init(_ parent: PhotosPicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            if let result = results.first {
                result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                    if let image = object as? UIImage {
                        DispatchQueue.main.async {
                            // 压缩图片
                            if let imageData = image.jpegData(compressionQuality: 0.8) {
                                // 如果图片太大，进行压缩
                                let maxDimension: CGFloat = 1200.0
                                var processedImage = image
                                
                                if image.size.width > maxDimension || image.size.height > maxDimension {
                                    let scale: CGFloat
                                    if image.size.width > image.size.height {
                                        scale = maxDimension / image.size.width
                                    } else {
                                        scale = maxDimension / image.size.height
                                    }
                                    
                                    let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                                    UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
                                    image.draw(in: CGRect(origin: .zero, size: newSize))
                                    if let resizedImage = UIGraphicsGetImageFromCurrentImageContext() {
                                        processedImage = resizedImage
                                    }
                                    UIGraphicsEndImageContext()
                                }
                                
                                self?.parent.selectedImage = processedImage
                                self?.parent.dismiss()
                            }
                        }
                    }
                }
            } else {
                parent.dismiss()
            }
        }
    }
}

// 照片编辑视图
struct PhotoEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentFilter: FilterType = .original
    @State private var brightness: Double = 0.0
    @State private var contrast: Double = 0.0
    @State private var showingFilterSheet = false
    @State private var showingAdjustmentSheet = false
    @State private var isProcessing = false
    @State private var processedImage: UIImage?
    
    // 使用Binding而非直接存储图像
    var image: Binding<UIImage>
    var onComplete: (UIImage) -> Void
    
    // 存储原始图像的副本以便重置
    @State private var originalImage: UIImage
    
    init(image: Binding<UIImage>, onComplete: @escaping (UIImage) -> Void) {
        self.image = image
        self.onComplete = onComplete
        // 创建原始图像的副本
        self._originalImage = State(initialValue: image.wrappedValue.safeCopy() as? UIImage ?? image.wrappedValue)
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if isProcessing {
                    ProgressView("处理中...")
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    if let processedImage = processedImage {
                        Image(uiImage: processedImage)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Image(uiImage: image.wrappedValue)
                            .resizable()
                            .scaledToFit()
                    }
                }
                
                HStack {
                    Button(action: {
                        showingFilterSheet = true
                    }) {
                        Label("滤镜", systemImage: "camera.filters")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        showingAdjustmentSheet = true
                    }) {
                        Label("调整", systemImage: "slider.horizontal.3")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
                
                HStack {
                    Button(action: {
                        // 重置为原始图像
                        brightness = 0.0
                        contrast = 0.0
                        currentFilter = .original
                        processedImage = nil
                    }) {
                        Text("重置")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        saveEditedImage()
                    }) {
                        Text("完成")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            .navigationTitle("编辑照片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingFilterSheet) {
                FilterSelectionView(
                    selectedFilter: $currentFilter,
                    originalImage: originalImage,
                    brightness: brightness,
                    contrast: contrast,
                    onFilterSelected: { filter in
                        currentFilter = filter
                        applyCurrentEffects()
                    }
                )
            }
            .sheet(isPresented: $showingAdjustmentSheet) {
                BrightnessContrastView(
                    brightness: $brightness,
                    contrast: $contrast,
                    originalImage: originalImage,
                    currentFilter: currentFilter,
                    onValueChanged: { newBrightness, newContrast in
                        brightness = newBrightness
                        contrast = newContrast
                        applyCurrentEffects()
                    }
                )
            }
            .onAppear {
                // 初始显示时应用当前的效果
                applyCurrentEffects()
            }
        }
    }
    
    private func applyCurrentEffects() {
        isProcessing = true
        
        // 在后台线程处理图像
        DispatchQueue.global(qos: .userInitiated).async {
            let result = applyFilter(to: originalImage, filter: currentFilter, brightness: brightness, contrast: contrast)
            
            DispatchQueue.main.async {
                processedImage = result
                isProcessing = false
            }
        }
    }
    
    private func saveEditedImage() {
        // 显示处理中状态
        isProcessing = true
        
        // 在后台线程处理最终图像
        DispatchQueue.global(qos: .userInteractive).async {
            // 使用最终处理的图像或原始图像
            let finalImage = self.processedImage ?? self.image.wrappedValue
            
            // 使用autoreleasepool确保内存管理
            autoreleasepool {
                // 创建一个新的图像副本，确保内存安全
                if let finalCopy = finalImage.safeCopy() {
                    // 在主线程完成回调和UI更新
                    DispatchQueue.main.async {
                        // 先回调以更新图像
                        self.onComplete(finalCopy)
                        
                        // 将处理状态设为false
                        self.isProcessing = false
                        
                        // 短暂延迟后关闭视图，避免闪烁
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.dismiss()
                        }
                    }
                } else {
                    // 如果复制失败，使用原始图像
                    DispatchQueue.main.async {
                        // 先回调以更新图像
                        self.onComplete(finalImage)
                        
                        // 将处理状态设为false
                        self.isProcessing = false
                        
                        // 短暂延迟后关闭视图，避免闪烁
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.dismiss()
                        }
                    }
                }
            }
        }
    }
}

// 滤镜选择视图
struct FilterSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedFilter: FilterType
    var originalImage: UIImage
    var brightness: Double
    var contrast: Double
    var onFilterSelected: (FilterType) -> Void
    
    @State private var previewImages: [FilterType: UIImage] = [:]
    @State private var isGeneratingPreviews = true
    
    var body: some View {
        NavigationStack {
            VStack {
                if isGeneratingPreviews {
                    ProgressView("生成预览中...")
                        .padding()
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 15) {
                            ForEach(FilterType.allCases) { filter in
                                VStack {
                                    // 预览图片
                                    if let preview = previewImages[filter] {
                                        Image(uiImage: preview)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(height: 80)
                                            .cornerRadius(8)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(selectedFilter == filter ? Color.blue : Color.clear, lineWidth: 3)
                                            )
                                    } else {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(height: 80)
                                            .cornerRadius(8)
                                    }
                                    
                                    Text(filter.rawValue)
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                }
                                .onTapGesture {
                                    selectedFilter = filter
                                    onFilterSelected(filter)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("选择滤镜")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("返回") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                generateFilterPreviews()
            }
        }
    }
    
    private func generateFilterPreviews() {
        isGeneratingPreviews = true
        
        // 创建缩略图尺寸的图像用于预览
        let thumbnailSize: CGFloat = 120
        var previewImage = originalImage
        
        // 如果原图太大，先缩小以加快预览生成
        if originalImage.size.width > thumbnailSize || originalImage.size.height > thumbnailSize {
            let scale = min(thumbnailSize / originalImage.size.width, thumbnailSize / originalImage.size.height)
            let newSize = CGSize(width: originalImage.size.width * scale, height: originalImage.size.height * scale)
            
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            originalImage.draw(in: CGRect(origin: .zero, size: newSize))
            if let resized = UIGraphicsGetImageFromCurrentImageContext() {
                previewImage = resized
            }
            UIGraphicsEndImageContext()
        }
        
        // 在后台线程生成所有滤镜的预览
        DispatchQueue.global(qos: .userInitiated).async {
            var previews: [FilterType: UIImage] = [:]
            
            for filter in FilterType.allCases {
                let filtered = applyFilter(to: previewImage, filter: filter, brightness: brightness, contrast: contrast)
                previews[filter] = filtered
            }
            
            DispatchQueue.main.async {
                self.previewImages = previews
                self.isGeneratingPreviews = false
            }
        }
    }
}

// 亮度和对比度调整视图
struct BrightnessContrastView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var brightness: Double
    @Binding var contrast: Double
    var originalImage: UIImage
    var currentFilter: FilterType
    var onValueChanged: (Double, Double) -> Void
    
    @State private var previewImage: UIImage?
    @State private var isProcessing = false
    @State private var currentBrightness: Double
    @State private var currentContrast: Double
    @State private var isSliding = false
    
    // 防抖计时器
    @State private var debounceTimer: Timer?
    
    init(brightness: Binding<Double>, contrast: Binding<Double>, originalImage: UIImage, currentFilter: FilterType, onValueChanged: @escaping (Double, Double) -> Void) {
        self._brightness = brightness
        self._contrast = contrast
        self.originalImage = originalImage
        self.currentFilter = currentFilter
        self.onValueChanged = onValueChanged
        
        // 初始化当前值
        self._currentBrightness = State(initialValue: brightness.wrappedValue)
        self._currentContrast = State(initialValue: contrast.wrappedValue)
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                // 预览图片 - 使用ZStack避免在切换时出现闪烁
                ZStack {
                    if let preview = previewImage {
                        Image(uiImage: preview)
                            .resizable()
                            .scaledToFit()
                            .transition(.opacity)
                    } else {
                        Image(uiImage: originalImage)
                            .resizable()
                            .scaledToFit()
                            .transition(.opacity)
                    }
                    
                    if isProcessing && !isSliding {
                        ProgressView("更新预览...")
                            .padding()
                            .background(Color.black.opacity(0.6))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: previewImage != nil)
                .padding()
                
                // 亮度滑块
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("亮度")
                            .font(.headline)
                        Spacer()
                        Text("\(Int(currentBrightness))")
                            .foregroundColor(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                    
                    HStack {
                        Image(systemName: "sun.min")
                            .foregroundColor(.secondary)
                        
                        Slider(value: $currentBrightness, in: -15...15, step: 0.5) { editing in
                            isSliding = editing
                            if !editing {
                                // 滑动结束时更新
                                updatePreviewWithDelay()
                            }
                        }
                        
                        Image(systemName: "sun.max")
                            .foregroundColor(.secondary)
                    }
                    
                    Button("重置亮度") {
                        currentBrightness = 0
                        updatePreviewWithDelay()
                    }
                    .font(.footnote)
                    .padding(.vertical, 5)
                }
                .padding(.horizontal)
                
                // 对比度滑块
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("对比度")
                            .font(.headline)
                        Spacer()
                        Text("\(Int(currentContrast))")
                            .foregroundColor(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                    
                    HStack {
                        Image(systemName: "circle.lefthalf.filled")
                            .foregroundColor(.secondary)
                        
                        Slider(value: $currentContrast, in: -15...15, step: 0.5) { editing in
                            isSliding = editing
                            if !editing {
                                // 滑动结束时更新
                                updatePreviewWithDelay()
                            }
                        }
                        
                        Image(systemName: "circle.fill")
                            .foregroundColor(.secondary)
                    }
                    
                    Button("重置对比度") {
                        currentContrast = 0
                        updatePreviewWithDelay()
                    }
                    .font(.footnote)
                    .padding(.vertical, 5)
                }
                .padding(.horizontal)
                
                Spacer()
                
                Button("应用调整") {
                    brightness = currentBrightness
                    contrast = currentContrast
                    onValueChanged(currentBrightness, currentContrast)
                    dismiss()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(.horizontal)
            }
            .padding(.top)
            .navigationTitle("亮度和对比度")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("返回") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // 第一次显示时加载预览
                updatePreview()
            }
            .onDisappear {
                // 清理计时器
                debounceTimer?.invalidate()
                debounceTimer = nil
            }
        }
    }
    
    // 延迟更新预览以避免频繁处理
    private func updatePreviewWithDelay() {
        debounceTimer?.invalidate()
        
        // 当滑块正在滑动时，不显示加载指示器，避免闪烁
        if !isSliding {
            isProcessing = true
        }
        
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { _ in
            updatePreview()
        }
    }
    
    private func updatePreview() {
        if !isSliding {
            isProcessing = true
        }
        
        // 创建略小的预览图像以提高性能
        let previewSize: CGFloat = 600
        var imageToProcess = originalImage
        
        // 如果原图太大，先缩小
        if originalImage.size.width > previewSize || originalImage.size.height > previewSize {
            let scale = min(previewSize / originalImage.size.width, previewSize / originalImage.size.height)
            let newSize = CGSize(width: originalImage.size.width * scale, height: originalImage.size.height * scale)
            
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            originalImage.draw(in: CGRect(origin: .zero, size: newSize))
            if let resized = UIGraphicsGetImageFromCurrentImageContext() {
                imageToProcess = resized
            }
            UIGraphicsEndImageContext()
        }
        
        // 使用后台高优先级队列处理图像
        DispatchQueue.global(qos: .userInteractive).async {
            let result = applyFilter(to: imageToProcess, filter: currentFilter, brightness: currentBrightness, contrast: currentContrast)
            
            // 回到主线程更新UI
            DispatchQueue.main.async {
                withAnimation {
                    self.previewImage = result
                    self.isProcessing = false
                }
            }
        }
    }
}

// 应用滤镜到图片
func applyFilter(to inputImage: UIImage, filter: FilterType, brightness: Double, contrast: Double) -> UIImage {
    // 为安全起见，如果发生任何错误，返回原始图像
    guard let cgImage = inputImage.cgImage else { return inputImage }
    
    // 检查图像尺寸，如果太大则缩小处理
    var imageToProcess = inputImage
    let maxDimension: CGFloat = 1200.0 // 设置最大尺寸限制
    
    if inputImage.size.width > maxDimension || inputImage.size.height > maxDimension {
        let scale: CGFloat = min(maxDimension / inputImage.size.width, maxDimension / inputImage.size.height)
        let newSize = CGSize(width: inputImage.size.width * scale, height: inputImage.size.height * scale)
        
        // 创建缩小后的图像
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        inputImage.draw(in: CGRect(origin: .zero, size: newSize))
        if let resizedImage = UIGraphicsGetImageFromCurrentImageContext() {
            imageToProcess = resizedImage
        }
    }
    
    // 创建新的上下文，避免使用软件渲染器
    let context = CIContext(options: [.useSoftwareRenderer: false])
    
    // 安全地创建 CIImage
    guard let ciImage = CIImage(image: imageToProcess) else { return imageToProcess }
    
    // 创建一个未修改的 CIImage 副本，以防滤镜应用失败
    var processedImage = ciImage
    var filterApplied = false
    
    // 应用滤镜
    if filter != .original {
        var ciFilter: CIFilter?
        
        switch filter {
        case .original:
            // 不应用滤镜
            break
        case .mono:
            ciFilter = CIFilter(name: "CIPhotoEffectMono")
        case .sepia:
            ciFilter = CIFilter(name: "CISepiaTone")
            ciFilter?.setValue(0.8, forKey: kCIInputIntensityKey)
        case .vibrant:
            ciFilter = CIFilter(name: "CIVibrance")
            ciFilter?.setValue(0.5, forKey: kCIInputAmountKey)
        case .cool:
            ciFilter = CIFilter(name: "CITemperatureAndTint")
            ciFilter?.setValue(CIVector(x: 5000, y: 0), forKey: "inputTargetNeutral")
        case .warm:
            ciFilter = CIFilter(name: "CITemperatureAndTint")
            ciFilter?.setValue(CIVector(x: 7000, y: 0), forKey: "inputTargetNeutral")
        }
        
        if let ciFilter = ciFilter {
            ciFilter.setValue(processedImage, forKey: kCIInputImageKey)
            if let output = ciFilter.outputImage {
                processedImage = output
                filterApplied = true
            }
        }
    }
    
    // 应用亮度和对比度调整，无论是否使用了滤镜
    if brightness != 0 || contrast != 0 {
        // 使用两个单独的滤镜分别处理亮度和对比度，避免相互干扰
        var adjustmentApplied = false
        
        // 处理亮度
        if brightness != 0 {
            let brightnessFilter = CIFilter(name: "CIColorControls")
            brightnessFilter?.setValue(processedImage, forKey: kCIInputImageKey)
            
            // 亮度参数范围：-1.0 到 1.0，默认 0
            // 将我们的范围 -15...15 映射到合适的范围
            let brightnessValue = brightness * 0.02  // 使用较小的缩放因子
            brightnessFilter?.setValue(brightnessValue, forKey: kCIInputBrightnessKey)
            
            if let output = brightnessFilter?.outputImage {
                processedImage = output
                adjustmentApplied = true
            }
        }
        
        // 处理对比度
        if contrast != 0 {
            let contrastFilter = CIFilter(name: "CIColorControls")
            contrastFilter?.setValue(processedImage, forKey: kCIInputImageKey)
            
            // 对比度参数范围：0.0 到 4.0，默认 1.0
            // 映射我们的 -15...15 到合适的范围
            let contrastValue = contrast > 0 ? 
                                1.0 + (contrast * 0.02) : // 正值映射到较小范围
                                max(0.5, 1.0 + (contrast * 0.02)) // 负值映射到较小范围
            contrastFilter?.setValue(contrastValue, forKey: kCIInputContrastKey)
            
            if let output = contrastFilter?.outputImage {
                processedImage = output
                adjustmentApplied = true
            }
        }
        
        // 如果既没有应用滤镜，又没有应用亮度/对比度调整，返回原始图像
        if !filterApplied && !adjustmentApplied {
            return imageToProcess
        }
    } else if !filterApplied {
        // 如果没有应用任何修改，直接返回原图
        return imageToProcess
    }
    
    // 使用捕获的方式和自动释放池转换回UIImage，避免崩溃
    do {
        // 确保 processedImage 有有效的 extent
        if processedImage.extent.isInfinite || processedImage.extent.isEmpty {
            return imageToProcess
        }
        
        // 在特定的自动释放池中创建 CGImage
        var resultImage: UIImage = imageToProcess
        autoreleasepool {
            if let cgImage = context.createCGImage(processedImage, from: processedImage.extent) {
                // 创建一个新的 UIImage 并复制它，避免引用和保持 CGImage
                let tempImage = UIImage(cgImage: cgImage)
                if let copiedImage = tempImage.safeCopy() as? UIImage {
                    resultImage = copiedImage
                }
            }
        }
        return resultImage
    } catch {
        print("应用滤镜时出错: \(error)")
        return imageToProcess
    }
}

#Preview {
    NavigationStack {
        AssetFormView(mode: .add)
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(AssetRepository(
                context: PersistenceController.preview.container.viewContext,
                purchaseManager: PurchaseManager.preview
            ))
            .environmentObject(CameraManager())
    }
} 
