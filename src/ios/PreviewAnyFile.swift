import QuickLook
import CoreServices

@objc(HWPPreviewAnyFile)
class PreviewAnyFile: CDVPlugin {
    var previewItem: NSURL?
    var tempCommandId: String?

    @objc(preview:)
    func preview(_ command: CDVInvokedUrlCommand) {
        guard let myUrl = command.arguments[0] as? String else {
            sendErrorResult(message: "Invalid URL", command: command)
            return
        }

        tempCommandId = command.callbackId

        downloadFile(withName: myUrl, fileName: "") { success, fileLocationURL, callback in
            if success {
                self.previewItem = fileLocationURL as NSURL?

                DispatchQueue.main.async {
                    let previewController = QLPreviewController()
                    previewController.dataSource = self
                    previewController.delegate = self
                    self.viewController?.present(previewController, animated: true, completion: nil)

                    let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "SUCCESS")
                    pluginResult?.keepCallback = true
                    self.commandDelegate?.send(pluginResult, callbackId: command.callbackId)
                }
            } else {
                self.sendErrorResult(message: callback?.localizedDescription ?? "Unknown error", command: command)
            }
        }
    }

    @objc(previewPath:)
    func previewPath(_ command: CDVInvokedUrlCommand) {
        guard let myUrl = command.arguments[0] as? String else {
            sendErrorResult(message: "Invalid URL", command: command)
            return
        }
        
        let fileName = command.arguments[1] as? String ?? ""
        
        downloadFile(withName: myUrl, fileName: fileName) { success, fileLocationURL, callback in
            if success {
                self.previewItem = fileLocationURL as NSURL?
                
                DispatchQueue.main.async {
                    let previewController = QLPreviewController()
                    previewController.dataSource = self
                    previewController.delegate = self
                    self.viewController?.present(previewController, animated: true, completion: nil)
                    
                    let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "SUCCESS")
                    pluginResult?.keepCallback = true
                    self.commandDelegate?.send(pluginResult, callbackId: command.callbackId)
                }
            } else {
                self.sendErrorResult(message: callback?.localizedDescription ?? "Unknown error", command: command)
            }
        }
    }

    @objc(previewBase64:)
    func previewBase64(_ command: CDVInvokedUrlCommand) {
        guard let base64String = command.arguments[0] as? String else {
            sendErrorResult(message: "Invalid Base64 string", command: command)
            return
        }
        
        let mimeType = command.arguments[2] as? String ?? ""
        let fileName = command.arguments[1] as? String ?? ""
        
        // Decode Base64 string and write to file
        
        guard let data = Data(base64Encoded: base64String) else {
            sendErrorResult(message: "Invalid Base64 string", command: command)
            return
        }
        
        let documentsDirectoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsDirectoryURL.appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            self.previewItem = fileURL as NSURL?
            
            DispatchQueue.main.async {
                let previewController = QLPreviewController()
                previewController.dataSource = self
                previewController.delegate = self
                self.viewController?.present(previewController, animated: true, completion: nil)
                
                let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "SUCCESS")
                pluginResult?.keepCallback = true
                self.commandDelegate?.send(pluginResult, callbackId: command.callbackId)
            }
        } catch {
            sendErrorResult(message: error.localizedDescription, command: command)
        }
    }

    func downloadFile(withName myUrl: String, fileName: String, completion: @escaping (_ success: Bool, _ fileLocation: URL?, _ callback: NSError?) -> Void) {
        // Implement downloadFile function here...
        guard let url = URL(string: myUrl) else {
            completion(false, nil, NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }
        
        let task = URLSession.shared.downloadTask(with: url) { (location, response, error) in
            guard let tempLocation = location, error == nil else {
                completion(false, nil, error as NSError?)
                return
            }
            
            let documentsDirectoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let destinationURL = documentsDirectoryURL.appendingPathComponent(fileName.isEmpty ? url.lastPathComponent : fileName)
            
            do {
                try FileManager.default.moveItem(at: tempLocation, to: destinationURL)
                completion(true, destinationURL, nil)
            } catch {
                completion(false, nil, error as NSError?)
            }
        }
        
        task.resume()
    }

    func dismissPreviewCallback() {
        print(tempCommandId ?? "")
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "CLOSING")
        self.commandDelegate?.send(pluginResult, callbackId: tempCommandId)
    }

    private func sendErrorResult(message: String, command: CDVInvokedUrlCommand) {
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: message)
        self.commandDelegate?.send(pluginResult, callbackId: command.callbackId)
    }
}

extension PreviewAnyFile: QLPreviewControllerDataSource, QLPreviewControllerDelegate {
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return 1
    }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return self.previewItem ?? NSURL()
    }

    func previewControllerWillDismiss(_ controller: QLPreviewController) {
        self.dismissPreviewCallback()
    }
}
