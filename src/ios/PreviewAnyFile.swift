import Cordova
import QuickLook

@objc(MyCordovaPlugin)
class MyCordovaPlugin: CDVPlugin, QLPreviewControllerDataSource {
    
    @objc(previewBase64:)
    func previewBase64(command: CDVInvokedUrlCommand) {
        guard let base64 = command.argument(at: 0) as? String,
              let name = command.argument(at: 1) as? String,
              let mediaType = command.argument(at: 2) as? String else {
            // Handle invalid arguments
            return
        }

        guard let decodedData = Data(base64Encoded: base64) else {
            // Handle decoding error
            return
        }

        let tempDirectoryURL = FileManager.default.temporaryDirectory
        let tempFilename = "\(name)_\(UUID().uuidString)" // Unique filename
        let tempFileURL = tempDirectoryURL.appendingPathComponent(tempFilename)

        do {
            try decodedData.write(to: tempFileURL, options: .atomic)
        } catch {
            // Handle file write error
            print("Error writing file: \(error)")
            return
        }

        let previewController = QLPreviewController()
        previewController.dataSource = self
        self.viewController?.present(previewController, animated: true)
    }

    // MARK: - QLPreviewControllerDataSource

    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return 1
    }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        fatalError("Not implemented. Implement this method to return the preview item.")
    }
}
