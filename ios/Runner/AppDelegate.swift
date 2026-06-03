import Flutter
import UIKit
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // workmanager_apple exige que cada task identifier seja registrado
    // ANTES do Flutter engine subir. Os identifiers aqui têm que bater
    // com BGTaskSchedulerPermittedIdentifiers no Info.plist e com os
    // nomes passados em registerOneOffTask/registerPeriodicTask no Dart.
    // Sem isso, o iOS crasha no launch quando o app tenta agendar uma
    // BGTask com identifier não registrado (causa do crash do reviewer).
    WorkmanagerPlugin.registerTask(withIdentifier: "wizmart_bg_sync")
    WorkmanagerPlugin.registerBGProcessingTask(withIdentifier: "be.tramckrijte.workmanager.iOSBackgroundProcessingTask")
    WorkmanagerPlugin.registerPeriodicTask(withIdentifier: "be.tramckrijte.workmanager.iOSBackgroundAppRefresh", frequency: NSNumber(value: 15 * 60))

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
