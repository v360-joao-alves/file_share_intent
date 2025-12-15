import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers

open class RSIBaseShareViewController: UIViewController {
    
    public var appGroupId: String?
    public var hostAppBundleIdentifier: String?
    public var sharedMediaKey = "SharedMedia"
    
    // UI Configuration
    public var showUI = false
    public var processingMessage = "Processing..."
    public var autoRedirect = true
    
    private var processingView: UIView?
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        // Load app group ID from Info.plist
        if let bundleDict = Bundle.main.infoDictionary,
           let appGroupIdValue = bundleDict["AppGroupId"] as? String {
            appGroupId = appGroupIdValue
        }
        
        // Derive host app bundle identifier
        if let bundleId = Bundle.main.bundleIdentifier {
            // Remove the .ShareExtension suffix to get host app bundle ID
            let components = bundleId.components(separatedBy: ".")
            if components.count > 1 {
                hostAppBundleIdentifier = components.dropLast().joined(separator: ".")
            }
        }
        
        if showUI {
            showProcessingUI()
        }
        
        processAttachments()
    }
    
    private func showProcessingUI() {
        let containerView = UIView(frame: view.bounds)
        containerView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.color = .white
        activityIndicator.center = containerView.center
        activityIndicator.startAnimating()
        
        let label = UILabel()
        label.text = processingMessage
        label.textColor = .white
        label.textAlignment = .center
        label.frame = CGRect(x: 0, y: activityIndicator.frame.maxY + 16, width: containerView.bounds.width, height: 30)
        
        containerView.addSubview(activityIndicator)
        containerView.addSubview(label)
        view.addSubview(containerView)
        
        processingView = containerView
    }
    
    private func processAttachments() {
        guard let extensionContext = extensionContext,
              let inputItems = extensionContext.inputItems as? [NSExtensionItem] else {
            completeRequest()
            return
        }
        
        let group = DispatchGroup()
        var sharedItems: [[String: Any]] = []
        
        for item in inputItems {
            guard let attachments = item.attachments else { continue }
            
            for provider in attachments {
                group.enter()
                
                handleAttachment(provider) { result in
                    if let result = result {
                        sharedItems.append(result)
                    }
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            self?.saveSharedItems(sharedItems)
            self?.onAttachmentsProcessed()
            
            if self?.autoRedirect == true {
                self?.redirectToHostApp()
            } else {
                self?.completeRequest()
            }
        }
    }
    
    private func handleAttachment(_ provider: NSItemProvider, completion: @escaping ([String: Any]?) -> Void) {
        // Handle URLs
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { (data, error) in
                if let url = data as? URL {
                    completion([
                        "path": url.absoluteString,
                        "type": "url"
                    ])
                } else {
                    completion(nil)
                }
            }
            return
        }
        
        // Handle text
        if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { (data, error) in
                if let text = data as? String {
                    completion([
                        "path": text,
                        "type": "text"
                    ])
                } else {
                    completion(nil)
                }
            }
            return
        }
        
        // Handle images
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] (data, error) in
                self?.handleFileData(data, type: "image", completion: completion)
            }
            return
        }
        
        // Handle videos
        if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.movie.identifier, options: nil) { [weak self] (data, error) in
                self?.handleFileData(data, type: "video", completion: completion)
            }
            return
        }
        
        // Handle generic files
        if provider.hasItemConformingToTypeIdentifier(UTType.data.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.data.identifier, options: nil) { [weak self] (data, error) in
                self?.handleFileData(data, type: "file", completion: completion)
            }
            return
        }
        
        completion(nil)
    }
    
    private func handleFileData(_ data: Any?, type: String, completion: @escaping ([String: Any]?) -> Void) {
        guard let appGroupId = appGroupId else {
            completion(nil)
            return
        }
        
        var fileUrl: URL?
        
        if let url = data as? URL {
            fileUrl = url
        } else if let image = data as? UIImage, let imageData = image.pngData() {
            let tempUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId)?
                .appendingPathComponent("\(UUID().uuidString).png")
            if let tempUrl = tempUrl {
                try? imageData.write(to: tempUrl)
                fileUrl = tempUrl
            }
        }
        
        guard let url = fileUrl else {
            completion(nil)
            return
        }
        
        // Copy to shared container
        guard let containerUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            completion(nil)
            return
        }
        
        let fileName = url.lastPathComponent
        let destinationUrl = containerUrl.appendingPathComponent(fileName)
        
        do {
            if FileManager.default.fileExists(atPath: destinationUrl.path) {
                try FileManager.default.removeItem(at: destinationUrl)
            }
            try FileManager.default.copyItem(at: url, to: destinationUrl)
            
            completion([
                "path": destinationUrl.absoluteString,
                "type": type
            ])
        } catch {
            print("Error copying file: \(error)")
            completion(nil)
        }
    }
    
    private func saveSharedItems(_ items: [[String: Any]]) {
        guard let appGroupId = appGroupId else { return }
        
        let userDefaults = UserDefaults(suiteName: appGroupId)
        if let data = try? JSONSerialization.data(withJSONObject: items, options: []) {
            userDefaults?.set(data, forKey: sharedMediaKey)
            userDefaults?.synchronize()
        }
    }
    
    open func onAttachmentsProcessed() {
        // Override in subclass for custom behavior
    }
    
    private func redirectToHostApp() {
        guard let hostAppBundleIdentifier = hostAppBundleIdentifier else {
            completeRequest()
            return
        }
        
        let urlScheme = "ShareMedia-\(hostAppBundleIdentifier)://"
        guard let url = URL(string: urlScheme) else {
            completeRequest()
            return
        }
        
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                application.open(url, options: [:]) { [weak self] _ in
                    self?.completeRequest()
                }
                return
            }
            responder = responder?.next
        }
        
        // Fallback: use openURL selector
        let selector = sel_registerName("openURL:")
        responder = self
        while responder != nil {
            if responder!.responds(to: selector) {
                responder!.perform(selector, with: url)
                break
            }
            responder = responder?.next
        }
        
        completeRequest()
    }
    
    public func completeRequest() {
        processingView?.removeFromSuperview()
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}