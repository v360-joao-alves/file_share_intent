import UIKit
import Social
import MobileCoreServices

open class RSIShareViewController: SLComposeServiceViewController {
    
    public var appGroupId: String?
    public var hostAppBundleIdentifier: String?
    public var sharedMediaKey = "SharedMedia"
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        // Load app group ID from Info.plist
        if let bundleDict = Bundle.main.infoDictionary,
           let appGroupIdValue = bundleDict["AppGroupId"] as? String {
            appGroupId = appGroupIdValue
        }
        
        // Derive host app bundle identifier
        if let bundleId = Bundle.main.bundleIdentifier {
            let components = bundleId.components(separatedBy: ".")
            if components.count > 1 {
                hostAppBundleIdentifier = components.dropLast().joined(separator: ".")
            }
        }
    }
    
    open override func isContentValid() -> Bool {
        return true
    }
    
    open override func didSelectPost() {
        processAttachments { [weak self] items in
            self?.saveSharedItems(items)
            
            if self?.shouldAutoRedirect() == true {
                self?.redirectToHostApp()
            } else {
                self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            }
        }
    }
    
    open func shouldAutoRedirect() -> Bool {
        return true
    }
    
    private func processAttachments(completion: @escaping ([[String: Any]]) -> Void) {
        guard let extensionContext = extensionContext,
              let inputItems = extensionContext.inputItems as? [NSExtensionItem] else {
            completion([])
            return
        }
        
        let group = DispatchGroup()
        var sharedItems: [[String: Any]] = []
        
        // Include the text content from the compose view
        if let text = contentText, !text.isEmpty {
            sharedItems.append([
                "path": text,
                "type": "text"
            ])
        }
        
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
        
        group.notify(queue: .main) {
            completion(sharedItems)
        }
    }
    
    private func handleAttachment(_ provider: NSItemProvider, completion: @escaping ([String: Any]?) -> Void) {
        let urlType = "public.url"
        let textType = "public.text"
        let imageType = "public.image"
        let movieType = "public.movie"
        let dataType = "public.data"
        
        if provider.hasItemConformingToTypeIdentifier(urlType) {
            provider.loadItem(forTypeIdentifier: urlType, options: nil) { (data, error) in
                if let url = data as? URL {
                    completion(["path": url.absoluteString, "type": "url"])
                } else {
                    completion(nil)
                }
            }
            return
        }
        
        if provider.hasItemConformingToTypeIdentifier(textType) {
            provider.loadItem(forTypeIdentifier: textType, options: nil) { (data, error) in
                if let text = data as? String {
                    completion(["path": text, "type": "text"])
                } else {
                    completion(nil)
                }
            }
            return
        }
        
        if provider.hasItemConformingToTypeIdentifier(imageType) {
            provider.loadItem(forTypeIdentifier: imageType, options: nil) { [weak self] (data, error) in
                self?.handleFileData(data, type: "image", completion: completion)
            }
            return
        }
        
        if provider.hasItemConformingToTypeIdentifier(movieType) {
            provider.loadItem(forTypeIdentifier: movieType, options: nil) { [weak self] (data, error) in
                self?.handleFileData(data, type: "video", completion: completion)
            }
            return
        }
        
        if provider.hasItemConformingToTypeIdentifier(dataType) {
            provider.loadItem(forTypeIdentifier: dataType, options: nil) { [weak self] (data, error) in
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
            
            completion(["path": destinationUrl.absoluteString, "type": type])
        } catch {
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
    
    private func redirectToHostApp() {
        guard let hostAppBundleIdentifier = hostAppBundleIdentifier else {
            extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            return
        }
        
        let urlScheme = "ShareMedia-\(hostAppBundleIdentifier)://"
        guard let url = URL(string: urlScheme) else {
            extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            return
        }
        
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                application.open(url, options: [:]) { [weak self] _ in
                    self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
                }
                return
            }
            responder = responder?.next
        }
        
        let selector = sel_registerName("openURL:")
        responder = self
        while responder != nil {
            if responder!.responds(to: selector) {
                responder!.perform(selector, with: url)
                break
            }
            responder = responder?.next
        }
        
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
    
    open override func configurationItems() -> [Any]! {
        return []
    }
}