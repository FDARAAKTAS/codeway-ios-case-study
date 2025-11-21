import SwiftUI
import Photos

@main
struct PhotoscannerApp: App {

    var body: some Scene {
        WindowGroup {
            NavigationViewControllerWrapper()
                .ignoresSafeArea()
        }
    }
}

struct NavigationViewControllerWrapper: UIViewControllerRepresentable {
    
    func makeUIViewController(context: Context) -> UINavigationController {
        let home = HomeViewController()
        let nav = UINavigationController(rootViewController: home)
        nav.navigationBar.prefersLargeTitles = true
        nav.view.backgroundColor = .systemBackground
        return nav
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
}
