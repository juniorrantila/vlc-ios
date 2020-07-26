/*****************************************************************************
 * SettingsController.swift
 * VLC for iOS
 *****************************************************************************
 * Copyright (c) 2013-2020 VideoLAN. All rights reserved.
 *
 * Authors: Swapnanil Dhol <swapnanildhol # gmail.com>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

import UIKit
import LocalAuthentication

class SettingsController: UITableViewController {

    private let cellReuseIdentifier = "settingsCell"
    private let sectionHeaderReuseIdentifier = "sectionHeaderReuseIdentifier"
    private let sectionFooterReuseIdentifier = "sectionFooterReuseIdentifier"
    private let userDefaults = UserDefaults.standard
    private let notificationCenter = NotificationCenter.default
    private let actionSheet = ActionSheet()
    private let specifierManager = ActionSheetSpecifier()
    private var mediaLibraryService = MediaLibraryService()
    private var localeDictionary = NSDictionary()

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return PresentationTheme.current.colors.statusBarStyle
    }

    init(mediaLibraryService: MediaLibraryService) {
        super.init(style: .grouped)
        self.mediaLibraryService = mediaLibraryService
        self.mediaLibraryService.deviceBackupDelegate = self
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        PlaybackService.sharedInstance().playerDisplayController.isMiniPlayerVisible ? self.miniPlayerIsShown() : self.miniPlayerIsHidden()
    }

    private func setup() {
        setupUI()
        setNavBarAppearance()
        registerTableViewClasses()
        setupBarButton()
        addObservers()
    }

// MARK: - Setup Functions

    private func setupUI() {
        self.title = NSLocalizedString("Settings", comment: "")
        self.tabBarItem = UITabBarItem(title: NSLocalizedString("Settings", comment: ""),
                                       image: UIImage(named: "Settings"),
                                       selectedImage: UIImage(named: "Settings"))
        self.tabBarItem.accessibilityIdentifier = VLCAccessibilityIdentifier.settings
        tableView.separatorStyle = .none
        view.backgroundColor = PresentationTheme.current.colors.background
        actionSheet.modalPresentationStyle = .custom
        guard let localDict = getLocaleDictionary() else { return }
        localeDictionary = localDict
    }

    private func addObservers() {
        notificationCenter.addObserver(self,
                                       selector: #selector(themeDidChange),
                                       name: .VLCThemeDidChangeNotification,
                                       object: nil)
        notificationCenter.addObserver(self,
                                       selector: #selector(miniPlayerIsShown),
                                       name: NSNotification.Name(rawValue: VLCPlayerDisplayControllerDisplayMiniPlayer),
                                       object: nil)
        notificationCenter.addObserver(self,
                                       selector: #selector(miniPlayerIsHidden),
                                       name: NSNotification.Name(rawValue: VLCPlayerDisplayControllerHideMiniPlayer),
                                       object: nil)
    }

    private func registerTableViewClasses() {
        tableView.register(SettingsCell.self,
                           forCellReuseIdentifier: cellReuseIdentifier)
        tableView.register(SettingsHeaderView.self,
                           forHeaderFooterViewReuseIdentifier: sectionHeaderReuseIdentifier)
        tableView.register(SettingsFooterView.self,
                           forHeaderFooterViewReuseIdentifier: sectionFooterReuseIdentifier)
    }

    private func setupBarButton() {
        let aboutBarButton = UIBarButtonItem(title: NSLocalizedString("BUTTON_ABOUT", comment: ""),
                                             style: .plain,
                                             target: self,
                                             action: #selector(showAbout))
        aboutBarButton.tintColor = PresentationTheme.current.colors.orangeUI
        navigationItem.leftBarButtonItem = aboutBarButton
        self.navigationItem.leftBarButtonItem?.accessibilityIdentifier = VLCAccessibilityIdentifier.about
    }

    private func setNavBarAppearance() {
        if #available(iOS 13.0, *) {
            let navigationBarAppearance = AppearanceManager.navigationbarAppearance
            self.navigationController?.navigationBar.standardAppearance = navigationBarAppearance()
            self.navigationController?.navigationBar.scrollEdgeAppearance = navigationBarAppearance()
        }
    }

// MARK: - Observer & BarButton Actions

    @objc private func showAbout() {
        if #available(iOS 10, *) {
            ImpactFeedbackGenerator().selectionChanged()
        }
        let aboutController = AboutController()
        let aboutNavigationController = AboutNavigationController(rootViewController: aboutController)
        present(aboutNavigationController, animated: true)
    }

    @objc private func themeDidChange() {
        self.view.backgroundColor = PresentationTheme.current.colors.background
        setNavBarAppearance()
        self.setNeedsStatusBarAppearanceUpdate()
    }

    @objc private func miniPlayerIsShown() {
        self.tableView.contentInset = UIEdgeInsets(top: 0,
                                                   left: 0,
                                                   bottom: CGFloat(AudioMiniPlayer.height),
                                                   right: 0)
    }

    @objc private func miniPlayerIsHidden() {
        self.tableView.contentInset = UIEdgeInsets(top: 0,
                                                   left: 0,
                                                   bottom: 0,
                                                   right: 0)
    }

// MARK: - Helper Functions

    private func forceRescanAlert() {
        if #available(iOS 10, *) {
            NotificationFeedbackGenerator().warning()
        }
        let alert = UIAlertController(title: NSLocalizedString("FORCE_RESCAN_TITLE", comment: ""),
                                      message: NSLocalizedString("FORCE_RESCAN_MESSAGE", comment: ""),
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("BUTTON_CANCEL", comment: ""),
                                      style: .cancel,
                                      handler: nil))
        alert.addAction(UIAlertAction(title: NSLocalizedString("BUTTON_RESCAN", comment: ""),
                                      style: .destructive,
                                      handler: { _ in
                                        if #available(iOS 10, *) {
                                            ImpactFeedbackGenerator().selectionChanged()
                                        }
                                        self.forceRescanLibrary()
        }))
        present(alert, animated: true, completion: nil)
    }

    private func forceRescanLibrary() {
        let queue = DispatchQueue.global(qos: .background)
        queue.async {
            self.mediaLibraryService.forceRescan()
        }
    }

    private func openPrivacySettings() {
        if #available(iOS 10.0, *) {
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url,
                                      options: [:],
                                      completionHandler: nil)
        }
    }

    private func showActionSheet(for sectionType: SectionType?) {
        guard let sectionType = sectionType else { return }
        guard !sectionType.containsSwitch else { return }
        guard let preferenceKey = sectionType.preferenceKey else {
            assertionFailure("SettingsController: No Preference Key Available.")
            return
        }
        showActionSheet(preferenceKey: preferenceKey)
    }

    private func showActionSheet(preferenceKey: String?) {
        specifierManager.preferenceKey = preferenceKey
        actionSheet.delegate = specifierManager
        actionSheet.dataSource = specifierManager
        present(actionSheet, animated: false) {
            self.actionSheet.collectionView.selectItem(at: self.specifierManager.selectedIndex, animated: false, scrollPosition: .centeredVertically)
        }
    }

    private func playHaptics(sectionType: SectionType?) {
        guard let sectionType = sectionType else { return }
        if #available(iOS 10, *), !sectionType.containsSwitch {
            ImpactFeedbackGenerator().selectionChanged()
        }
    }
}

extension SettingsController {

    override func numberOfSections(in tableView: UITableView) -> Int {
        return SettingsSection.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return MainOptions.allCases.count
        case 1:
            return GenericOptions.allCases.count
        case 2:
            return PrivacyOptions.allCases.count
        case 3:
            return PlaybackControlOptions.allCases.count
        case 4:
            return VideoOptions.allCases.count
        case 5:
            return SubtitlesOptions.allCases.count
        case 6:
            return AudioOptions.allCases.count
        case 7:
            return CastingOptions.allCases.count
        case 8:
            return MediaLibraryOptions.allCases.count
        case 9:
            return FileSyncOptions.allCases.count
        default:
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath == [1, 1] && !userDefaults.bool(forKey: kVLCSettingPasscodeOnKey) {
            //If the passcode lock is on we return a default UITableViewCell else
            //while hiding the biometric option row using a cell height of 0
            //constraint warnings will be printed to the console since the cell height (0)
            //collapses on given constraints (Top, leading, trailing, Bottom of StackView to Cell)
            return UITableViewCell()
        }
        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier, for: indexPath) as? SettingsCell else {
            return UITableViewCell()
        }
        guard let section = SettingsSection(rawValue: indexPath.section) else {
            return UITableViewCell()
        }
        switch section {
        case .main:
            let main = MainOptions(rawValue: indexPath.row)
            cell.sectionType = main
        case .generic:
            let generic = GenericOptions(rawValue: indexPath.row)
            cell.sectionType = generic
        case .privacy:
            let privacy = PrivacyOptions(rawValue: indexPath.row)
            let isPasscodeOn = userDefaults.bool(forKey: kVLCSettingPasscodeOnKey)
            if !isPasscodeOn && indexPath.row == 1 {
                cell.isHidden = true
            }
            cell.sectionType = privacy
            cell.passcodeSwitchDelegate = self
            cell.medialibraryHidingSwitchDelegate = self
        case .gestureControl:
            let gestureControlOptions = PlaybackControlOptions(rawValue: indexPath.row)
            cell.sectionType = gestureControlOptions
        case .video:
            let videoOptions = VideoOptions(rawValue: indexPath.row)
            cell.sectionType = videoOptions
        case .subtitles:
            let subtitlesOptions = SubtitlesOptions(rawValue: indexPath.row)
            cell.sectionType = subtitlesOptions
        case .audio:
            let audioOptions = AudioOptions(rawValue: indexPath.row)
            cell.sectionType = audioOptions
        case .casting:
            let castingOptions = CastingOptions(rawValue: indexPath.row)
            cell.sectionType = castingOptions
        case .mediaLibrary:
            let mediaLibOptions = MediaLibraryOptions(rawValue: indexPath.row)
            cell.sectionType = mediaLibOptions
            if indexPath.row == 0 {
                cell.accessoryView = .none
                cell.accessoryType = .none
            }
        case .fileSync:
            let fileSyncOptions = FileSyncOptions(rawValue: indexPath.row)
            cell.sectionType = fileSyncOptions
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let section = SettingsSection(rawValue: indexPath.section) else { return }
        if section == .main && indexPath.row == 0 {
            openPrivacySettings()
            return
        }
        if section == .mediaLibrary && indexPath.row == 0 {
            forceRescanAlert()
            return
        }
        switch section {
        case .main:
            let mainSection = MainOptions(rawValue: indexPath.row)
            playHaptics(sectionType: mainSection)
            showActionSheet(for: mainSection)
        case .generic:
            let genericSection = GenericOptions(rawValue: indexPath.row)
            playHaptics(sectionType: genericSection)
            showActionSheet(for: genericSection)
        case .privacy:
            let privacySection = PrivacyOptions(rawValue: indexPath.row)
            playHaptics(sectionType: privacySection)
        case .gestureControl:
            break
        case .video:
            let videoSection = VideoOptions(rawValue: indexPath.row)
            playHaptics(sectionType: videoSection)
            showActionSheet(for: videoSection)
        case .subtitles:
            let subtitleSection = SubtitlesOptions(rawValue: indexPath.row)
            playHaptics(sectionType: subtitleSection)
            showActionSheet(for: subtitleSection)
        case .audio:
            break
        case .casting:
            break
        case .mediaLibrary:
            break
        case .fileSync:
            let fileSection = FileSyncOptions(rawValue: indexPath.row)
            playHaptics(sectionType: fileSection)
            showActionSheet(for: fileSection)
        }
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let headerView = tableView.dequeueReusableHeaderFooterView( withIdentifier: sectionHeaderReuseIdentifier) as? SettingsHeaderView else { return nil }
        guard let description = SettingsSection.init(rawValue: section)?.description else { return nil }
        headerView.sectionHeaderLabel.text = localeDictionary[description] as? String
        return headerView
    }

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        guard let footerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: sectionFooterReuseIdentifier) as? SettingsFooterView else { return nil }
        return section == 8 ? nil : footerView
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return section == 0 ? 0 : 64
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 25
    }

    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 64
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let isPasscodeOn = userDefaults.bool(forKey: kVLCSettingPasscodeOnKey)
        let automaticDimension = UITableView.automaticDimension
        if isPasscodeOn {
            return automaticDimension
        } else {
            return indexPath == [SettingsSection.privacy.rawValue, PrivacyOptions.enableBiometrics.rawValue] ? 0 : automaticDimension //Hides Biometric Row if Passcode Lock is off
        }
    }
}

extension SettingsController: MediaLibraryDeviceBackupDelegate {

    func medialibraryDidStartExclusion() {
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }

    func medialibraryDidCompleteExclusion() {
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
}

extension SettingsController: MediaLibraryHidingDelegate {
    func medialibraryDidStartHiding() {
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }

    func medialibraryDidCompleteHiding() {
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
}

extension SettingsController: PasscodeActivateDelegate {

    func passcodeLockSwitchOn(state: Bool) {
        if state {
            guard let passcodeLockController = PasscodeLockController(action: .set) else { return }
            let passcodeNavigationController = UINavigationController(rootViewController: passcodeLockController)
            passcodeNavigationController.modalPresentationStyle = .fullScreen
            present(passcodeNavigationController, animated: true) {
                self.tableView.reloadData() //To show/hide biometric row
            }
        } else {
            tableView.reloadData()
        }
    }
}

extension SettingsController: MedialibraryHidingActivateDelegate {
    func medialibraryHidingLockSwitchOn(state: Bool) {
        mediaLibraryService.hideMediaLibrary(state)
    }
}
