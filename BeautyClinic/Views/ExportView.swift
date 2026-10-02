import SwiftUI

// MARK: - Download Manager (handles large files with progress)
@MainActor
class DownloadManager: NSObject, ObservableObject {
    @Published var downloadProgress: Double = 0
    @Published var downloadStatus: String = ""
    @Published var localFileURL: URL?
    @Published var isDownloading = false
    @Published var downloadError: String?
    
    private var downloadTask: URLSessionDownloadTask?
    private var resumeData: Data?
    
    func downloadFile(from url: URL, token: String, fileName: String) {
        isDownloading = true
        downloadProgress = 0
        downloadStatus = "准备下载..."
        downloadError = nil
        localFileURL = nil
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 300 // 5 minutes timeout for large files
        
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        downloadTask = session.downloadTask(with: request)
        downloadTask?.resume()
    }
    
    func cancel() {
        downloadTask?.cancel(byProducingResumeData: { data in
            self.resumeData = data
        })
        isDownloading = false
    }
}

extension DownloadManager: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        let writtenMB = Double(totalBytesWritten) / 1024 / 1024
        let totalMB = Double(totalBytesExpectedToWrite) / 1024 / 1024
        
        Task { @MainActor in
            self.downloadProgress = progress
            self.downloadStatus = String(format: "已下载 %.1f / %.1f MB (%.0f%%)", writtenMB, totalMB, progress * 100)
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // CRITICAL: Must move file synchronously before this method returns
        // The temp file at 'location' is deleted immediately after this callback
        let fileManager = FileManager.default
        let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let suggestedName = downloadTask.response?.suggestedFilename ?? "BeautyManager导出.zip"
        let localURL = documentsDir.appendingPathComponent(suggestedName)
        
        do {
            // Ensure Documents directory exists
            if !fileManager.fileExists(atPath: documentsDir.path) {
                try fileManager.createDirectory(at: documentsDir, withIntermediateDirectories: true, attributes: nil)
            }
            
            // Remove existing file
            if fileManager.fileExists(atPath: localURL.path) {
                try fileManager.removeItem(at: localURL)
            }
            
            // Move synchronously (must complete before callback returns)
            try fileManager.moveItem(at: location, to: localURL)
            
            // Update UI on main thread
            Task { @MainActor in
                self.localFileURL = localURL
                self.isDownloading = false
                self.downloadStatus = "下载完成"
            }
        } catch {
            Task { @MainActor in
                self.downloadError = "保存文件失败: \(error.localizedDescription)"
                self.isDownloading = false
            }
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        Task { @MainActor in
            if let error = error {
                self.downloadError = "下载失败: \(error.localizedDescription)"
                self.isDownloading = false
            }
        }
    }
}

struct ExportView: View {
    @EnvironmentObject var userState: UserState
    @StateObject private var downloadManager = DownloadManager()
    
    @State private var exportType: ExportType = .all
    @State private var selectedStoreId: UUID?
    @State private var startDate = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var selectedCustomerIds: Set<UUID> = []
    
    @State private var isExporting = false
    @State private var exportProgress: Double = 0
    @State private var exportStatus: String = ""
    @State private var showResult = false
    @State private var downloadURL: URL?
    @State private var zipSize: String = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    @State private var stores: [Store] = []
    @State private var customers: [Customer] = []
    @State private var showCustomerPicker = false
    @State private var taskId: String?
    @State private var pollTimer: Timer?
    @State private var pollFailureCount = 0
    
    enum ExportType: String, CaseIterable {
        case all = "all"
        case store = "store"
        case dateRange = "dateRange"
        case customers = "customers"
        
