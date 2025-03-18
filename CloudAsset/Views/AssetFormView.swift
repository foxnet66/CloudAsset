import SwiftUI
import PhotosUI
import CoreImage
import CoreImage.CIFilterBuiltins

// 表单模式
enum AssetFormMode {
    case add
    case edit(asset: Asset)
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
    
    // 验证和错误
    @State private var showingErrors = false
    @State private var errorMessages: [String] = []
    
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
        }
        
        // 异步保存以避免UI阻塞
        DispatchQueue.global(qos: .userInitiated).async {
            var success = false
            
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
                    imageData: finalImageData
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
                        selectedImage = nil
                        imageData = nil
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("删除照片")
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            
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
        .sheet(isPresented: $showingCameraSheet) {
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
            if let image = imageToEdit {
                PhotoEditView(image: Binding(
                    get: { image },
                    set: { newImage in
                        selectedImage = newImage
                        imageData = cameraManager.compressImage(newImage)
                    }
                )) { editedImage in
                    selectedImage = editedImage
                    imageData = cameraManager.compressImage(editedImage)
                }
            }
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
                            cameraManager.photoData = nil
                            cameraManager.previewImage = nil
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
            if let previewImage = cameraManager.previewImage {
                PhotoEditView(image: Binding(
                    get: { previewImage },
                    set: { newImage in
                        // 由于cameraManager.previewImage是只读的，我们不能直接修改它
                        // 所以在这里不做任何事情
                    }
                )) { editedImage in
                    onImageCaptured(editedImage)
                    dismiss()
                }
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
    @Binding var image: UIImage
    let onSave: (UIImage) -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var rotation: Angle = .zero
    @State private var lastRotation: Angle = .zero
    @State private var selectedFilter: FilterType = .none
    @State private var brightness: Double = 0.0
    @State private var contrast: Double = 0.0
    @State private var showingOptions = false
    
    // 添加状态变量来存储滤镜预览图像缓存
    @State private var filterPreviews: [FilterType: UIImage] = [:]
    @State private var isGeneratingPreviews = false
    
    // 简单滤镜类型
    enum FilterType: String, CaseIterable, Identifiable {
        case none = "原图"
        case mono = "黑白"
        case sepia = "复古"
        case vibrant = "鲜艳"
        case cool = "冷色调"
        case warm = "暖色调"
        
        var id: String { self.rawValue }
    }
    
    // 应用滤镜到图片
    private func applyFilter(to inputImage: UIImage) -> UIImage {
        // 检查图像尺寸，如果太大则缩小处理
        let maxDimension: CGFloat = 1200.0 // 设置最大尺寸限制
        var imageToProcess = inputImage
        
        if inputImage.size.width > maxDimension || inputImage.size.height > maxDimension {
            let scale: CGFloat
            if inputImage.size.width > inputImage.size.height {
                scale = maxDimension / inputImage.size.width
            } else {
                scale = maxDimension / inputImage.size.height
            }
            
            let newSize = CGSize(width: inputImage.size.width * scale, height: inputImage.size.height * scale)
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            inputImage.draw(in: CGRect(origin: .zero, size: newSize))
            if let resizedImage = UIGraphicsGetImageFromCurrentImageContext() {
                imageToProcess = resizedImage
            }
            UIGraphicsEndImageContext()
        }
        
        let context = CIContext()
        guard let ciImage = CIImage(image: imageToProcess) else { return inputImage }
        
        // 应用滤镜
        var processedImage = ciImage
        
        // 移除do-catch块，因为Core Image操作通常不会抛出异常
        // 而是在操作失败时返回nil
        if selectedFilter != .none {
            var filter: CIFilter?
            
            switch selectedFilter {
            case .none:
                // 不应用滤镜
                break
            case .mono:
                filter = CIFilter(name: "CIPhotoEffectMono")
            case .sepia:
                filter = CIFilter(name: "CISepiaTone")
                filter?.setValue(0.8, forKey: kCIInputIntensityKey)
            case .vibrant:
                filter = CIFilter(name: "CIVibrance")
                filter?.setValue(0.5, forKey: kCIInputAmountKey)
            case .cool:
                filter = CIFilter(name: "CITemperatureAndTint")
                filter?.setValue(CIVector(x: 5000, y: 0), forKey: "inputTargetNeutral")
            case .warm:
                filter = CIFilter(name: "CITemperatureAndTint")
                filter?.setValue(CIVector(x: 7000, y: 0), forKey: "inputTargetNeutral")
            }
            
            if let filter = filter {
                filter.setValue(processedImage, forKey: kCIInputImageKey)
                if let output = filter.outputImage {
                    processedImage = output
                }
            }
        }
        
        // 应用亮度和对比度调整，无论是否使用了滤镜
        if brightness != 0 || contrast != 0 {
            // 使用两个单独的滤镜分别处理亮度和对比度，避免相互干扰
            
            // 处理亮度
            if brightness != 0 {
                let brightnessFilter = CIFilter(name: "CIColorControls")
                brightnessFilter?.setValue(processedImage, forKey: kCIInputImageKey)
                
                // 亮度参数范围：-1.0 到 1.0，默认 0
                // 将我们的范围 -15...15 映射到合适的范围
                let brightnessValue = brightness / 30.0  // 映射到 -0.5...0.5
                brightnessFilter?.setValue(brightnessValue, forKey: kCIInputBrightnessKey)
                
                if let output = brightnessFilter?.outputImage {
                    processedImage = output
                }
            }
            
            // 处理对比度
            if contrast != 0 {
                let contrastFilter = CIFilter(name: "CIColorControls")
                contrastFilter?.setValue(processedImage, forKey: kCIInputImageKey)
                
                // 对比度参数范围：0.0 到 4.0，默认 1.0
                // 映射我们的 -15...15 到合适的范围
                let contrastValue = contrast > 0 ? 
                                    1.0 + (contrast / 15.0) : // 正值映射到 1.0-2.0
                                    max(0.25, 1.0 + (contrast / 30.0)) // 负值映射到 0.5-1.0
                contrastFilter?.setValue(contrastValue, forKey: kCIInputContrastKey)
                
                if let output = contrastFilter?.outputImage {
                    processedImage = output
                }
            }
        }
        
        // 转换回UIImage
        if let cgImage = context.createCGImage(processedImage, from: processedImage.extent) {
            return UIImage(cgImage: cgImage)
        }
        
        return inputImage
    }
    
    // 保存编辑后的图片
    private func saveEditedImage() {
        // 创建一个图像上下文
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        let context = UIGraphicsGetCurrentContext()!
        
        // 设置背景为白色（如果有透明部分）
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: image.size))
        
        // 移动原点到图像中心
        context.translateBy(x: image.size.width / 2, y: image.size.height / 2)
        
        // 应用旋转
        context.rotate(by: CGFloat(rotation.radians))
        
        // 应用缩放
        context.scaleBy(x: scale, y: scale)
        
        // 绘制图像，需要将坐标移回左上角
        let rect = CGRect(
            x: -image.size.width / 2 + offset.width / scale,
            y: -image.size.height / 2 + offset.height / scale,
            width: image.size.width,
            height: image.size.height
        )
        
        // 先绘制原始图像
        image.draw(in: rect)
        
        // 获取编辑后的图像
        if let editedImage = UIGraphicsGetImageFromCurrentImageContext() {
            // 应用滤镜
            let filteredImage = applyFilter(to: editedImage)
            
            // 保存并关闭
            UIGraphicsEndImageContext()
            onSave(filteredImage)
            dismiss()
        } else {
            UIGraphicsEndImageContext()
            dismiss()
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                // 图片显示区域
                Image(uiImage: applyFilter(to: image))
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .rotationEffect(rotation)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = lastScale * value
                            }
                            .onEnded { value in
                                lastScale = scale
                            }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { value in
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                            .onEnded { value in
                                lastOffset = offset
                            }
                    )
                    .simultaneousGesture(
                        RotationGesture()
                            .onChanged { value in
                                rotation = lastRotation + value
                            }
                            .onEnded { value in
                                lastRotation = rotation
                            }
                    )
                
                // 控制UI
                VStack {
                    if showingOptions {
                        VStack(spacing: 20) {
                            // 滤镜选择器
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 15) {
                                    ForEach(FilterType.allCases) { filter in
                                        VStack {
                                            ZStack {
                                                // 显示加载指示器
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                    .scaleEffect(0.7)
                                                
                                                // 异步加载滤镜预览图
                                                Image(uiImage: getFilterPreviewImage(filter: filter))
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 60, height: 60)
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                            }
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(selectedFilter == filter ? Color.blue : Color.clear, lineWidth: 3)
                                            )
                                            
                                            Text(filter.rawValue)
                                                .font(.caption)
                                                .foregroundColor(.white)
                                        }
                                        .onTapGesture {
                                            // 确保我们以非阻塞方式应用滤镜
                                            withAnimation {
                                                selectedFilter = filter
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .padding(.vertical)
                            .background(Color.black.opacity(0.7))
                            
                            // 亮度滑块
                            VStack(alignment: .leading) {
                                HStack {
                                    Text("亮度")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("\(Int(brightness))")
                                        .foregroundColor(.white)
                                        .frame(width: 30, alignment: .trailing)
                                    Button {
                                        brightness = 0
                                    } label: {
                                        Image(systemName: "arrow.uturn.backward")
                                            .foregroundColor(.gray)
                                            .font(.caption)
                                    }
                                }
                                
                                HStack {
                                    Image(systemName: "sun.min")
                                        .foregroundColor(.white)
                                    
                                    Slider(value: $brightness, in: -15...15, step: 0.5)
                                        .accentColor(.white)
                                        .onChange(of: brightness) { _ in
                                            // 亮度调整时触发界面刷新
                                        }
                                    
                                    Image(systemName: "sun.max")
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(.horizontal)
                            
                            // 对比度滑块
                            VStack(alignment: .leading) {
                                HStack {
                                    Text("对比度")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("\(Int(contrast))")
                                        .foregroundColor(.white)
                                        .frame(width: 30, alignment: .trailing)
                                    Button {
                                        contrast = 0
                                    } label: {
                                        Image(systemName: "arrow.uturn.backward")
                                            .foregroundColor(.gray)
                                            .font(.caption)
                                    }
                                }
                                
                                HStack {
                                    Image(systemName: "circle.lefthalf.filled")
                                        .foregroundColor(.white)
                                    
                                    Slider(value: $contrast, in: -15...15, step: 0.5)
                                        .accentColor(.white)
                                        .onChange(of: contrast) { _ in
                                            // 对比度调整时触发界面刷新
                                        }
                                    
                                    Image(systemName: "circle.fill")
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(12)
                        .padding()
                    }
                    
                    Spacer()
                    
                    // 底部工具栏
                    HStack(spacing: 30) {
                        // 旋转按钮
                        Button {
                            withAnimation {
                                rotation = rotation + .degrees(90)
                                lastRotation = rotation
                            }
                        } label: {
                            Image(systemName: "rotate.right")
                                .font(.title)
                                .foregroundColor(.white)
                        }
                        
                        // 重置按钮
                        Button {
                            withAnimation {
                                scale = 1.0
                                lastScale = 1.0
                                offset = .zero
                                lastOffset = .zero
                                rotation = .zero
                                lastRotation = .zero
                                brightness = 0
                                contrast = 0
                                selectedFilter = .none
                            }
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.title)
                                .foregroundColor(.white)
                        }
                        
                        // 显示/隐藏选项按钮
                        Button {
                            withAnimation {
                                showingOptions.toggle()
                                // 如果是打开选项且滤镜预览还未生成，则立即开始生成
                                if showingOptions && filterPreviews.isEmpty {
                                    generateFilterPreviews()
                                }
                            }
                        } label: {
                            Image(systemName: showingOptions ? "slider.horizontal.below.rectangle" : "slider.horizontal.3")
                                .font(.title)
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(12)
                    .padding()
                }
            }
            .navigationTitle("编辑照片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveEditedImage()
                    }
                    .foregroundColor(.white)
                }
            }
            
            // 添加一个onAppear修饰符来异步生成滤镜预览
            .onAppear {
                // 立即生成占位预览图，使面板能够立即显示
                generatePlaceholderPreviews()
                // 异步生成实际预览图
                DispatchQueue.global(qos: .userInitiated).async {
                    generateFilterPreviews()
                }
            }
        }
    }
    
    // 生成占位预览图，供立即显示
    private func generatePlaceholderPreviews() {
        var placeholders: [FilterType: UIImage] = [:]
        let size = CGSize(width: 60, height: 60)
        
        for filter in FilterType.allCases {
            UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
            
            // 使用不同的灰度颜色作为不同滤镜的占位图
            let grayLevel: CGFloat
            switch filter {
            case .none: grayLevel = 0.5
            case .mono: grayLevel = 0.3
            case .sepia: grayLevel = 0.6
            case .vibrant: grayLevel = 0.7
            case .cool: grayLevel = 0.4
            case .warm: grayLevel = 0.65
            }
            
            UIColor(white: grayLevel, alpha: 1.0).setFill()
            UIBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
            
            // 添加滤镜名称指示
            let text = filter.rawValue
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.white
            ]
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            text.draw(in: textRect, withAttributes: attributes)
            
            // 获取占位图
            if let placeholderImage = UIGraphicsGetImageFromCurrentImageContext() {
                placeholders[filter] = placeholderImage
            }
            
            UIGraphicsEndImageContext()
        }
        
        // 立即更新预览缓存
        filterPreviews = placeholders
    }
    
    // 生成滤镜预览图
    private func generateFilterPreviews() {
        // 如果已经在生成或已经有非占位图的预览，则不重复生成
        guard !isGeneratingPreviews else { return }
        
        isGeneratingPreviews = true
        
        // 先在主线程创建一个小的缩略图
        let size = CGSize(width: 60, height: 60)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: size))
        let smallImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        guard let smallImage = smallImage else { 
            isGeneratingPreviews = false
            return 
        }
        
        // 预先创建一个上下文，避免多次创建
        let context = CIContext()
        
        // 在后台队列中生成所有滤镜预览
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            // 为每个滤镜生成预览
            var previews: [FilterType: UIImage] = [:]
            let ciImage = CIImage(image: smallImage)
            
            guard let ciImage = ciImage else {
                // 如果无法创建CIImage，则保留占位图
                DispatchQueue.main.async {
                    self.isGeneratingPreviews = false
                }
                return
            }
            
            // 每处理完一个滤镜就更新一次UI，而不是等全部完成
            for filter in FilterType.allCases {
                autoreleasepool {
                    var processedCI = ciImage
                    
                    // 应用滤镜效果
                    if filter != .none {
                        var ciFilter: CIFilter?
                        
                        switch filter {
                        case .none:
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
                            ciFilter.setValue(processedCI, forKey: kCIInputImageKey)
                            if let output = ciFilter.outputImage {
                                processedCI = output
                            }
                        }
                    }
                    
                    // 转换回UIImage
                    if let cgImage = context.createCGImage(processedCI, from: processedCI.extent) {
                        let processedImage = UIImage(cgImage: cgImage)
                        previews[filter] = processedImage
                        
                        // 每生成一个滤镜预览就立即更新UI，提高响应速度
                        let filterCopy = filter
                        let previewCopy = processedImage
                        DispatchQueue.main.async {
                            var currentPreviews = self.filterPreviews
                            currentPreviews[filterCopy] = previewCopy
                            self.filterPreviews = currentPreviews
                        }
                    }
                }
            }
            
            // 完成所有处理后标记完成
            DispatchQueue.main.async {
                self.isGeneratingPreviews = false
            }
        }
    }
    
    // 获取滤镜预览图像 - 使用缓存
    private func getFilterPreviewImage(filter: FilterType) -> UIImage {
        // 返回缓存中的预览图（可能是占位图或实际预览图）
        if let cachedPreview = filterPreviews[filter] {
            return cachedPreview
        }
        
        // 如果缓存中没有（不太可能发生），创建一个简单的占位图
        let size = CGSize(width: 60, height: 60)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        UIColor.darkGray.setFill()
        UIBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
        let placeholderImage = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()
        
        return placeholderImage
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