import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Default", sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: scene)
        let root: UIViewController = ProcessInfo.processInfo.arguments.contains("-showChecker") ? CheckerController() : GameController()
        window.rootViewController = UINavigationController(rootViewController: root)
        window.makeKeyAndVisible()
        self.window = window
    }
}

final class CheckerController: UIViewController, UITextFieldDelegate {
    private let accent = UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.53, green: 0.87, blue: 0.74, alpha: 1) : UIColor(red: 0.10, green: 0.32, blue: 0.26, alpha: 1) }
    private let scroll = UIScrollView()
    private let field = UITextField()
    private let picker = UISegmentedControl(items: ["NASPA", "Collins"])
    private let result = UILabel()
    private let resultIcon = UIImageView()
    private let card = UIStackView()
    private let check = UIButton(type: .system)
    private var dictionary: WordDictionary?
    private var submitted: String?
    private var lexicon: Lexicon { Lexicon(rawValue: picker.selectedSegmentIndex) ?? .naspa }

    init(dictionary: WordDictionary? = nil) {
        self.dictionary = dictionary
        super.init(nibName:nil,bundle:nil)
    }
    required init?(coder:NSCoder) { fatalError() }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.tintColor = accent
        view.backgroundColor = .systemBackground
        scroll.keyboardDismissMode = .interactive
        scroll.alwaysBounceVertical = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor)
        ])
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        let width = stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -40)
        width.priority = .defaultHigh
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.centerXAnchor.constraint(equalTo: scroll.frameLayoutGuide.centerXAnchor),
            width, stack.widthAnchor.constraint(lessThanOrEqualToConstant: 500)
        ])
        picker.selectedSegmentIndex = UserDefaults.standard.integer(forKey: "lexicon") == 1 ? 1 : 0
        picker.accessibilityIdentifier = "dictionaryPicker"
        picker.accessibilityValue = lexicon.detail
        picker.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        picker.addTarget(self, action: #selector(changeDictionary), for: .valueChanged)
        navigationItem.titleView = picker
        picker.widthAnchor.constraint(equalToConstant: 220).isActive = true
        field.font = UIFontMetrics(forTextStyle: .title1).scaledFont(for: .systemFont(ofSize: 30, weight: .medium))
        field.adjustsFontForContentSizeCategory = true
        field.placeholder = "Word"
        field.accessibilityLabel = "Word to check"
        field.accessibilityIdentifier = "wordInput"
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 20, height: 1))
        field.leftViewMode = .always
        field.clearButtonMode = .whileEditing
        field.autocapitalizationType = .allCharacters
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.smartQuotesType = .no
        field.smartDashesType = .no
        field.keyboardType = .asciiCapable
        field.returnKeyType = .go
        field.enablesReturnKeyAutomatically = true
        field.delegate = self
        let toolbar = UIToolbar()
        toolbar.items = [UIBarButtonItem(systemItem: .flexibleSpace), UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in self?.view.endEditing(true) })]
        toolbar.sizeToFit()
        field.inputAccessoryView = toolbar
        let close = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) })
        close.accessibilityIdentifier = "closeChecker"
        navigationItem.leftBarButtonItem = close
        field.heightAnchor.constraint(greaterThanOrEqualToConstant: 76).isActive = true
        field.addTarget(self, action: #selector(editing), for: .editingChanged)
        stack.addArrangedSubview(glass(around: field))
        var config = UIButton.Configuration.glass()
        config.title = "Check"
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 18, leading: 20, bottom: 18, trailing: 20)
        check.configuration = config
        check.accessibilityIdentifier = "checkWord"
        check.accessibilityLabel = "Check word"
        check.addTarget(self, action: #selector(submit), for: .touchUpInside)
        stack.addArrangedSubview(check)
        card.spacing = 10
        card.alignment = .center
        card.isLayoutMarginsRelativeArrangement = true
        card.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
        result.font = UIFontMetrics(forTextStyle: .title2).scaledFont(for: .systemFont(ofSize: 23, weight: .semibold))
        result.adjustsFontForContentSizeCategory = true
        result.numberOfLines = 0
        result.accessibilityIdentifier = "verdict"
        resultIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 25, weight: .medium)
        resultIcon.contentMode = .scaleAspectFit
        resultIcon.widthAnchor.constraint(equalToConstant: 28).isActive = true
        resultIcon.isAccessibilityElement = false
        card.addArrangedSubview(resultIcon)
        card.addArrangedSubview(result)
        stack.addArrangedSubview(card)
        do { if dictionary == nil { dictionary = try WordDictionary() }; card.isHidden = true }
        catch { showResult("Dictionary unavailable. Please reinstall.", symbol: "exclamationmark.circle", color: .secondaryLabel) }
        editing()
    }
    private func glass(around content: UIView) -> UIView {
        let effect = UIGlassEffect(style: .regular)
        let glass = UIVisualEffectView(effect: effect)
        glass.layer.cornerRadius = 28
        glass.layer.cornerCurve = .continuous
        glass.clipsToBounds = true
        content.translatesAutoresizingMaskIntoConstraints = false
        glass.contentView.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: glass.contentView.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: glass.contentView.trailingAnchor, constant: -12),
            content.topAnchor.constraint(equalTo: glass.contentView.topAnchor),
            content.bottomAnchor.constraint(equalTo: glass.contentView.bottomAnchor)
        ])
        return glass
    }
    override func viewWillDisappear(_ animated: Bool) { super.viewWillDisappear(animated); view.endEditing(true) }
    @objc private func editing() {
        submitted = nil
        if dictionary != nil { card.isHidden = true }
        check.isEnabled = dictionary != nil && !WordDictionary.normalize(field.text ?? "").isEmpty
    }
    @objc private func changeDictionary() {
        UserDefaults.standard.set(picker.selectedSegmentIndex, forKey: "lexicon")
        picker.accessibilityValue = lexicon.detail
        if submitted != nil { submit() }
    }
    private func showResult(_ text: String, symbol: String, color: UIColor) {
        result.text = text
        result.textColor = color
        resultIcon.image = UIImage(systemName: symbol)
        resultIcon.tintColor = color
        card.isHidden = false
    }
    @objc private func submit() {
        guard let dictionary else { return }
        let word = WordDictionary.normalize(field.text ?? "")
        if let error = WordDictionary.inputError(field.text ?? "") {
            submitted = nil
            showResult(error, symbol: "exclamationmark.circle", color: .secondaryLabel)
        } else {
            submitted = word
            field.text = word
            let valid = dictionary.contains(word, in: lexicon)
            showResult(valid ? "Valid" : "Not valid", symbol: valid ? "checkmark.circle.fill" : "xmark.circle.fill", color: valid ? accent : .systemRed)
        }
        if field.isFirstResponder { field.selectAll(nil) }
        view.layoutIfNeeded()
        scroll.scrollRectToVisible(card.convert(card.bounds, to: scroll), animated: true)
        UIAccessibility.post(notification: .announcement, argument: "\(word). \(result.text ?? ""). \(lexicon.detail).")
    }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool { submit(); return false }
}

final class DocumentController: UIViewController {
    private let documentText: String
    init(title: String, text: String) {
        documentText = text
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let text = UITextView()
        text.text = documentText
        text.font = .preferredFont(forTextStyle: .body)
        text.adjustsFontForContentSizeCategory = true
        text.isEditable = false
        text.dataDetectorTypes = .link
        text.textContainerInset = UIEdgeInsets(top: 20, left: 16, bottom: 24, right: 16)
        text.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(text)
        NSLayoutConstraint.activate([
            text.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            text.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            text.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            text.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })
    }
}
