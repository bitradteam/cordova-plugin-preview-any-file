import QuickLook
import CoreServices

@objc(HWPPreviewAnyFile)
class PreviewAnyFile: CDVPlugin {
    lazy var previewItem = NSURL()
    var tempCommandId = String()

    @objc(preview:)
    func preview(_ command: CDVInvokedUrlCommand) {
        tempCommandId = command.callbackId

        guard let myUrl = command.arguments.first as? String else {
            sendErrorPluginResult("Invalid file URL", command.callbackId)
            return
        }

        downloadFile(withName: myUrl, fileName: "") { success, fileLocationURL, error in
            if success, let fileLocation = fileLocationURL {
                self.previewItem = fileLocation as NSURL
                DispatchQueue.main.async {
                    self.presentPreviewController()
                }
            } else {
                self.sendErrorPluginResult(error?.localizedDescription ?? "Failed to download file", command.callbackId)
            }
        }
    }

    @objc(previewPath:)
    func previewPath(_ command: CDVInvokedUrlCommand) {
        tempCommandId = command.callbackId

        guard let myUrl = command.arguments.first as? String else {
            sendErrorPluginResult("Invalid file URL", command.callbackId)
            return
        }

        // Additional arguments handling...

        downloadFile(withName: myUrl, fileName: "") { success, fileLocationURL, error in
            if success, let fileLocation = fileLocationURL {
                self.previewItem = fileLocation as NSURL
                DispatchQueue.main.async {
                    self.presentPreviewController()
                }
            } else {
                self.sendErrorPluginResult(error?.localizedDescription ?? "Failed to download file", command.callbackId)
            }
        }
    }

    @objc(previewBase64:)
    func previewBase64(_ command: CDVInvokedUrlCommand) {
        var pluginResult = CDVPluginResult(
            status: CDVCommandStatus_ERROR
        )
        tempCommandId = command.callbackId
        var ext: String = ""
        guard let base64String = command.arguments[0] as? String else {
            sendErrorPluginResult("No Base64 code found", command.callbackId)
            return
        }

        let mimeType = command.arguments[2] as? String ?? ""
        let name = command.arguments[1] as? String ?? ""

        if base64String.isEmpty {
            sendErrorPluginResult("No Base64 code found", command.callbackId)
            return
        } else if base64String.contains(";base64,") {
            let baseTmp = base64String.components(separatedBy: ",")
            let cleanMimeType = baseTmp[0].replacingOccurrences(of: "data:", with: "").replacingOccurrences(of: ";base64", with: "")
            ext = UTTypeCopyPreferredTagWithClass(cleanMimeType as CFString, kUTTagClassFilenameExtension)?.takeRetainedValue() as? String ?? ""
        }

        let fileName = name.isEmpty ? "file.\(ext)" : name

        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last,
              let convertedData = Data(base64Encoded: base64String) else {
            sendErrorPluginResult("Invalid base64 data", command.callbackId)
            return
        }

        let fileURL = documentsURL.appendingPathComponent(fileName)

        do {
            try convertedData.write(to: fileURL)
            downloadFile(withName: fileURL.absoluteString, fileName: fileName) { success, fileLocationURL, error in
                if success, let fileLocation = fileLocationURL {
                    self.previewItem = fileLocation as NSURL
                    DispatchQueue.main.async {
                        self.presentPreviewController()
                    }
                } else {
                    self.sendErrorPluginResult(error?.localizedDescription ?? "Failed to download file", command.callbackId)
                }
            }
        } catch {
            sendErrorPluginResult("Failed to write base64 data", command.callbackId)
        }
    }

    func downloadFile(withName myUrl: String, fileName: String, completion: @escaping (_ success: Bool, _ fileLocation: URL?, _ error: Error?) -> Void) {
        guard let itemUrl = URL(string: myUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") else {
            completion(false, nil, NSError(domain: "InvalidURL", code: 0, userInfo: nil))
            return
        }

        if FileManager.default.fileExists(atPath: itemUrl.path) {
            if itemUrl.scheme == nil {
                completion(true, itemUrl, nil)
            }
            return completion(true, itemUrl, nil)
        }

        let documentsDirectoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destinationUrl = documentsDirectoryURL.appendingPathComponent(fileName)

        if FileManager.default.fileExists(atPath: destinationUrl.path) {
            do {
                try FileManager.default.removeItem(at: destinationUrl)
            } catch let error as NSError {
                completion(false, nil, error)
            }
        }
        let downloadTask = URLSession.shared.downloadTask(with: itemUrl) { location, _, error in
            guard let tempLocation = location, error == nil else {
                completion(false, nil, error)
                return
            }
            do {
                try FileManager.default.moveItem(at: tempLocation, to: destinationUrl)
                completion(true, destinationUrl, nil)
            } catch let error as NSError {
                completion(false, nil, error)
            }
        }
        downloadTask.resume()
    }

    func presentPreviewController() {
        let previewController = QLPreviewController()
        previewController.dataSource = self
        previewController.delegate = self
        viewController?.present(previewController, animated: true, completion: nil)
    }

    func sendErrorPluginResult(_ errorMessage: String, _ callbackId: String) {
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: errorMessage)
        commandDelegate?.send(pluginResult, callbackId: callbackId)
    }
}

extension PreviewAnyFile: QLPreviewControllerDataSource, QLPreviewControllerDelegate {
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return 1
    }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return self.previewItem as QLPreviewItem
    }

    func previewControllerWillDismiss(_ controller: QLPreviewController) {
        dismissPreviewCallback()
    }

    func dismissPreviewCallback() {
        print(tempCommandId)
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "CLOSING")
        commandDelegate?.send(pluginResult, callbackId: tempCommandId)
    }
}
