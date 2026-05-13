//
//  CatalystFilePicker.swift
//  WSP Reader
//
//  NSOpenPanel is marked NS_UNAVAILABLE in the Catalyst SDK headers, but AppKit IS
//  loaded in every Catalyst process at runtime. We bypass the compile-time check by
//  reaching NSOpenPanel through the ObjC runtime (NSClassFromString + KVC + perform),
//  which has no availability enforcement.
//

#if targetEnvironment(macCatalyst)
import Foundation
import UniformTypeIdentifiers
import ObjectiveC

enum CatalystFilePicker {
    static func open(allowedTypes: [UTType], completion: @escaping (URL?) -> Void) {
        // Obtain NSOpenPanel via ObjC runtime — exists at runtime despite Swift headers
        // marking the class unavailable on Catalyst.
        guard let panelClass = NSClassFromString("NSOpenPanel") as? NSObject.Type,
              let panel = panelClass.perform(NSSelectorFromString("openPanel"))?.takeUnretainedValue() as? NSObject else {
            print("[WSPReader] CatalystFilePicker: NSOpenPanel not found at runtime")
            DispatchQueue.main.async { completion(nil) }
            return
        }

        panel.setValue(true, forKey: "canChooseFiles")
        panel.setValue(false, forKey: "canChooseDirectories")
        panel.setValue(false, forKey: "allowsMultipleSelection")
        panel.setValue("Open Writing Shed Pro Project", forKey: "title")
        panel.setValue(allowedTypes.compactMap(\.preferredFilenameExtension), forKey: "allowedFileTypes")

        // Pass a Swift closure as an ObjC block to beginWithCompletionHandler:
        // @convention(block) makes the closure ABI-compatible with an ObjC block object.
        let block: @convention(block) (Int) -> Void = { response in
            DispatchQueue.main.async {
                let url = response == 1 ? (panel.value(forKey: "URL") as? URL) : nil
                print("[WSPReader] NSOpenPanel response=\(response) url=\(url?.lastPathComponent ?? "nil")")
                completion(url)
            }
        }
        panel.perform(NSSelectorFromString("beginWithCompletionHandler:"), with: block as AnyObject)
    }
}
#endif
