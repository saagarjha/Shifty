//
//  GeneralPreferencesViewController.swift
//  Shifty
//
//  Created by Nate Thompson on 11/10/17.
//

import Cocoa
import MASPreferences_Shifty
import ServiceManagement
import AXSwift

///The height difference between the custom schedule controls being shown and hidden
let PREF_GENERAL_HEIGHT_ADJUSTMENT = CGFloat(33.0)

@objcMembers
class PrefGeneralViewController: NSViewController, MASPreferencesViewController {

    override var nibName: NSNib.Name {
        return NSNib.Name("PrefGeneralViewController")
    }

    var viewIdentifier: String = "PrefGeneralViewController"

    var toolbarItemImage: NSImage? {
        return NSImage(named: .preferencesGeneral)
    }

    var toolbarItemLabel: String? {
        view.layoutSubtreeIfNeeded()
        return NSLocalizedString("prefs.general", comment: "General")
    }

    var hasResizableWidth = false
    var hasResizableHeight = false

    @IBOutlet weak var setAutoLaunch: NSButton!
    @IBOutlet weak var toggleStatusItem: NSButton!
    @IBOutlet weak var setIconSwitching: NSButton!
    @IBOutlet weak var darkModeSync: NSButton!

    @IBOutlet weak var schedulePopup: NSPopUpButton!
    @IBOutlet weak var offMenuItem: NSMenuItem!
    @IBOutlet weak var customMenuItem: NSMenuItem!
    @IBOutlet weak var sunMenuItem: NSMenuItem!

    @IBOutlet weak var fromTimePicker: NSDatePicker!
    @IBOutlet weak var toTimePicker: NSDatePicker!
    @IBOutlet weak var fromLabel: NSTextField!
    @IBOutlet weak var toLabel: NSTextField!
    @IBOutlet weak var customTimeStackView: NSStackView!

    let prefs = UserDefaults.standard
    var setStatusToggle: (() -> Void)?
    var updateSchedule: (() -> Void)?
    var updateDarkMode: (() -> Void)?

    var appDelegate: AppDelegate!
    var prefWindow: NSWindow!

    override func viewDidLoad() {
        super.viewDidLoad()

        appDelegate = NSApplication.shared.delegate as! AppDelegate
        prefWindow = appDelegate.preferenceWindowController.window

        updateSchedule = {
            switch NightShiftManager.schedule {
            case .off:
                self.schedulePopup.select(self.offMenuItem)
                self.setCustomControlVisibility(false, animate: true)
            case .custom(start: let startTime, end: let endTime):
                self.schedulePopup.select(self.customMenuItem)
                if let startDate = Date(startTime),
                    let endDate = Date(endTime) {
                    self.fromTimePicker.dateValue = startDate
                    self.toTimePicker.dateValue = endDate
                }
                self.setCustomControlVisibility(true, animate: true)
            case .solar:
                self.schedulePopup.select(self.sunMenuItem)
                self.setCustomControlVisibility(false, animate: true)
            }
        }
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        updateSchedule?()
    }

    //MARK: IBActions

    @IBAction func setAutoLaunch(_ sender: NSButtonCell) {
        let launcherAppIdentifier = "io.natethompson.ShiftyHelper"
        SMLoginItemSetEnabled(launcherAppIdentifier as CFString, setAutoLaunch.state == .on)
    }

    @IBAction func quickToggle(_ sender: NSButtonCell) {
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        appDelegate.setStatusToggle()
    }

    @IBAction func setIconSwitching(_ sender: Any) {
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        appDelegate.updateMenuBarIcon()
    }

    @IBAction func syncDarkMode(_ sender: NSButtonCell) {
        if sender.state == .on {
            updateDarkMode?()
        } else {
            SLSSetAppearanceThemeLegacy(false)
        }
    }

    @IBAction func setWebsiteControl(_ sender: NSButtonCell) {
        if sender.state == .on {
            if !UIElement.isProcessTrusted(withPrompt: false) {
                UserDefaults.standard.set(false, forKey: Keys.isWebsiteControlEnabled)
                let alert: NSAlert = NSAlert()
                alert.messageText = NSLocalizedString("alert.enable_accessibility_message", comment: "This feature requires accessibility permissions.")
                alert.informativeText = NSLocalizedString("alert.accessibility_informative", comment: "Grant access to Shifty in Security & Privacy preferences, located in System Preferences.")
                alert.alertStyle = NSAlert.Style.warning
                alert.addButton(withTitle: NSLocalizedString("alert.open_preferences", comment: "Open System Preferences"))
                alert.addButton(withTitle: NSLocalizedString("general.cancel", comment: "Cancel"))
                if alert.runModal() == .alertFirstButtonReturn {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                }
            }
        } else {
            stopBrowserWatcher()
        }
    }

    @IBAction func schedulePopup(_ sender: Any) {
        if schedulePopup.selectedItem == offMenuItem {
            NightShiftManager.schedule = .off
            setCustomControlVisibility(false, animate: true)
        } else if schedulePopup.selectedItem == customMenuItem {
            scheduleTimePickers(self)
            setCustomControlVisibility(true, animate: true)
        } else if schedulePopup.selectedItem == sunMenuItem {
            NightShiftManager.schedule = .solar
            setCustomControlVisibility(false, animate: true)

        }
    }

    @IBAction func scheduleTimePickers(_ sender: Any) {
        guard let fromTime = Time(fromTimePicker.dateValue),
            let toTime = Time(toTimePicker.dateValue) else {
                return
        }
        NightShiftManager.schedule = .custom(start: fromTime, end: toTime)
    }

    override func viewWillDisappear() {
        Event.preferences(autoLaunch: setAutoLaunch.state == .on, quickToggle: toggleStatusItem.state == .on, iconSwitching: setIconSwitching.state == .on, syncDarkMode: darkModeSync.state == .on, schedule: NightShiftManager.schedule).record()
    }

    func setCustomControlVisibility(_ visible: Bool, animate: Bool) {
        var adjustment = PREF_GENERAL_HEIGHT_ADJUSTMENT
        if customTimeStackView.isHidden == visible || (!visible && !animate) {
            if let frame = prefWindow?.frame {
                if visible {
                    //Keep elements hidden until after animation is completed
                    fromLabel.isHidden = true
                    fromTimePicker.isHidden = true
                    toLabel.isHidden = true
                    toTimePicker.isHidden = true
                } else {
                    adjustment *= -1
                }

                customTimeStackView.isHidden = !visible
                let newFrame = NSMakeRect(frame.origin.x, frame.origin.y - adjustment, frame.width, frame.height + adjustment)
                prefWindow.setFrame(newFrame, display: true, animate: animate)

                if visible {
                    fromLabel.isHidden = false
                    fromTimePicker.isHidden = false
                    toLabel.isHidden = false
                    toTimePicker.isHidden = false
                }
            }
        }
    }
}


class PrefWindowController: MASPreferencesWindowController {
    override func keyDown(with theEvent: NSEvent) {
        if theEvent.keyCode == 13 {
            window?.close()
        }
    }

    //Decreases window frame height if custom schedule controls are not shown
    override func getNewWindowFrame() -> NSRect {
        if NightShiftManager.schedule == ScheduleType.off || NightShiftManager.schedule == .solar {
            let newFrame = super.getNewWindowFrame()
            return NSMakeRect(newFrame.origin.x, newFrame.origin.y + PREF_GENERAL_HEIGHT_ADJUSTMENT, newFrame.width, newFrame.height - PREF_GENERAL_HEIGHT_ADJUSTMENT)
        } else {
            return super.getNewWindowFrame()
        }
    }
}
