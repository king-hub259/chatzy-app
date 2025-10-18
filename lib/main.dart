import 'dart:developer';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get_storage/get_storage.dart';
import 'common/extension/tklmn.dart';
import 'common/languages/index.dart';
import 'config.dart';
import 'controllers/common_controllers/contact_controller.dart';
import 'controllers/common_controllers/firebase_common_controller.dart';
import 'controllers/common_controllers/notification_controller.dart';
import 'controllers/recent_chat_controller.dart';
import 'utils/general_utils.dart';

const encryptedKey = "MyCHATZY32lengthENCRYPTKEY132456";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await GetStorage.init();
  if (Platform.isAndroid) {
    await Firebase.initializeApp(
      name: "name "
        options: FirebaseOptions(
            apiKey: "Enter your firbase apikey",
            appId: "Enter your firbase appId  ",
            storageBucket: "Enter your Firbase storageBucket ",
            messagingSenderId: "Enter your firbase messagingSenderId",
            projectId: "Enter your firbase projectId"));
  } else {
    await Firebase.initializeApp(
        options: FirebaseOptions(
            apiKey: "Enter your firbase apikey",
            appId: "Enter your firbase appId  ",
            storageBucket: "Enter your Firbase storageBucket ",
            messagingSenderId: "Enter your firbase messagingSenderId",
            projectId: "Enter your firbase projectId"));
  }

  cameras = await availableCameras();
  // Get.put(LoadingController());
  // Set the background messaging handler early on, as a named top-level function
  Get.put(AppController());
  Get.put(FirebaseCommonController());
  Get.put(CustomNotificationController());
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarIconBrightness: Brightness.dark,
      statusBarColor: appCtrl.appTheme.trans));
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    // TODO: implement initState
    final noti = Get.find<CustomNotificationController>();
    noti.initNotification();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    lockScreenPortrait();
    return FutureBuilder(
        future: SharedPreferences.getInstance(),
        builder: (context, AsyncSnapshot<SharedPreferences> snapData) {
          if (snapData.hasData) {
            return MultiProvider(
              providers: [
                ChangeNotifierProvider(create: (_) => RecentChatController()),
                ChangeNotifierProvider(create: (_) => ContactProvider()),
              ],
              child: GetMaterialApp(
                builder: (context, widget) {
                  print(
                      "object-=-=-=-=-=-=-=1212:::${Locale('${appCtrl.storage.read(session.locale)}', '${appCtrl.storage.read(session.countryCode)}')}");
                  return MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: const TextScaler.linear(1.0)),
                    child: widget!,
                  );
                },
                debugShowCheckedModeBanner: false,
                translations: Language(),
                locale: /* const Locale('en',
                    'US')  */ /* Locale(appCtrl.locale) */
                    Locale('${appCtrl.storage.read(session.locale)}',
                        '${appCtrl.storage.read(session.countryCode)}'),
                // fallbackLocale: const Locale('en', 'US'),
                title: appFonts.chatzy.tr,
                home: CallFunc(prefs: snapData.data), 
                getPages: appRoute.getPages,
                theme: AppTheme.fromType(ThemeType.light).themeData,
                darkTheme: AppTheme.fromType(ThemeType.dark).themeData,
                themeMode: ThemeService().theme,
              ),
            );
          } else {
            log("NO DATA ");
            return MultiProvider(
              providers: [
                ChangeNotifierProvider(create: (_) => RecentChatController()),
                ChangeNotifierProvider(create: (_) => ContactProvider()),
              ],
              child: MaterialApp(
                  theme: AppTheme.fromType(ThemeType.light).themeData,
                  debugShowCheckedModeBanner: false,
                  home: Scaffold(
                      backgroundColor: appCtrl.appTheme.primary,
                      body: Stack(alignment: Alignment.center, children: [
                        SizedBox(
                            height: MediaQuery.of(context).size.height,
                            width: MediaQuery.of(context).size.width,
                            child: Image.asset(eImageAssets.splash,
                                fit: BoxFit.fill)),
                        Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Image.asset(eImageAssets.appLogo,
                                  height: 100, width: 100),
                              const VSpace(Sizes.s20),
                              Text(appFonts.chatzy.tr,
                                  style: AppCss.muktaVaani40
                                      .textColor(appCtrl.appTheme.sameWhite))
                            ])
                      ]))),
            );
          }
        });
  }

  lockScreenPortrait() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  if (Platform.isAndroid) {
    await Firebase.initializeApp(
    options: FirebaseOptions(
        apiKey: "Enter your firbase apikey",
        appId: "Enter your firbase appId  ",
        storageBucket: "Enter your Firbase storageBucket ",
        messagingSenderId: "Enter your firbase messagingSenderId",
        projectId: "Enter your firbase projectId"));
  } else {
    await Firebase.initializeApp(
    options: FirebaseOptions(
    apiKey: "Enter your firbase apikey",
  appId: "Enter your firbase appId  ",
  storageBucket: "Enter your Firbase storageBucket ",
  messagingSenderId: "Enter your firbase messagingSenderId",
  projectId: "Enter your firbase projectId"));
  }
  AndroidNotificationChannel channel = AndroidNotificationChannel(
    'Astrologically Partner local notifications',
    'High Importance Notifications for Astrologically',
    description: 'This channel is used for important notifications.',
    playSound: true,
    importance: Importance.high,
    sound: (message.data['title'] != 'Incoming Audio Call...' ||
            message.data['title'] != 'Incoming Video Call...')
        ? RawResourceAndroidNotificationSound('message')
        : RawResourceAndroidNotificationSound('callsound'),
  );
  final notifications = CustomNotificationController();
  await notifications.initNotification();
  notifications.showNotification(message);
}
