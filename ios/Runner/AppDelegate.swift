import Flutter
import UIKit
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // BGTask identifier do nosso periodic sync (mesmo nome passado em
    // Workmanager().registerPeriodicTask no main.dart). Tem que ser
    // registrado AQUI, antes do Flutter engine subir — senão iOS
    // crasha quando a chamada Dart tenta agendar pela primeira vez.
    WorkmanagerPlugin.registerPeriodicTask(withIdentifier: "wizmart_bg_sync", frequency: nil)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
