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
