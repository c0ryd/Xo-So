import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi')
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'Vietnamese Lottery OCR'**
  String get appTitle;

  /// Button text to start scanning a lottery ticket
  ///
  /// In en, this message translates to:
  /// **'Scan a ticket'**
  String get scanTicket;

  /// Header for current lottery results section
  ///
  /// In en, this message translates to:
  /// **'CURRENT RESULTS'**
  String get currentResults;

  /// Title when results are not available yet
  ///
  /// In en, this message translates to:
  /// **'Pending Results'**
  String get pendingResults;

  /// Title when winner check fails
  ///
  /// In en, this message translates to:
  /// **'Winner Check Failed'**
  String get winnerCheckFailed;

  /// Message shown while processing the scanned image
  ///
  /// In en, this message translates to:
  /// **'Processing image...'**
  String get processingImage;

  /// Header for ticket details section
  ///
  /// In en, this message translates to:
  /// **'Ticket Details'**
  String get ticketDetails;

  /// Label for province field
  ///
  /// In en, this message translates to:
  /// **'Province'**
  String get province;

  /// Label for ticket number field
  ///
  /// In en, this message translates to:
  /// **'Ticket Number'**
  String get ticketNumber;

  /// Label for draw date field
  ///
  /// In en, this message translates to:
  /// **'Draw Date'**
  String get drawDate;

  /// Label for region field
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get region;

  /// Congratulations message for winners
  ///
  /// In en, this message translates to:
  /// **'🎉 Congratulations! 🎉'**
  String get congratulations;

  /// Message showing winnings amount
  ///
  /// In en, this message translates to:
  /// **'You won {amount} VND!'**
  String youWon(String amount);

  /// Shows which prize tiers were matched
  ///
  /// In en, this message translates to:
  /// **'Matched Tiers: {tiers}'**
  String matchedTiers(String tiers);

  /// Message when ticket is not a winner
  ///
  /// In en, this message translates to:
  /// **'Not a winner this time'**
  String get notAWinner;

  /// Encouraging message for non-winners
  ///
  /// In en, this message translates to:
  /// **'Better luck next time! Keep playing!'**
  String get betterLuckNextTime;

  /// Message when lottery results are not yet available
  ///
  /// In en, this message translates to:
  /// **'Results for {province} are not available yet. You will be notified when results are available.'**
  String resultsNotAvailable(String province);

  /// Message when drawing hasn't happened yet
  ///
  /// In en, this message translates to:
  /// **'This drawing has not occurred yet, you will receive a notification after the drawing has occurred.'**
  String get drawingNotOccurred;

  /// Generic error message
  ///
  /// In en, this message translates to:
  /// **'An error occurred. Please try again.'**
  String get errorOccurred;

  /// Message when camera permission is needed
  ///
  /// In en, this message translates to:
  /// **'Camera permission is required to scan tickets'**
  String get cameraPermissionRequired;

  /// Logout button text
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// Setting to enable/disable local image storage
  ///
  /// In en, this message translates to:
  /// **'Save Images Locally'**
  String get saveImagesLocally;

  /// Message when image storage is turned on
  ///
  /// In en, this message translates to:
  /// **'Image storage enabled'**
  String get imageStorageEnabled;

  /// Message when image storage is turned off
  ///
  /// In en, this message translates to:
  /// **'Image storage disabled'**
  String get imageStorageDisabled;

  /// No description provided for @scanTips.
  ///
  /// In en, this message translates to:
  /// **'Scan Tips'**
  String get scanTips;

  /// No description provided for @goodLighting.
  ///
  /// In en, this message translates to:
  /// **'Good lighting'**
  String get goodLighting;

  /// No description provided for @goodLightingTip.
  ///
  /// In en, this message translates to:
  /// **'Avoid shadows and glare on the ticket'**
  String get goodLightingTip;

  /// No description provided for @keepSteady.
  ///
  /// In en, this message translates to:
  /// **'Keep camera steady'**
  String get keepSteady;

  /// No description provided for @keepSteadyTip.
  ///
  /// In en, this message translates to:
  /// **'Hold your phone stable for sharp text'**
  String get keepSteadyTip;

  /// No description provided for @fillFrame.
  ///
  /// In en, this message translates to:
  /// **'Fill the frame'**
  String get fillFrame;

  /// No description provided for @fillFrameTip.
  ///
  /// In en, this message translates to:
  /// **'Position ticket within the green frame'**
  String get fillFrameTip;

  /// No description provided for @keepFlat.
  ///
  /// In en, this message translates to:
  /// **'Keep ticket flat'**
  String get keepFlat;

  /// No description provided for @keepFlatTip.
  ///
  /// In en, this message translates to:
  /// **'Smooth out wrinkles and fold lines'**
  String get keepFlatTip;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it!'**
  String get gotIt;

  /// Settings menu item
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Language setting label
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// English language option
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// Vietnamese language option
  ///
  /// In en, this message translates to:
  /// **'Vietnamese'**
  String get vietnamese;

  /// Menu item for drawing results
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get todaysDrawings;

  /// Menu item for drawing results
  ///
  /// In en, this message translates to:
  /// **'Drawing Results'**
  String get drawingResults;

  /// Message for features not yet implemented
  ///
  /// In en, this message translates to:
  /// **'Coming Soon!'**
  String get comingSoon;

  /// Success message when ticket is stored
  ///
  /// In en, this message translates to:
  /// **'Ticket stored successfully'**
  String get ticketStored;

  /// Error message when ticket storage fails
  ///
  /// In en, this message translates to:
  /// **'Failed to store ticket. Please try again.'**
  String get failedToStore;

  /// Button to scan another ticket
  ///
  /// In en, this message translates to:
  /// **'Scan Another'**
  String get scanAnother;

  /// Link to reset password
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// Reset password button text
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get resetPassword;

  /// Instructions for password reset
  ///
  /// In en, this message translates to:
  /// **'Enter your email address and we\'ll send you a link to reset your password.'**
  String get enterEmailToReset;

  /// Button to send password reset email
  ///
  /// In en, this message translates to:
  /// **'Send Reset Link'**
  String get sendResetLink;

  /// Success message after sending reset link
  ///
  /// In en, this message translates to:
  /// **'Password reset link sent! Check your email.'**
  String get resetLinkSent;

  /// Link to return to sign in screen
  ///
  /// In en, this message translates to:
  /// **'Back to Sign In'**
  String get backToSignIn;

  /// Error when email field is empty
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get emailRequired;

  /// Sign in button text
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// Sign up button text
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// Create account button text
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// Email or phone input field hint
  ///
  /// In en, this message translates to:
  /// **'Email/Phone'**
  String get emailPhone;

  /// Phone input field hint
  ///
  /// In en, this message translates to:
  /// **'Phone (+1234567890)'**
  String get phone;

  /// Password input field hint
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// OTP input field hint
  ///
  /// In en, this message translates to:
  /// **'Enter OTP'**
  String get enterOtp;

  /// Send OTP button text
  ///
  /// In en, this message translates to:
  /// **'Send OTP'**
  String get sendOtp;

  /// Verify OTP and sign up button text
  ///
  /// In en, this message translates to:
  /// **'Verify & Sign Up'**
  String get verifySignUp;

  /// Verify OTP and sign in button text
  ///
  /// In en, this message translates to:
  /// **'Verify & Sign In'**
  String get verifySignIn;

  /// Back button text
  ///
  /// In en, this message translates to:
  /// **'← Back'**
  String get back;

  /// Resend OTP button text
  ///
  /// In en, this message translates to:
  /// **'Resend OTP'**
  String get resendOtp;

  /// Text asking if user already has an account
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// Text asking if user doesn't have an account
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get dontHaveAccount;

  /// Text between login methods
  ///
  /// In en, this message translates to:
  /// **'or continue with'**
  String get orContinueWith;

  /// Apple sign in button text
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get continueWithApple;

  /// Google sign in button text
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// Loading text during sign in
  ///
  /// In en, this message translates to:
  /// **'Signing in...'**
  String get signingIn;

  /// Error when email or password is missing
  ///
  /// In en, this message translates to:
  /// **'Please enter both email and password'**
  String get pleaseEnterEmailPassword;

  /// Error when password is too short
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordMinLength;

  /// Error when phone number is missing
  ///
  /// In en, this message translates to:
  /// **'Please enter a phone number'**
  String get pleaseEnterPhoneNumber;

  /// Error when phone number format is invalid
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid phone number (include country code like +1234567890)'**
  String get invalidPhoneNumber;

  /// Error when OTP is missing
  ///
  /// In en, this message translates to:
  /// **'Please enter the verification code'**
  String get pleaseEnterOtp;

  /// Generic sign in failure message
  ///
  /// In en, this message translates to:
  /// **'Sign in failed'**
  String get signInFailed;

  /// Generic sign up failure message
  ///
  /// In en, this message translates to:
  /// **'Sign up failed'**
  String get signUpFailed;

  /// Menu item for user's tickets
  ///
  /// In en, this message translates to:
  /// **'My Tickets'**
  String get myTickets;

  /// Camera page scan button text
  ///
  /// In en, this message translates to:
  /// **'Scan Ticket'**
  String get scanTicketButton;

  /// Auto-scanning status text
  ///
  /// In en, this message translates to:
  /// **'Auto-Scanning...'**
  String get autoScanning;

  /// Found items count prefix
  ///
  /// In en, this message translates to:
  /// **'Found'**
  String get found;

  /// Stop auto-scanning button
  ///
  /// In en, this message translates to:
  /// **'Stop Scanning'**
  String get stopScanning;

  /// Scan results popup title
  ///
  /// In en, this message translates to:
  /// **'Scan Results'**
  String get scanResults;

  /// City field label
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// Date field label
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// Quantity field label
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// Done button text
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// Winner popup button text
  ///
  /// In en, this message translates to:
  /// **'Amazing!'**
  String get amazing;

  /// Checking winner status text
  ///
  /// In en, this message translates to:
  /// **'Checking for winner...'**
  String get checkingWinner;

  /// Field not found text
  ///
  /// In en, this message translates to:
  /// **'Not found'**
  String get notFound;

  /// Today's drawings page title
  ///
  /// In en, this message translates to:
  /// **'Today\'s Drawings'**
  String get todaysDrawingsTitle;

  /// Provinces section title
  ///
  /// In en, this message translates to:
  /// **'Provinces with drawings'**
  String get provincesWithDrawings;

  /// No drawings message
  ///
  /// In en, this message translates to:
  /// **'No drawings scheduled for this date'**
  String get noDrawingsScheduled;

  /// Lottery results page title
  ///
  /// In en, this message translates to:
  /// **'Lottery Results'**
  String get lotteryResults;

  /// Drawing scheduled status
  ///
  /// In en, this message translates to:
  /// **'Drawing Scheduled'**
  String get drawingScheduled;

  /// Results not available status
  ///
  /// In en, this message translates to:
  /// **'Results Not Available'**
  String get resultsNotAvailableYet;

  /// Loading text
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// My tickets page title
  ///
  /// In en, this message translates to:
  /// **'My Tickets'**
  String get myTicketsTitle;

  /// Total winnings label
  ///
  /// In en, this message translates to:
  /// **'Total Winnings'**
  String get totalWinnings;

  /// Pending status text
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// Email field label
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// Special prize tier
  ///
  /// In en, this message translates to:
  /// **'Special Prize'**
  String get specialPrize;

  /// First prize tier
  ///
  /// In en, this message translates to:
  /// **'First Prize'**
  String get firstPrize;

  /// Second prize tier
  ///
  /// In en, this message translates to:
  /// **'Second Prize'**
  String get secondPrize;

  /// Third prize tier
  ///
  /// In en, this message translates to:
  /// **'Third Prize'**
  String get thirdPrize;

  /// Fourth prize tier
  ///
  /// In en, this message translates to:
  /// **'Fourth Prize'**
  String get fourthPrize;

  /// Fifth prize tier
  ///
  /// In en, this message translates to:
  /// **'Fifth Prize'**
  String get fifthPrize;

  /// Sixth prize tier
  ///
  /// In en, this message translates to:
  /// **'Sixth Prize'**
  String get sixthPrize;

  /// Seventh prize tier
  ///
  /// In en, this message translates to:
  /// **'Seventh Prize'**
  String get seventhPrize;

  /// Eighth prize tier
  ///
  /// In en, this message translates to:
  /// **'Eighth Prize'**
  String get eighthPrize;

  /// Message when drawing hasn't finished yet
  ///
  /// In en, this message translates to:
  /// **'Drawing not yet complete'**
  String get drawingNotComplete;

  /// Message for future drawing dates
  ///
  /// In en, this message translates to:
  /// **'Drawing results will be available on this date'**
  String get drawingResultsAvailable;

  /// Message when no results found for date and province
  ///
  /// In en, this message translates to:
  /// **'No drawing results found for this date and province'**
  String get noDrawingResults;

  /// Generic no results message
  ///
  /// In en, this message translates to:
  /// **'No results available'**
  String get noResultsAvailable;

  /// Message when no results for specific date
  ///
  /// In en, this message translates to:
  /// **'No results available for this date'**
  String get noResultsForDate;

  /// Singular form of ticket
  ///
  /// In en, this message translates to:
  /// **'ticket'**
  String get ticket;

  /// Plural form of tickets
  ///
  /// In en, this message translates to:
  /// **'tickets'**
  String get tickets;

  /// Header text when ticket is a winner
  ///
  /// In en, this message translates to:
  /// **'Winner!'**
  String get winner;

  /// Header text when ticket is not a winner
  ///
  /// In en, this message translates to:
  /// **'Not a Winner'**
  String get notWinner;

  /// Header text when lottery results are not yet available
  ///
  /// In en, this message translates to:
  /// **'Results Pending'**
  String get resultsPending;

  /// Header text when scan is complete but winner status unknown
  ///
  /// In en, this message translates to:
  /// **'Scan Complete!'**
  String get scanComplete;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
