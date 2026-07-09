import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:queuenova_mobile/config/app_colors.dart';
import 'package:queuenova_mobile/firebase_options.dart';
import 'package:queuenova_mobile/screens/splash_screen.dart';
import 'package:queuenova_mobile/services/auth_service.dart';
import 'package:queuenova_mobile/services/push_notification_service.dart';
import 'package:queuenova_mobile/providers/language_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await EasyLocalization.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Initialize Stripe (not supported on web)
  if (!kIsWeb) {
    Stripe.publishableKey = 'pk_test_51TnKGlAknvzRSizhAKBtQQYHFJqKi8PeUikwWxOLsCuLHOdRYtYOyhi50eXd2f4tKs85tyat03mR4URDYTAjmCHA00yPYVww2F';
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('si'), Locale('ta')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      startLocale: const Locale('en'),
      child: const QueueNovaApp(),
    ),
  );
}

class QueueNovaApp extends StatelessWidget {
  const QueueNovaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: MaterialApp(
        title: 'app_name'.tr(),
        debugShowCheckedModeBanner: false,
        theme: appTheme(),
        home: const SplashScreen(),
        locale: context.locale,
        supportedLocales: context.supportedLocales,
        localizationsDelegates: context.localizationDelegates,
      ),
    );
  }
}
