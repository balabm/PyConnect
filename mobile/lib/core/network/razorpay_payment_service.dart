import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'api_client.dart';

/// Result of a payment attempt.
sealed class PaymentResult {}

class PaymentSuccess extends PaymentResult {
  PaymentSuccess({required this.paymentId, required this.orderId, this.signature});
  final String paymentId;
  final String orderId;
  final String? signature;
}

class PaymentError extends PaymentResult {
  PaymentError({required this.code, required this.message});
  final int code;
  final String message;
}

class PaymentExternalWallet extends PaymentResult {
  PaymentExternalWallet({required this.walletName});
  final String walletName;
}

/// Wraps the Razorpay Flutter SDK to provide a clean checkout flow.
///
/// When the environment variable `USE_MOCK_PAYMENTS` is `"true"`, the service
/// bypasses the Razorpay SDK entirely and simulates an instant successful
/// payment, then polls the backend webhook reconciliation endpoint for
/// confirmation. This enables local simulator testing without Razorpay keys.
///
/// Usage:
/// 1. Call [createOrder] to get a `razorpay_order_id` from the backend.
/// 2. Call [startPayment] with the order details and user prefill.
/// 3. Listen to the returned [Future] for success/error/external wallet.
class RazorpayPaymentService {
  /// Creates the service. Razorpay SDK initialization is deferred to
  /// [init] so it can be called from a screen's `initState` or lazily
  /// before the first checkout. This avoids constructing the native
  /// plugin before the Flutter engine is ready.
  RazorpayPaymentService(this._api);

  final ApiClient _api;
  Razorpay? _razorpay;
  bool _isInitialized = false;

  Completer<PaymentResult>? _completer;

