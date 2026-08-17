import 'dart:io';

import 'package:flutter/material.dart' show IconData;

class DispatchTaskModel {
  DispatchTaskModel({
    required this.id,
    required this.taskType,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.driverEarnings,
    required this.status,
    this.driverId,
    this.orderId,
    this.batchGroupId,
    this.orderItems,
  });

  final String id;
  final String taskType;
  final String pickupAddress;
  final String dropoffAddress;
  final double driverEarnings;
  final String status;
  final String? driverId;
  final String? orderId;
  final String? batchGroupId;
  final List<OrderItemModel>? orderItems;

  factory DispatchTaskModel.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['orderItems'] as List<dynamic>?;
    return DispatchTaskModel(
      id: json['id'] as String,
      taskType: json['taskType'] as String,
      pickupAddress: json['pickupAddress'] as String,
      dropoffAddress: json['dropoffAddress'] as String,
      driverEarnings: (json['driverEarnings'] as num).toDouble(),
      status: json['status'] as String,
      driverId: json['driverId'] as String?,
      orderId: json['orderId'] as String?,
      batchGroupId: json['batchGroupId'] as String?,
      orderItems: itemsRaw
          ?.map((e) => OrderItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class OrderItemModel {
  OrderItemModel({
    required this.name,
    required this.quantity,
    this.specialInstructions,
  });

  final String name;
  final int quantity;
  final String? specialInstructions;

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      name: json['name'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      specialInstructions: json['specialInstructions'] as String?,
    );
  }
}

class DriverWalletModel {
  DriverWalletModel({
    required this.balance,
    required this.recentEntries,
  });

  final double balance;
  final List<LedgerEntryModel> recentEntries;

  factory DriverWalletModel.fromJson(Map<String, dynamic> json) {
    return DriverWalletModel(
      balance: (json['balance'] as num).toDouble(),
      recentEntries: (json['recentEntries'] as List)
          .map((e) => LedgerEntryModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Cash-collection ledger wallet returned by GET /api/driver/wallet.
/// Tracks COD commission balance, suspension status, and recent transactions.
class DriverWalletDetailModel {
  DriverWalletDetailModel({
    required this.id,
    required this.balance,
    required this.hardLimit,
    required this.currency,
    required this.suspended,
    required this.recentTransactions,
    this.lastSettledAt,
  });

  final String id;
  final double balance;
  final double hardLimit;
  final String currency;
  final bool suspended;
  final String? lastSettledAt;
  final List<WalletTransactionModel> recentTransactions;

  /// Amount needed to bring the balance to zero (only when negative).
  double get settleAmount => balance < 0 ? -balance : 0;

  /// True when the balance is within 20% of the hard limit (approaching).
  bool get isApproachingHardLimit {
    if (hardLimit >= 0) return false;
    final threshold = hardLimit * 0.8;
    return balance <= threshold && balance > hardLimit;
  }

  factory DriverWalletDetailModel.fromJson(Map<String, dynamic> json) {
    final txnsRaw = json['recentTransactions'] as List<dynamic>? ?? [];
    return DriverWalletDetailModel(
      id: json['id'] as String? ?? '',
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
      hardLimit: (json['hardLimit'] as num?)?.toDouble() ?? -1000,
      currency: json['currency'] as String? ?? 'INR',
      suspended: json['suspended'] as bool? ?? false,
      lastSettledAt: json['lastSettledAt'] as String?,
      recentTransactions: txnsRaw
          .map((e) =>
              WalletTransactionModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// A single wallet ledger entry (commission, top-up, settlement, adjustment).
class WalletTransactionModel {
  WalletTransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.createdAt,
    this.referenceId,
  });

  final String id;
  final String type;
  final double amount;
  final String description;
  final String? referenceId;
  final String createdAt;

  factory WalletTransactionModel.fromJson(Map<String, dynamic> json) {
    return WalletTransactionModel(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      description: json['description'] as String? ?? '',
      referenceId: json['referenceId'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

/// Result of initiating a Razorpay wallet top-up order.
class WalletTopUpOrderModel {
  WalletTopUpOrderModel({
    required this.orderId,
    required this.amount,
    required this.currency,
  });

  final String orderId;
  final double amount;
  final String currency;

  factory WalletTopUpOrderModel.fromJson(Map<String, dynamic> json) {
    return WalletTopUpOrderModel(
      orderId: json['orderId'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'INR',
    );
  }
}

class LedgerEntryModel {
  LedgerEntryModel({
    required this.id,
    required this.amount,
    required this.transactionType,
    required this.createdAt,
    this.reference,
  });

  final String id;
  final double amount;
  final String transactionType;
  final String? reference;
  final String createdAt;

  factory LedgerEntryModel.fromJson(Map<String, dynamic> json) {
    return LedgerEntryModel(
      id: json['id'] as String,
      amount: (json['amount'] as num).toDouble(),
      transactionType: json['transactionType'] as String,
      reference: json['reference'] as String?,
      createdAt: json['createdAt'] as String,
    );
  }
}

class InstantPayoutResultModel {
  InstantPayoutResultModel({
    required this.success,
    required this.amount,
    required this.fee,
    required this.newBalance,
    required this.message,
  });

  final bool success;
  final double amount;
  final double fee;
  final double newBalance;
  final String message;

  factory InstantPayoutResultModel.fromJson(Map<String, dynamic> json) {
    return InstantPayoutResultModel(
      success: json['success'] as bool,
      amount: (json['amount'] as num).toDouble(),
      fee: (json['fee'] as num).toDouble(),
      newBalance: (json['newBalance'] as num).toDouble(),
      message: json['message'] as String,
    );
  }
}

/// Result of a KYC document upload.
class KycUploadResult {
  KycUploadResult({
    required this.success,
    required this.message,
    required this.isKycUploaded,
  });

  final bool success;
  final String message;
  final bool isKycUploaded;

  factory KycUploadResult.fromJson(Map<String, dynamic> json) {
    return KycUploadResult(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      isKycUploaded: json['isKycUploaded'] as bool? ?? false,
    );
  }
}

/// Tracks the state of each KYC document upload zone.
enum KycDocStatus { pending, uploading, uploaded, error }

/// Driver profile returned by GET /api/driver/me.
/// Used for router guards (approval/tutorial/signature) and SignalR connect.
class DriverProfileModel {
  DriverProfileModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.vehicleType,
    required this.isApproved,
    required this.isKycUploaded,
    required this.hasCompletedTutorial,
    required this.hasSignedAgreement,
    required this.isOnline,
    this.vehiclePlate,
  });

  final String id;
  final String name;
  final String phone;
  final String vehicleType;
  final String? vehiclePlate;
  final bool isApproved;
  final bool isKycUploaded;
  final bool hasCompletedTutorial;
  final bool hasSignedAgreement;
  final bool isOnline;

  factory DriverProfileModel.fromJson(Map<String, dynamic> json) {
    return DriverProfileModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      vehicleType: json['vehicleType'] as String? ?? 'Bike',
      vehiclePlate: json['vehiclePlate'] as String?,
      isApproved: json['isApproved'] as bool? ?? false,
      isKycUploaded: json['isKycUploaded'] as bool? ?? false,
      hasCompletedTutorial: json['hasCompletedTutorial'] as bool? ?? false,
      hasSignedAgreement: json['hasSignedAgreement'] as bool? ?? false,
      isOnline: json['isOnline'] as bool? ?? false,
    );
  }
}

/// Represents a single KYC document upload slot.
class KycDocumentSlot {
  KycDocumentSlot({
    required this.label,
    required this.icon,
    required this.fieldName,
    this.file,
    this.status = KycDocStatus.pending,
    this.errorMessage,
    this.cameraOnly = false,
  });

  final String label;
  final IconData icon;
  /// The form field name expected by the backend (e.g. "aadhaar").
  final String fieldName;
  final File? file;
  final KycDocStatus status;
  final String? errorMessage;
  /// If true, only the camera source is offered (no gallery option).
  final bool cameraOnly;

  KycDocumentSlot copyWith({
    File? file,
    KycDocStatus? status,
    String? errorMessage,
  }) {
    return KycDocumentSlot(
      label: label,
      icon: icon,
      fieldName: fieldName,
      file: file ?? this.file,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      cameraOnly: cameraOnly,
    );
  }
}
