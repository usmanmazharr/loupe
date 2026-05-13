import UIKit
import SwiftUI
import Combine

/// UIKit bridge – wraps `LoupeView` in a `UIViewController` for UIKit hosts.
public final class LoupeViewController: UIViewController {

    private var hostingController: UIHostingController<AnyView>?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Presentation

    @discardableResult
    public static func present(from viewController: UIViewController? = nil) -> LoupeViewController {
        let logger = LoupeViewController()
        logger.modalPresentationStyle = .fullScreen
        let presenter = viewController ?? UIApplication.shared.topViewController
        presenter?.present(logger, animated: true)
        return logger
    }

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()

        // Set initial UIKit style so adaptive UIColors resolve correctly from the start.
        self.overrideUserInterfaceStyle = LoupeThemeManager.shared.uiStyle

        // When the in-app toggle fires, update the UIKit trait environment on this VC.
        // This makes Color(uiColor: .systemBackground) etc. adapt correctly.
        LoupeThemeManager.shared.$uiStyle
            .receive(on: DispatchQueue.main)
            .sink { [weak self] style in
                UIView.animate(withDuration: 0.25) {
                    self?.overrideUserInterfaceStyle = style
                }
            }
            .store(in: &cancellables)

        let isPresented = Binding<Bool>(
            get: { [weak self] in self?.presentingViewController != nil },
            set: { [weak self] newValue in
                guard let self, !newValue else { return }
                self.dismiss(animated: true)
            }
        )

        let rootView = LoupeView(isPresented: isPresented)
        let host = UIHostingController(rootView: AnyView(rootView))
        hostingController = host

        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
    }
}
