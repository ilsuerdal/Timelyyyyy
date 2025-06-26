import UIKit
import Firebase


class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Firebase konfigürasyonu
        FirebaseApp.configure()
        
        return true
    }
}