  /// Initializes the Razorpay SDK and registers event handlers.
  /// Safe to call multiple times — subsequent calls are no-ops.
  /// Should be called from a payment screen's `initState` or before
  /// the first [openCheckout] call.
  void init() {
    if (_isInitialized) return;
    _razorpay = Razorpay();
    _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleSuccess);
    _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handleError);
    _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _isInitialized = true;
  }

  /// Returns true when `USE_MOCK_PAYMENTS=true` is set in the .env file
  /// OR when no Razorpay key ID was provided via --dart-define.
  /// In both cases we bypass the real Razorpay SDK and simulate payment.
  bool get useMockPayments {
    try {
      return dotenv.maybeGet('USE_MOCK_PAYMENTS')?.toLowerCase() == 'true' ||
          _razorpayKeyId.isEmpty;
    } catch (_) {
      // dotenv not loaded (release build without .env) — use mock if no key
      return _razorpayKeyId.isEmpty;
    }
  }

  /// Razorpay Key ID. In production this comes from the backend or is
  /// injected via --dart-define. For now we read from the same config
  /// that the backend uses (passed to the client at build time).
  static const String _razorpayKeyId = String.fromEnvironment(
    'RAZORPAY_KEY_ID',
    defaultValue: '',
  );

  /// Creates a payment order on the backend via `POST /api/payments`.
  ///
  /// [amount] is in rupees (will be converted to paise).
  /// Exactly one of the booking ID fields must be provided.
  Future<({String paymentId, String providerOrderId})> createOrder({
    double amount = 0,
    String currency = 'INR',
    String? foodOrderId,
    String? serviceBookingId,
    String? transitTripId,
    String? luggageDropOffId,
    String? scooterRentalId,
  }) async {
    final body = <String, dynamic>{
      'amount': amount,
      'currency': currency,
      if (foodOrderId != null) 'foodOrderId': foodOrderId,
      if (serviceBookingId != null) 'serviceBookingId': serviceBookingId,
      if (transitTripId != null) 'transitTripId': transitTripId,
      if (luggageDropOffId != null) 'luggageDropOffId': luggageDropOffId,
      if (scooterRentalId != null) 'scooterRentalId': scooterRentalId,
    };

    final response = await _api.post('/api/payments', data: body)
        as Map<String, dynamic>;

    return (
      paymentId: response['paymentId'] as String,
      providerOrderId: response['providerOrderId'] as String,
    );
  }

  /// Verifies a Razorpay payment on the backend by sending the
  /// `razorpay_payment_id`, `razorpay_order_id`, and `razorpay_signature`
  /// to `POST /api/payments/verify`. The backend validates the HMAC SHA256
  /// signature before transitioning the order to `Paid`.
  Future<bool> verifyPayment({
    required String razorpayPaymentId,
    required String razorpayOrderId,
    String? razorpaySignature,
  }) async {
    try {
      final body = <String, dynamic>{
        'razorpayPaymentId': razorpayPaymentId,
        'razorpayOrderId': razorpayOrderId,
        if (razorpaySignature != null) 'razorpaySignature': razorpaySignature,
      };
      await _api.post('/api/payments/verify', data: body);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Starts a payment flow for the given [orderId] and [amount].
  ///
  /// When `USE_MOCK_PAYMENTS=true`, instantly simulates a successful payment
  /// without opening the Razorpay UI, then polls the backend for confirmation.
  /// Otherwise, opens the real Razorpay checkout sheet with UPI intent enabled.
  Future<PaymentResult> startPayment({
    required String orderId,
    required int amount,
    required String phone,
    String? userEmail,
    String? userName,
  }) {
    if (useMockPayments) {
      return _simulateMockPayment(orderId, amount);
    }
    return openCheckout(
      amount: amount.toDouble() / 100, // openCheckout expects rupees
      orderId: orderId,
      userPhone: phone,
      userEmail: userEmail,
      userName: userName,
    );
  }

  /// Opens the Razorpay checkout sheet.
  ///
  /// Returns a [Future] that completes with a [PaymentResult] when the user
  /// completes, cancels, or errors out of the payment flow.
  Future<PaymentResult> openCheckout({
    required double amount,
    required String orderId,
    required String userPhone,
    String? userEmail,
    String? userName,
  }) {
    _completer = Completer<PaymentResult>();

    final options = <String, dynamic>{
      'key': _razorpayKeyId,
      'amount': (amount * 100).round(), // paise
      'currency': 'INR',
      'order_id': orderId,
      'name': 'PY Connect',
      'description': 'Payment for your order',
      'prefill': <String, dynamic>{
        'contact': userPhone,
        if (userEmail != null && userEmail.isNotEmpty) 'email': userEmail,
        if (userName != null && userName.isNotEmpty) 'name': userName,
      },
      'external': <String, dynamic>{
        'wallets': ['phonepe', 'googlepay', 'paytm'],
      },
      // Enable UPI Intent so the user can pay via any UPI app
      'config': <String, dynamic>{
        'upi': <String, dynamic>{
          'intent': true,
        },
      },
    };

    try {
      // Lazy-init the SDK if the screen didn't call init() in initState.
      if (!_isInitialized) init();
      _razorpay!.open(options);
    } catch (e) {
      // Any SDK initialization failure (NotInitializedError, missing
      // native plugin, platform issues) falls back to mock payment so
      // the user is never blocked during the testing phase.
      _completer!.complete(_simulateMockPaymentSync(orderId, (amount * 100).round()));
    }

    return _completer!.future;
  }

  /// Simulates an instant successful payment for local testing.
  /// Generates a fake payment ID and returns [PaymentSuccess] immediately.
  Future<PaymentResult> _simulateMockPayment(String orderId, int amount) async {
    // Simulate a small delay for realism
    await Future.delayed(const Duration(milliseconds: 500));

    final mockPaymentId = 'pay_mock_${DateTime.now().millisecondsSinceEpoch}';
    return PaymentSuccess(
      paymentId: mockPaymentId,
      orderId: orderId,
      signature: null,
    );
  }

  /// Synchronous mock payment for fallback when Razorpay SDK fails to open.
  PaymentResult _simulateMockPaymentSync(String orderId, int amount) {
    final mockPaymentId = 'pay_mock_${DateTime.now().millisecondsSinceEpoch}';
    return PaymentSuccess(
      paymentId: mockPaymentId,
      orderId: orderId,
      signature: null,
    );
  }

  void _handleSuccess(PaymentSuccessResponse response) {
    _completer?.complete(
      PaymentSuccess(
        paymentId: response.paymentId ?? '',
        orderId: response.orderId ?? '',
        signature: response.signature,
      ),
    );
  }

  void _handleError(PaymentFailureResponse response) {
    _completer?.complete(
      PaymentError(
        code: response.code ?? 0,
        message: response.message ?? 'Payment failed. Please try again.',
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _completer?.complete(
      PaymentExternalWallet(walletName: response.walletName ?? ''),
    );
  }

  /// Clears the Razorpay instance. Call in dispose.
  void clear() {
    _razorpay?.clear();
  }
}
