import SwiftUI
import PhotosUI

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
        
        switch mode {
        case .add:
            _ = assetRepository.addAsset(
                name: name,
                categoryId: categoryId,
                price: priceValue,
                purchaseDate: purchaseDate,
                warrantyEndDate: warrantyDate,
                totalUses: totalUsesValue,
                notes: notes.isEmpty ? nil : notes,
                imageData: imageData
            )
        case .edit(let asset):
            _ = assetRepository.updateAsset(
                id: asset.wrappedId,
                name: name,
                categoryId: categoryId,
                price: priceValue,
                purchaseDate: purchaseDate,
                warrantyEndDate: warrantyDate,
                totalUses: totalUsesValue,
                usedCount: usedCountValue,
                notes: notes.isEmpty ? nil : notes,
                imageData: imageData,
                currentlyInUse: currentlyInUse
            )
        }
        
        dismiss()
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
            cameraManager.startSession()
            // 添加延迟，给相机初始化一些时间
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                isInitializing = false
            }
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
    }
}

// 拍照视图
struct CameraView: View {
    @EnvironmentObject private var cameraManager: CameraManager
    @Environment(\.dismiss) private var dismiss
    let onImageCaptured: (UIImage?) -> Void
    
    // 添加状态变量来跟踪相机状态
    @State private var isInitializing = true
    
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
                            self?.parent.selectedImage = image
                            self?.parent.dismiss()
                        }
                    }
                }
            } else {
                parent.dismiss()
            }
        }
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