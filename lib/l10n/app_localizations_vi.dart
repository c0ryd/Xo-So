// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'Quét Xổ Số Việt Nam';

  @override
  String get scanTicket => 'Quét vé số';

  @override
  String get currentResults => 'KẾT QUẢ HIỆN TẠI';

  @override
  String get pendingResults => 'Đang Chờ Kết Quả';

  @override
  String get winnerCheckFailed => 'Kiểm Tra Trúng Thưởng Thất Bại';

  @override
  String get processingImage => 'Đang xử lý hình ảnh...';

  @override
  String get ticketDetails => 'Chi Tiết Vé Số';

  @override
  String get province => 'Tỉnh/Thành';

  @override
  String get ticketNumber => 'Số Vé';

  @override
  String get drawDate => 'Ngày Xổ';

  @override
  String get region => 'Vùng';

  @override
  String get congratulations => '🎉 Chúc Mừng! 🎉';

  @override
  String youWon(String amount) {
    return 'Bạn đã trúng $amount VND!';
  }

  @override
  String matchedTiers(String tiers) {
    return 'Giải Trúng: $tiers';
  }

  @override
  String get notAWinner => 'Chưa trúng lần này';

  @override
  String get betterLuckNextTime => 'Chúc may mắn lần sau! Hãy tiếp tục chơi!';

  @override
  String resultsNotAvailable(String province) {
    return 'Kết quả xổ số $province chưa có. Bạn sẽ được thông báo khi có kết quả.';
  }

  @override
  String get drawingNotOccurred =>
      'Kỳ xổ này chưa diễn ra, bạn sẽ nhận được thông báo sau khi có kết quả xổ số.';

  @override
  String get errorOccurred => 'Đã xảy ra lỗi. Vui lòng thử lại.';

  @override
  String get cameraPermissionRequired =>
      'Cần quyền truy cập camera để quét vé số';

  @override
  String get logout => 'Đăng Xuất';

  @override
  String get saveImagesLocally => 'Lưu Ảnh Cục Bộ';

  @override
  String get imageStorageEnabled => 'Đã bật lưu trữ ảnh';

  @override
  String get imageStorageDisabled => 'Đã tắt lưu trữ ảnh';

  @override
  String get scanTips => 'Mẹo Quét';

  @override
  String get goodLighting => 'Ánh sáng tốt';

  @override
  String get goodLightingTip => 'Tránh bóng và ánh sáng chói trên vé';

  @override
  String get keepSteady => 'Giữ máy ảnh ổn định';

  @override
  String get keepSteadyTip => 'Giữ điện thoại thật ổn để có chữ rõ nét';

  @override
  String get fillFrame => 'Lấp đầy khung hình';

  @override
  String get fillFrameTip => 'Đặt vé trong khung xanh';

  @override
  String get keepFlat => 'Giữ vé phẳng';

  @override
  String get keepFlatTip => 'Làm phẳng các nếp gấp và đường gấp';

  @override
  String get gotIt => 'Hiểu rồi!';

  @override
  String get settings => 'Cài Đặt';

  @override
  String get language => 'Ngôn Ngữ';

  @override
  String get english => 'Tiếng Anh';

  @override
  String get vietnamese => 'Tiếng Việt';

  @override
  String get todaysDrawings => 'Kết Quả';

  @override
  String get drawingResults => 'Kết Quả Xổ Số';

  @override
  String get comingSoon => 'Sắp Ra Mắt!';

  @override
  String get ticketStored => 'Đã lưu vé số thành công';

  @override
  String get failedToStore => 'Lưu vé số thất bại. Vui lòng thử lại.';

  @override
  String get scanAnother => 'Quét Vé Khác';

  @override
  String get forgotPassword => 'Quên Mật Khẩu?';

  @override
  String get resetPassword => 'Đặt Lại Mật Khẩu';

  @override
  String get enterEmailToReset =>
      'Nhập địa chỉ email của bạn và chúng tôi sẽ gửi liên kết đặt lại mật khẩu.';

  @override
  String get sendResetLink => 'Gửi Liên Kết Đặt Lại';

  @override
  String get resetLinkSent =>
      'Đã gửi liên kết đặt lại mật khẩu! Kiểm tra email của bạn.';

  @override
  String get backToSignIn => 'Quay Lại Đăng Nhập';

  @override
  String get emailRequired => 'Email là bắt buộc';

  @override
  String get signIn => 'Đăng Nhập';

  @override
  String get signUp => 'Đăng Ký';

  @override
  String get createAccount => 'Tạo Tài Khoản';

  @override
  String get emailPhone => 'Email/Điện Thoại';

  @override
  String get phone => 'Điện Thoại (+84123456789)';

  @override
  String get password => 'Mật Khẩu';

  @override
  String get enterOtp => 'Nhập Mã OTP';

  @override
  String get sendOtp => 'Gửi OTP';

  @override
  String get verifySignUp => 'Xác Minh & Đăng Ký';

  @override
  String get verifySignIn => 'Xác Minh & Đăng Nhập';

  @override
  String get back => '← Quay Lại';

  @override
  String get resendOtp => 'Gửi Lại OTP';

  @override
  String get alreadyHaveAccount => 'Đã có tài khoản?';

  @override
  String get dontHaveAccount => 'Chưa có tài khoản?';

  @override
  String get orContinueWith => 'hoặc tiếp tục với';

  @override
  String get continueWithApple => 'Tiếp Tục Với Apple';

  @override
  String get continueWithGoogle => 'Tiếp Tục Với Google';

  @override
  String get signingIn => 'Đang đăng nhập...';

  @override
  String get pleaseEnterEmailPassword => 'Vui lòng nhập email và mật khẩu';

  @override
  String get passwordMinLength => 'Mật khẩu phải có ít nhất 6 ký tự';

  @override
  String get pleaseEnterPhoneNumber => 'Vui lòng nhập số điện thoại';

  @override
  String get invalidPhoneNumber =>
      'Vui lòng nhập số điện thoại hợp lệ (bao gồm mã quốc gia như +84123456789)';

  @override
  String get pleaseEnterOtp => 'Vui lòng nhập mã xác minh';

  @override
  String get signInFailed => 'Đăng nhập thất bại';

  @override
  String get signUpFailed => 'Đăng ký thất bại';

  @override
  String get myTickets => 'Vé Số Của Tôi';

  @override
  String get scanTicketButton => 'Quét Vé Số';

  @override
  String get autoScanning => 'Đang Tự Động Quét...';

  @override
  String get found => 'Tìm Thấy';

  @override
  String get stopScanning => 'Dừng Quét';

  @override
  String get scanResults => 'Kết Quả Quét';

  @override
  String get city => 'Thành Phố';

  @override
  String get date => 'Ngày';

  @override
  String get quantity => 'Số Lượng';

  @override
  String get done => 'Hoàn Thành';

  @override
  String get amazing => 'Tuyệt Vời!';

  @override
  String get checkingWinner => 'Đang kiểm tra trúng thưởng...';

  @override
  String get notFound => 'Không tìm thấy';

  @override
  String get todaysDrawingsTitle => 'Kết Quả Hôm Nay';

  @override
  String get provincesWithDrawings => 'Tỉnh có xổ số';

  @override
  String get noDrawingsScheduled =>
      'Không có xổ số nào được lên lịch cho ngày này';

  @override
  String get lotteryResults => 'Kết Quả Xổ Số';

  @override
  String get drawingScheduled => 'Đã Lên Lịch Xổ';

  @override
  String get resultsNotAvailableYet => 'Chưa Có Kết Quả';

  @override
  String get loading => 'Đang tải...';

  @override
  String get myTicketsTitle => 'Vé Số Của Tôi';

  @override
  String get totalWinnings => 'Tổng Tiền Thắng';

  @override
  String get pending => 'Đang Chờ';

  @override
  String get email => 'Email';

  @override
  String get specialPrize => 'Giải Đặc Biệt';

  @override
  String get firstPrize => 'Giải Nhất';

  @override
  String get secondPrize => 'Giải Nhì';

  @override
  String get thirdPrize => 'Giải Ba';

  @override
  String get fourthPrize => 'Giải Tư';

  @override
  String get fifthPrize => 'Giải Năm';

  @override
  String get sixthPrize => 'Giải Sáu';

  @override
  String get seventhPrize => 'Giải Bảy';

  @override
  String get eighthPrize => 'Giải Tám';

  @override
  String get drawingNotComplete => 'Xổ số chưa hoàn thành';

  @override
  String get drawingResultsAvailable => 'Kết quả xổ số sẽ có vào ngày này';

  @override
  String get noDrawingResults =>
      'Không tìm thấy kết quả xổ số cho ngày và tỉnh này';

  @override
  String get noResultsAvailable => 'Không có kết quả';

  @override
  String get noResultsForDate => 'Không có kết quả cho ngày này';

  @override
  String get ticket => 'vé';

  @override
  String get tickets => 'vé';

  @override
  String get winner => 'Trúng Thưởng!';

  @override
  String get notWinner => 'Không Trúng Thưởng';

  @override
  String get resultsPending => 'Kết Quả Đang Chờ';

  @override
  String get scanComplete => 'Quét Hoàn Thành!';
}
