import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:camera/camera.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:app_links/app_links.dart';
import 'config/app_config.dart';
import 'services/supabase_auth_service.dart';
import 'services/notification_service.dart';
import 'services/image_storage_service.dart';
import 'services/ad_service.dart';
import 'services/language_service.dart';
import 'screens/home_screen.dart';
import 'screens/supabase_login_screen.dart';
import 'screens/todays_drawings_screen.dart';
import 'screens/user_tickets_summary_screen.dart';
import 'screens/debug_screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

late List<CameraDescription> cameras;

// Global navigator key for navigation from notifications
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Lock orientation to portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Initialize Supabase with environment-specific configuration
  // Print configuration on startup
  print('🚀 STARTING XO SO APP');
  AppConfig.printCurrentConfig();
  
  await SupabaseAuthService.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
  
  // Supabase initialized with current configuration
  
  // Initialize deep link handling for OAuth callbacks
  _initializeDeepLinkHandling();
  
  // Initialize services
  await NotificationService.initialize();
  await AdService.initialize();
  await ImageStorageService.initialize();
  
  cameras = await availableCameras();
  runApp(
    ChangeNotifierProvider(
      create: (context) => LanguageService(),
      child: MyApp(),
    ),
  );
}

// Initialize deep link handling for OAuth callbacks
void _initializeDeepLinkHandling() {
  final AppLinks appLinks = AppLinks();
  
  // Listen for incoming deep links when app is already running
  appLinks.uriLinkStream.listen((Uri uri) {
    print('🔗 Received deep link: $uri');
    if (uri.scheme == 'com.cdawson.xoso' && uri.host == 'login-callback') {
      print('🔑 OAuth callback received - Supabase will handle authentication');
      // Supabase SDK will automatically handle the OAuth callback
    }
  }, onError: (Object err) {
    print('❌ Deep link error: $err');
  });
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageService>(
      builder: (context, languageService, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Vietnamese Lottery OCR',
          theme: ThemeData(
            primarySwatch: Colors.blue,
            scaffoldBackgroundColor: Colors.transparent,
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF91000C), // Vietnamese red color
              foregroundColor: Color(0xFFFFE8BE), // Light cream text
              titleTextStyle: TextStyle(
                color: Color(0xFFFFE8BE),
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
              iconTheme: IconThemeData(
                color: Color(0xFFFFE8BE),
              ),
              systemOverlayStyle: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light,
                statusBarBrightness: Brightness.dark,
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF91000C),
                foregroundColor: Color(0xFFFFE8BE),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            cardTheme: CardTheme(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          locale: languageService.currentLocale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'), // English
            Locale('vi'), // Vietnamese
          ],
          home: AuthWrapper(),
          routes: {
            '/results': (context) => const TodaysDrawingsScreen(),
            '/my-tickets': (context) => const UserTicketsSummaryScreen(),
            '/debug': (context) => const DebugScreen(),
          },
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  final SupabaseAuthService _authService = SupabaseAuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        if (snapshot.hasData && snapshot.data?.session != null) {
          // User is signed in, show main app
          return HomeScreen();
        } else {
          // User is not signed in, show login screen
          return SupabaseLoginScreen();
        }
      },
    );
  }
}
