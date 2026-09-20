import '../models/category.dart';
import '../models/product.dart';
import '../models/voucher.dart';

/// Field name -> first error message. Empty means "valid".
///
/// Screens render [errorFor] directly into `TextFormField.errorText`, so the
/// validation copy lives next to the rules instead of being sprinkled over
/// `onPressed` handlers.
class ValidationResult {
  final Map<String, String> errors;

  const ValidationResult([this.errors = const <String, String>{}]);

  const ValidationResult.valid() : errors = const <String, String>{};

  bool get isValid => errors.isEmpty;
  bool get hasErrors => errors.isNotEmpty;

  String? errorFor(String field) => errors[field];

  ValidationResult merge(ValidationResult other) =>
      ValidationResult(<String, String>{...errors, ...other.errors});

  @override
  String toString() => 'ValidationResult($errors)';
}

/// Validation for the admin product editor.
class ProductValidator {
  const ProductValidator();

  ValidationResult validate(Product product) {
    final errors = <String, String>{};

    if (product.name.trim().isEmpty) {
      errors['name'] = 'Product title is required.';
    } else if (product.name.trim().length < 2) {
      errors['name'] = 'Use at least 2 characters.';
    }

    if (product.amount <= 0) {
      errors['amount'] = 'MRP must be greater than 0.';
    }

    if (product.discountAmt < 0) {
      errors['discountAmt'] = 'Selling price cannot be negative.';
    } else if (product.discountAmt > 0 &&
        product.discountAmt >= product.amount) {
      errors['discountAmt'] =
          'Selling price must be lower than the MRP (or left at 0).';
    }

    if (!product.isUnlimitedStock && product.stockQty < 0) {
      errors['stockQty'] = 'Stock cannot be negative.';
    }

    if (product.unit <= 0) {
      errors['unit'] = 'Unit must be greater than 0.';
    }

    if (product.categoryId.isEmpty) {
      errors['categoryId'] = 'Pick a category for this product.';
    }

    if (product.type == ProductType.weightBased && product.unitType.isEmpty) {
      errors['unitType'] = 'Weight based products need a unit (kg, g, ...).';
    }

    return ValidationResult(errors);
  }
}

/// Validation for the admin category editor (name + hierarchy placement).
class CategoryValidator {
  const CategoryValidator();

  ValidationResult validate({
    required String name,
    required List<Category> existing,
    String companyId = '',
    String selfId = '',
    String? parentId,
  }) =>
      ValidationResult(_errors(
        name: name,
        existing: existing,
        companyId: companyId,
        selfId: selfId,
        parentId: parentId,
      ));

  Map<String, String> _errors({
    required String name,
    required List<Category> existing,
    required String companyId,
    required String selfId,
    String? parentId,
  }) {
    final errors = <String, String>{};
    final trimmed = name.trim();

    if (trimmed.isEmpty) {
      errors['name'] = 'Category name is required.';
      return errors;
    }
    if (trimmed.length < 2) {
      errors['name'] = 'Use at least 2 characters.';
    }

    final duplicate = existing.any(
      (c) =>
          c.id != selfId &&
          c.companyId == companyId &&
          c.name.trim().toLowerCase() == trimmed.toLowerCase(),
    );
    if (duplicate) {
      errors['name'] = 'A category with this name already exists.';
    }

    if (parentId != null && parentId.isNotEmpty && parentId == selfId) {
      errors['parentId'] = 'A category cannot be its own parent.';
    }
    return errors;
  }
}

/// Validation for the admin voucher editor.
class VoucherValidator {
  const VoucherValidator();

  static const int codeMinLength = 3;
  static const int codeMaxLength = 24;

  ValidationResult validate({
    required String code,
    required String discountType,
    required double discountValue,
    required double minOrderAmt,
    required int perUserLimit,
    required int maxUses,
    required String appliesTo,
    required List<String> productIds,
    required List<String> categoryIds,
    required List<String> existingCodes,
    DateTime? expiryDate,
    String selfId = '',
    DateTime? now,
  }) {
    final errors = <String, String>{};
    final normalized = Voucher.normalizeCode(code);

    if (normalized.isEmpty) {
      errors['code'] = 'Voucher code is required.';
    } else if (normalized.length < codeMinLength) {
      errors['code'] = 'Use at least $codeMinLength characters.';
    } else if (normalized.length > codeMaxLength) {
      errors['code'] = 'Use at most $codeMaxLength characters.';
    } else if (!RegExp(r'^[A-Z0-9]+$').hasMatch(normalized)) {
      errors['code'] = 'Only letters and numbers are allowed.';
    } else if (existingCodes.any(
      (c) => c.toUpperCase() == normalized && c.isNotEmpty,
    )) {
      errors['code'] = 'This code already exists for this store.';
    }

    if (discountType == VoucherType.percentage) {
      if (discountValue <= 0) {
        errors['discountValue'] = 'Enter a percentage greater than 0.';
      } else if (discountValue > 100) {
        errors['discountValue'] = 'Percentage cannot exceed 100.';
      }
    } else if (discountType == VoucherType.fixedAmount) {
      if (discountValue <= 0) {
        errors['discountValue'] = 'Enter an amount greater than 0.';
      }
    }

    if (minOrderAmt < 0) {
      errors['minOrderAmt'] = 'Minimum order cannot be negative.';
    } else if (discountType == VoucherType.fixedAmount &&
        minOrderAmt > 0 &&
        minOrderAmt <= discountValue) {
      errors['minOrderAmt'] =
          'Minimum order should be higher than the discount, '
          'otherwise the order can total zero.';
    }

    if (perUserLimit <= 0) {
      errors['perUserLimit'] = 'Per-user limit must be at least 1.';
    }

    if (maxUses <= 0) {
      errors['maxUses'] = 'Total usage limit must be at least 1.';
    } else if (maxUses < perUserLimit) {
      errors['maxUses'] =
          'Total limit cannot be lower than the per-user limit.';
    }

    if (expiryDate != null &&
        (now ?? DateTime.now()).isAfter(
          expiryDate.add(const Duration(days: 1)),
        )) {
      errors['expiryDate'] = 'Expiry date must be in the future.';
    }

    if (appliesTo == VoucherScope.specificProduct && productIds.isEmpty) {
      errors['productIds'] = 'Select at least one product.';
    }
    if (appliesTo == VoucherScope.specificCategory && categoryIds.isEmpty) {
      errors['categoryIds'] = 'Select at least one category.';
    }

    return ValidationResult(errors);
  }
}
