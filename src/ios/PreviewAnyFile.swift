import QuickLook
import CoreServices

@objc(HWPPreviewAnyFile)
class PreviewAnyFile: CDVPlugin {
    lazy var previewItem = NSURL()
    var tempCommandId = ""

    @objc(preview:)
    func preview(_ command: CDVInvokedUrlCommand) {
        tempCommandId = command.callbackId

        guard let myUrl = command.arguments.first as? String else {
            sendErrorResult("Missing URL", command.callbackId)
            return
        }

        downloadFile(withName: myUrl, fileName: "") { success, fileLocationURL, error in
            if success {
                self.showPreview(with: fileLocationURL)
            } else {
                self.sendErrorResult(error?.localizedDescription ?? "Failed to download file", command.callbackId)
            }
        }
    }

    @objc(previewPath:)
    func previewPath(_ command: CDVInvokedUrlCommand) {
        tempCommandId = command.callbackId

        guard let myUrl = command.arguments.first as? String else {
            sendErrorResult("Missing URL", command.callbackId)
            return
        }

        let name = command.arguments[1] as? String ?? ""
        let mimeType = command.arguments[2] as? String ?? ""

        var fileName = name.isEmpty ? "" : name

        if mimeType.isEmpty {
            let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mimeType as CFString, nil)
            if let ext = UTTypeCopyPreferredTagWithClass(uti!.takeRetainedValue(), kUTTagClassFilenameExtension)?.takeRetainedValue() as? String {
                fileName = "file.\(ext)"
            }
        }

        downloadFile(withName: myUrl, fileName: fileName) { success, fileLocationURL, error in
            if success {
                self.showPreview(with: fileLocationURL)
            } else {
                self.sendErrorResult(error?.localizedDescription ?? "Failed to download file", command.callbackId)
            }
        }
    }

    @objc(previewBase64:)
    func previewBase64(_ command: CDVInvokedUrlCommand) {
        tempCommandId = command.callbackId

        guard let base64String = command.arguments.first as? String else {
            sendErrorResult("No Base64 code found", command.callbackId)
            return
        }

        guard let mimeType = command.arguments[2] as? String, !mimeType.isEmpty else {
            sendErrorResult("You must define MIME type", command.callbackId)
            return
        }

        let name = command.arguments[1] as? String ?? ""
        var fileName = name.isEmpty ? "" : name

        let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mimeType as CFString, nil)
        if let ext = UTTypeCopyPreferredTagWithClass(uti!.takeRetainedValue(), kUTTagClassFilenameExtension)?.takeRetainedValue() as? String {
            fileName = "file.\(ext)"
        }

        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last else {
            sendErrorResult("Failed to get documents URL", command.callbackId)
            return
        }

        let fileURL = documentsURL.appendingPathComponent(fileName)

        guard let data = Data(base64Encoded: base64String) else {
            sendErrorResult("Invalid Base64 data", command.callbackId)
            return
        }

        do {
            try data.write(to: fileURL)
            showPreview(with: fileURL)
        } catch {
            sendErrorResult("Failed to write Base64 data", command.callbackId)
        }
    }

    private func downloadFile(withName myUrl: String, fileName: String, completion: @escaping (Bool, URL?, Error?) -> Void) {
        guard let itemUrl = URL(string: myUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!) else {
            completion(false, nil, NSError(domain: "Invalid URL", code: -1, userInfo: nil))
            return
        }

        let documentsDirectoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destinationURL = documentsDirectoryURL.appendingPathComponent(fileName.isEmpty ? itemUrl.lastPathComponent : fileName)

        let downloadTask = URLSession.shared.downloadTask(with: itemUrl) { (location, response, error) in
            if let error = error {
                completion(false, nil, error)
                return
            }

            guard let tempLocation = location else {
                completion(false, nil, NSError(domain: "Invalid location", code: -1, userInfo: nil))
                return
            }

            do {
                try FileManager.default.moveItem(at: tempLocation, to: destinationURL)
                completion(true, destinationURL, nil)
            } catch {
                completion(false, nil, error)
            }
        }

        downloadTask.resume()
    }

    private func showPreview(with fileLocationURL: URL?) {
        guard let fileLocationURL = fileLocationURL else {
            sendErrorResult("Failed to open file", tempCommandId)
            return
        }

        previewItem = fileLocationURL as NSURL

        DispatchQueue.main.async {
            let previewController = QLPreviewController()
            previewController.dataSource = self
            previewController.delegate = self
            self.viewController?.present(previewController, animated: true, completion: nil)
        }
    }

    private func sendErrorResult(_ message: String, _ callbackId: String) {
        let pluginResult = CDVPluginResult(status: .ERROR, messageAs: message)
        commandDelegate?.send(pluginResult, callbackId: callbackId)
    }
}

extension PreviewAnyFile: QLPreviewControllerDataSource, QLPreviewControllerDelegate {
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return 1
    }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return previewItem as QLPreviewItem
    }

    func previewControllerWillDismiss(_ controller: QLPreviewController) {
        dismissPreviewCallback()
    }

    private func dismissPreviewCallback() {
        let pluginResult = CDVPluginResult(status: .OK, messageAs: "CLOSING")
        commandDelegate?.send(pluginResult, callbackId: tempCommandId)
    }
}
