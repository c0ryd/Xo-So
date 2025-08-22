// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Vietnamese Lottery OCR';

  @override
  String get scanTicket => 'Scan a ticket';

  @override
  String get currentResults => 'CURRENT RESULTS';

  @override
  String get pendingResults => 'Pending Results';

  @override
  String get winnerCheckFailed => 'Winner Check Failed';

  @override
  String get processingImage => 'Processing image...';

  @override
  String get ticketDetails => 'Ticket Details';

  @override
  String get province => 'Province';

  @override
  String get ticketNumber => 'Ticket Number';

  @override
  String get drawDate => 'Draw Date';

  @override
  String get region => 'Region';

  @override
  String get congratulations => '🎉 Congratulations! 🎉';

  @override
  String youWon(String amount) {
    return 'You won $amount VND!';
  }

  @override
  String matchedTiers(String tiers) {
    return 'Matched Tiers: $tiers';
  }

  @override
  String get notAWinner => 'Not a winner this time';

  @override
  String get betterLuckNextTime => 'Better luck next time! Keep playing!';

  @override
  String resultsNotAvailable(String province) {
    return 'Results for $province are not available yet. You will be notified when results are available.';
  }

  @override
  String get drawingNotOccurred =>
      'This drawing has not occurred yet, you will receive a notification after the drawing has occurred.';

  @override
  String get errorOccurred => 'An error occurred. Please try again.';

  @override
  String get cameraPermissionRequired =>
      'Camera permission is required to scan tickets';

  @override
  String get logout => 'Logout';

  @override
  String get saveImagesLocally => 'Save Images Locally';

  @override
  String get imageStorageEnabled => 'Image storage enabled';

  @override
  String get imageStorageDisabled => 'Image storage disabled';

  @override
  String get scanTips => 'Scan Tips';

  @override
  String get goodLighting => 'Good lighting';

  @override
  String get goodLightingTip => 'Avoid shadows and glare on the ticket';

  @override
  String get keepSteady => 'Keep camera steady';

  @override
  String get keepSteadyTip => 'Hold your phone stable for sharp text';

  @override
  String get fillFrame => 'Fill the frame';

  @override
  String get fillFrameTip => 'Position ticket within the green frame';

  @override
  String get keepFlat => 'Keep ticket flat';

  @override
  String get keepFlatTip => 'Smooth out wrinkles and fold lines';

  @override
  String get gotIt => 'Got it!';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get vietnamese => 'Vietnamese';

  @override
  String get todaysDrawings => 'Results';

  @override
  String get drawingResults => 'Drawing Results';

  @override
  String get comingSoon => 'Coming Soon!';

  @override
  String get ticketStored => 'Ticket stored successfully';

  @override
  String get failedToStore => 'Failed to store ticket. Please try again.';

  @override
  String get scanAnother => 'Scan Another';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get resetPassword => 'Reset Password';

  @override
  String get enterEmailToReset =>
      'Enter your email address and we\'ll send you a link to reset your password.';

  @override
  String get sendResetLink => 'Send Reset Link';

  @override
  String get resetLinkSent => 'Password reset link sent! Check your email.';

  @override
  String get backToSignIn => 'Back to Sign In';

  @override
  String get emailRequired => 'Email is required';

  @override
  String get signIn => 'Sign In';

  @override
  String get signUp => 'Sign Up';

  @override
  String get createAccount => 'Create Account';

  @override
  String get emailPhone => 'Email/Phone';

  @override
  String get phone => 'Phone (+1234567890)';

  @override
  String get password => 'Password';

  @override
  String get enterOtp => 'Enter OTP';

  @override
  String get sendOtp => 'Send OTP';

  @override
  String get verifySignUp => 'Verify & Sign Up';

  @override
  String get verifySignIn => 'Verify & Sign In';

  @override
  String get back => '← Back';

  @override
  String get resendOtp => 'Resend OTP';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get dontHaveAccount => 'Don\'t have an account?';

  @override
  String get orContinueWith => 'or continue with';

  @override
  String get continueWithApple => 'Continue with Apple';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get signingIn => 'Signing in...';

  @override
  String get pleaseEnterEmailPassword => 'Please enter both email and password';

  @override
  String get passwordMinLength => 'Password must be at least 6 characters';

  @override
  String get pleaseEnterPhoneNumber => 'Please enter a phone number';

  @override
  String get invalidPhoneNumber =>
      'Please enter a valid phone number (include country code like +1234567890)';

  @override
  String get pleaseEnterOtp => 'Please enter the verification code';

  @override
  String get signInFailed => 'Sign in failed';

  @override
  String get signUpFailed => 'Sign up failed';

  @override
  String get myTickets => 'My Tickets';

  @override
  String get scanTicketButton => 'Scan Ticket';

  @override
  String get autoScanning => 'Auto-Scanning...';

  @override
  String get found => 'Found';

  @override
  String get stopScanning => 'Stop Scanning';

  @override
  String get scanResults => 'Scan Results';

  @override
  String get city => 'City';

  @override
  String get date => 'Date';

  @override
  String get quantity => 'Quantity';

  @override
  String get done => 'Done';

  @override
  String get amazing => 'Amazing!';

  @override
  String get checkingWinner => 'Checking for winner...';

  @override
  String get notFound => 'Not found';

  @override
  String get todaysDrawingsTitle => 'Today\'s Drawings';

  @override
  String get provincesWithDrawings => 'Provinces with drawings';

  @override
  String get noDrawingsScheduled => 'No drawings scheduled for this date';

  @override
  String get lotteryResults => 'Lottery Results';

  @override
  String get drawingScheduled => 'Drawing Scheduled';

  @override
  String get resultsNotAvailableYet => 'Results Not Available';

  @override
  String get loading => 'Loading...';

  @override
  String get myTicketsTitle => 'My Tickets';

  @override
  String get totalWinnings => 'Total Winnings';

  @override
  String get pending => 'Pending';

  @override
  String get email => 'Email';

  @override
  String get specialPrize => 'Special Prize';

  @override
  String get firstPrize => 'First Prize';

  @override
  String get secondPrize => 'Second Prize';

  @override
  String get thirdPrize => 'Third Prize';

  @override
  String get fourthPrize => 'Fourth Prize';

  @override
  String get fifthPrize => 'Fifth Prize';

  @override
  String get sixthPrize => 'Sixth Prize';

  @override
  String get seventhPrize => 'Seventh Prize';

  @override
  String get eighthPrize => 'Eighth Prize';

  @override
  String get drawingNotComplete => 'Drawing not yet complete';

  @override
  String get drawingResultsAvailable =>
      'Drawing results will be available on this date';

  @override
  String get noDrawingResults =>
      'No drawing results found for this date and province';

  @override
  String get noResultsAvailable => 'No results available';

  @override
  String get noResultsForDate => 'No results available for this date';

  @override
  String get ticket => 'ticket';

  @override
  String get tickets => 'tickets';

  @override
  String get winner => 'Winner!';

  @override
  String get notWinner => 'Not a Winner';

  @override
  String get resultsPending => 'Results Pending';

  @override
  String get scanComplete => 'Scan Complete!';
}
