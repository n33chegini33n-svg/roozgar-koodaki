import '../utils/jalali.dart';
import 'school_classes.dart';

/// مدل مرحله پرداخت نقدی (حداکثر ۳ مرحله)
class CashStage {
  final String title;
  final int amount;
  final String dueDate;
  final bool isSettled;

  CashStage({
    required this.title,
    required this.amount,
    required this.dueDate,
    this.isSettled = false,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'amount': amount,
        'dueDate': dueDate,
        'isSettled': isSettled,
      };

  factory CashStage.fromJson(Map<String, dynamic> json) => CashStage(
        title: json['title'] ?? 'مرحله پرداخت',
        amount: json['amount'] ?? 0,
        dueDate: json['dueDate'] ?? JalaliDate.now().formatted,
        isSettled: json['isSettled'] ?? false,
      );

  CashStage copyWith({
    String? title,
    int? amount,
    String? dueDate,
    bool? isSettled,
  }) {
    return CashStage(
      title: title ?? this.title,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      isSettled: isSettled ?? this.isSettled,
    );
  }
}

class TuitionRecord {
  final String id;
  final String studentName;
  final String className;
  final int amount; // in Toman
  final String status; // 'پرداخت‌شده 🟢', 'در انتظار تأیید 🟡', 'معوقه / بدهکار 🔴'
  final String date;
  final String receiptNo;
  final String feeType;
  final String feeTitle;
  final String description;
  final bool isIncluded;
  final bool isCash;
  final bool isInstallment;
  final List<CashStage> cashStages;
  final int installmentCount;
  final List<bool> installmentSettled;
  final String documentNote;

  TuitionRecord({
    required this.id,
    required this.studentName,
    required this.className,
    required this.amount,
    required this.status,
    required this.date,
    required this.receiptNo,
    this.feeType = 'شهریه',
    this.feeTitle = 'شهریه',
    this.description = '',
    this.isIncluded = true,
    this.isCash = true,
    this.isInstallment = false,
    List<CashStage>? cashStages,
    this.installmentCount = 1,
    List<bool>? installmentSettled,
    this.documentNote = '',
  })  : cashStages = cashStages ?? [
          CashStage(title: 'مرحله اول', amount: amount, dueDate: date, isSettled: status.contains('پرداخت‌شده')),
          CashStage(title: 'مرحله دوم', amount: 0, dueDate: date, isSettled: false),
          CashStage(title: 'مرحله سوم', amount: 0, dueDate: date, isSettled: false),
        ],
        installmentSettled = installmentSettled ?? List.generate(installmentCount > 0 ? installmentCount : 1, (i) => status.contains('پرداخت‌شده'));

  Map<String, dynamic> toJson() => {
        'id': id,
        'studentName': studentName,
        'className': className,
        'amount': amount,
        'status': status,
        'date': date,
        'receiptNo': receiptNo,
        'feeType': feeType,
        'feeTitle': feeTitle,
        'description': description,
        'isIncluded': isIncluded,
        'isCash': isCash,
        'isInstallment': isInstallment,
        'cashStages': cashStages.map((e) => e.toJson()).toList(),
        'installmentCount': installmentCount,
        'installmentSettled': installmentSettled,
        'documentNote': documentNote,
      };

  factory TuitionRecord.fromJson(Map<String, dynamic> json) {
    List<CashStage> stages = [];
    if (json['cashStages'] != null && json['cashStages'] is List) {
      stages = (json['cashStages'] as List).map((e) => CashStage.fromJson(Map<String, dynamic>.from(e))).toList();
    }
    final amt = json['amount'] ?? 0;
    final dt = json['date'] ?? JalaliDate.now().formatted;
    final st = json['status'] ?? 'پرداخت‌شده 🟢';
    if (stages.isEmpty) {
      stages = [
        CashStage(title: 'مرحله اول', amount: amt, dueDate: dt, isSettled: st.contains('پرداخت‌شده')),
        CashStage(title: 'مرحله دوم', amount: 0, dueDate: dt, isSettled: false),
        CashStage(title: 'مرحله سوم', amount: 0, dueDate: dt, isSettled: false),
      ];
    }
    final instCount = json['installmentCount'] ?? 1;
    List<bool> instSettled = [];
    if (json['installmentSettled'] != null && json['installmentSettled'] is List) {
      instSettled = List<bool>.from(json['installmentSettled']);
    } else {
      instSettled = List.generate(instCount, (_) => st.contains('پرداخت‌شده'));
    }
    return TuitionRecord(
      id: json['id'] ?? '',
      studentName: json['studentName'] ?? '',
      className: normalizeClassName(((json['className']) ?? '').toString()),
      amount: amt,
      status: st,
      date: dt,
      receiptNo: json['receiptNo'] ?? 'REC-001',
      feeType: json['feeType'] ?? 'شهریه',
      feeTitle: json['feeTitle'] ?? 'شهریه',
      description: json['description'] ?? '',
      isIncluded: json['isIncluded'] ?? true,
      isCash: json['isCash'] ?? true,
      isInstallment: json['isInstallment'] ?? false,
      cashStages: stages,
      installmentCount: instCount,
      installmentSettled: instSettled,
      documentNote: json['documentNote'] ?? '',
    );
  }

  TuitionRecord copyWith({
    String? id,
    String? studentName,
    String? className,
    int? amount,
    String? status,
    String? date,
    String? receiptNo,
    String? feeType,
    String? feeTitle,
    String? description,
    bool? isIncluded,
    bool? isCash,
    bool? isInstallment,
    List<CashStage>? cashStages,
    int? installmentCount,
    List<bool>? installmentSettled,
    String? documentNote,
  }) {
    return TuitionRecord(
      id: id ?? this.id,
      studentName: studentName ?? this.studentName,
      className: className ?? this.className,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      date: date ?? this.date,
      receiptNo: receiptNo ?? this.receiptNo,
      feeType: feeType ?? this.feeType,
      feeTitle: feeTitle ?? this.feeTitle,
      description: description ?? this.description,
      isIncluded: isIncluded ?? this.isIncluded,
      isCash: isCash ?? this.isCash,
      isInstallment: isInstallment ?? this.isInstallment,
      cashStages: cashStages ?? this.cashStages,
      installmentCount: installmentCount ?? this.installmentCount,
      installmentSettled: installmentSettled ?? this.installmentSettled,
      documentNote: documentNote ?? this.documentNote,
    );
  }
}