        var displayName: String {
            switch self {
            case .all: return "全部"
            case .store: return "按门店"
            case .dateRange: return "按时间"
            case .customers: return "按客户"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("导出范围") {
                    Picker("类型", selection: $exportType) {
                        ForEach(ExportType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(isExporting || downloadManager.isDownloading)
                    
                    switch exportType {
                    case .all:
                        Text("将导出所有客户数据及交付图片")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    
                    case .store:
                        if stores.isEmpty {
                            ProgressView("加载门店...")
                                .font(.caption)
                        } else {
                            Picker("选择门店", selection: $selectedStoreId) {
                                Text("请选择").tag(nil as UUID?)
                                ForEach(stores) { store in
                                    Text(store.name).tag(store.id as UUID?)
                                }
                            }
                            .disabled(isExporting || downloadManager.isDownloading)
                        }
                    
                    case .dateRange:
                        DatePicker("开始", selection: $startDate, displayedComponents: .date)
                            .disabled(isExporting || downloadManager.isDownloading)
                        DatePicker("结束", selection: $endDate, displayedComponents: .date)
                            .disabled(isExporting || downloadManager.isDownloading)
                    
                    case .customers:
                        Button("选择客户 (\(selectedCustomerIds.count) 位)") {
                            showCustomerPicker = true
                        }
                        .disabled(isExporting || downloadManager.isDownloading)
                    }
                }
                
                if isExporting {
                    Section("服务器处理进度") {
                        VStack(alignment: .leading, spacing: 12) {
                            ProgressView(value: exportProgress, total: 1.0)
                                .progressViewStyle(.linear)
                            
                            Text(exportStatus)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                if downloadManager.isDownloading {
                    Section("下载进度") {
                        VStack(alignment: .leading, spacing: 12) {
                            ProgressView(value: downloadManager.downloadProgress, total: 1.0)
                                .progressViewStyle(.linear)
                            
                            Text(downloadManager.downloadStatus)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button("取消下载") {
                                downloadManager.cancel()
                            }
                            .foregroundColor(.red)
                            .font(.caption)
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                if showResult {
                    Section("导出完成") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.title3)
                                Text("导出成功")
                                    .font(.headline)
                            }
                            
                            HStack {
                                Text("文件大小:")
                                    .foregroundColor(.secondary)
                                Text(zipSize)
                                    .fontWeight(.semibold)
                            }
                            .font(.subheadline)
                            
                            if let localURL = downloadManager.localFileURL {
                                ShareLink(item: localURL) {
                                    Label("分享导出文件", systemImage: "square.and.arrow.up")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                
                                Text("文件位置: \(localURL.lastPathComponent)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            } else if let remoteURL = downloadURL {
                                Button(action: { startDownload(from: remoteURL) }) {
                                    Label("下载到本地", systemImage: "arrow.down.circle")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                if let error = downloadManager.downloadError {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("数据导出")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: startExport) {
                        if isExporting || downloadManager.isDownloading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("开始导出")
                        }
                    }
                    .disabled(isExporting || downloadManager.isDownloading || !canExport)
                }
            }
            .alert("导出失败", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showCustomerPicker) {
                CustomerMultiSelectView(
                    customers: customers,
                    selectedIds: $selectedCustomerIds
                )
            }
            .task {
                await loadStoresAndCustomers()
            }
            .onDisappear {
                pollTimer?.invalidate()
            }
        }
    }
    
    private var canExport: Bool {
        switch exportType {
        case .all:
            return true
        case .store:
            return selectedStoreId != nil
        case .dateRange:
            return startDate <= endDate
        case .customers:
            return !selectedCustomerIds.isEmpty
        }
    }
    
    private func loadStoresAndCustomers() async {
        do {
            stores = try await StoreService.shared.listStores()
            customers = try await CustomerService.shared.listCustomers()
        } catch {
            print("加载数据失败: \(error)")
        }
    }
    
    private func startExport() {
        guard APIConfig.authToken != nil else {
            errorMessage = "未登录"
            showError = true
            return
        }
        
        isExporting = true
        exportProgress = 0
        exportStatus = "准备导出..."
        showResult = false
        downloadManager.localFileURL = nil
        downloadManager.downloadError = nil
        
        Task {
            do {
                let params = ExportRequest(
                    type: exportType.rawValue,
                    storeId: selectedStoreId?.uuidString,
                    startDate: exportType == .dateRange ? ISO8601DateFormatter().string(from: startDate) : nil,
                    endDate: exportType == .dateRange ? ISO8601DateFormatter().string(from: endDate) : nil,
                    customerIds: exportType == .customers ? selectedCustomerIds.map { $0.uuidString } : nil,
                    includeImages: true
                )
                
                let result: ExportTaskResponse = try await APIClient.shared.post(
                    path: "/api/export/tasks",
                    body: params
                )
                
                guard result.success, let tid = result.taskId else {
                    throw ExportError.taskCreationFailed
                }
                
                taskId = tid
                startPolling(taskId: tid)
                
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                    self.isExporting = false
                }
            }
        }
    }
    
    private func startPolling(taskId: String) {
        pollTimer?.invalidate()
        pollFailureCount = 0
        
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task {
                await self.pollTaskStatus(taskId: taskId)
            }
        }
    }
    
    private func pollTaskStatus(taskId: String) async {
        do {
            let result: ExportStatusResponse = try await APIClient.shared.get(
                path: "/api/export/tasks/\(taskId)"
            )
            
            await MainActor.run {
                self.pollFailureCount = 0
                self.exportProgress = result.progress
                self.exportStatus = result.currentStep
                
                if result.status == "completed" {
                    self.pollTimer?.invalidate()
                    self.isExporting = false
                    self.showResult = true
                    
                    if let downloadUrl = result.result?.downloadUrl {
                        // COS URL is already absolute, no need to prepend baseURL
                        let url: URL
                        if downloadUrl.hasPrefix("http") {
                            url = URL(string: downloadUrl)!
                        } else {
                            url = URL(string: APIConfig.baseURL + downloadUrl)!
                        }
                        self.downloadURL = url
                        // Auto-start download
                        self.startDownload(from: url)
                    }
                    self.zipSize = result.result?.fileSizeFormatted ?? "未知"
                    
                } else if result.status == "failed" {
                    self.pollTimer?.invalidate()
                    self.isExporting = false
                    self.errorMessage = result.error ?? "导出失败"
                    self.showError = true
                }
            }
        } catch {
            print("轮询失败: \(error)")
            if case APIError.serverError(404, _) = error {
                // 任务在服务器端不存在（如服务器重启且磁盘无备份），停止轮询并提示，避免界面永久卡在处理中
                await MainActor.run {
                    self.pollTimer?.invalidate()
                    self.isExporting = false
                    self.errorMessage = "导出任务已丢失（服务器可能重启），请重新导出"
                    self.showError = true
                }
            } else {
                // 网络抖动等其他错误：连续失败超过 15 次（约 30 秒）也停止并提示
                await MainActor.run {
                    self.pollFailureCount += 1
                    if self.pollFailureCount >= 15 {
                        self.pollTimer?.invalidate()
                        self.isExporting = false
                        self.errorMessage = "无法获取导出进度，请检查网络后重新导出"
                        self.showError = true
                    }
                }
            }
        }
    }
    
    private func startDownload(from url: URL) {
        guard let token = APIConfig.authToken else {
            errorMessage = "未登录，无法下载"
            showError = true
            return
        }
        
        let fileName = "BeautyManager导出_\(Date().formatted(.dateTime.year().month().day())).zip"
        downloadManager.downloadFile(from: url, token: token, fileName: fileName)
    }
}

// MARK: - 请求模型
struct ExportRequest: Codable {
    let type: String
    let storeId: String?
    let startDate: String?
    let endDate: String?
    let customerIds: [String]?
    let includeImages: Bool
}

// MARK: - 响应模型
struct ExportTaskResponse: Codable {
    let success: Bool
    let taskId: String?
    let status: String?
    let message: String?
}

struct ExportStatusResponse: Codable {
    let success: Bool
    let taskId: String
    let status: String
    let progress: Double
    let currentStep: String
    let result: ExportResult?
    let error: String?
}

struct ExportResult: Codable {
    let downloadUrl: String
    let filename: String
    let fileSize: Int
    let fileSizeFormatted: String
    let customerCount: Int
    let transactionCount: Int
    let imageCount: Int
}

enum ExportError: Error {
    case taskCreationFailed
    case downloadFailed
}

// MARK: - 辅助视图

struct CustomerMultiSelectView: View {
    let customers: [Customer]
    @Binding var selectedIds: Set<UUID>
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    var filteredCustomers: [Customer] {
        if searchText.isEmpty { return customers }
        return customers.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.phone.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredCustomers) { customer in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(customer.name)
                                .font(.body)
                            Text(customer.phone)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if selectedIds.contains(customer.id) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(.gray)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if selectedIds.contains(customer.id) {
                            selectedIds.remove(customer.id)
                        } else {
                            selectedIds.insert(customer.id)
                        }
                    }
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .navigationTitle("选择客户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}
