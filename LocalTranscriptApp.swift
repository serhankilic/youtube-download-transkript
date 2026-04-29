import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
        
        // Bağımsız (executable) çalışmalarda TextField klavye etkileşimleri için menü zorunludur.
        let mainMenu = NSMenu()
        
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: Selector(("cut:")), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: Selector(("copy:")), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: Selector(("paste:")), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Delete", action: Selector(("delete:")), keyEquivalent: "\u{8}"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: Selector(("selectAll:")), keyEquivalent: "a"))
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)
        
        NSApp.mainMenu = mainMenu
    }
}

@main
struct LocalTranscriptApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = TranscriptionViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
        }
        .windowResizability(.contentSize)

        Settings {
            EmptyView()
        }
    }
}
