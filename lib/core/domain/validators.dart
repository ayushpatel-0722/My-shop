import '../models/category.dart';
import '../models/product.dart';
import '../models/voucher.dart';
import '../../app/l10n/l10n_service.dart';

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
      errors['name'] = L10n.current.productTitleIsRequired;
    } else if (product.name.trim().length < 2) {
      errors['name'] = L10n.current.useAtLeast2Characters;
    }

    if (product.amount <= 0) {
      errors['amount'] = L10n.current.mrpMustBeGreaterThan0;
    }

    if (product.discountAmt < 0) {
      errors['discountAmt'] = L10n.current.sellingPriceCannotBeNegative;
    } else if (product.discountAmt > 0 &&
        product.discountAmt >= product.amount) {
      errors['discountAmt'] =
          L10n.current.sellingPriceMustBeLowerThanTheMrpOrLeftAt0;
    }

    if (!product.isUnlimitedStock && product.stockQty < 0) {
      errors['stockQty'] = L10n.current.stockCannotBeNegative;
    }

    if (product.unit <= 0) {
      errors['unit'] = L10n.current.unitMustBeGreaterThan0;
    }

    if (product.categoryId.isEmpty) {
      errors['categoryId'] = L10n.current.pickACategoryForThisProduct;
    }

    if (product.type == ProductType.weightBased && product.unitType.isEmpty) {
      errors['unitType'] = L10n.current.weightBasedProductsNeedAUnitKgG;
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
  }) => ValidationResult(
    _errors(
      name: name,
      existing: existing,
      companyId: companyId,
      selfId: selfId,
      parentId: parentId,
    ),
  );

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
      errors['name'] = L10n.current.categoryNameIsRequired;
      return errors;
    }
    if (trimmed.length < 2) {
      errors['name'] = L10n.current.useAtLeast2Characters;
    }

    final duplicate = existing.any(
      (c) =>
          c.id != selfId &&
          c.companyId == companyId &&
          c.name.trim().toLowerCase() == trimmed.toLowerCase(),
    );
    if (duplicate) {
      errors['name'] = L10n.current.aCategoryWithThisNameAlreadyExists;
    }

    if (parentId != null && parentId.isNotEmpty && parentId == selfId) {
      errors['parentId'] = L10n.current.aCategoryCannotBeItsOwnParent;
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
      errors['code'] = L10n.current.voucherCodeIsRequired;
    } else if (normalized.length < codeMinLength) {
      errors['code'] = L10n.current.useAtLeastCharacters('$codeMinLength');
    } else if (normalized.length > codeMaxLength) {
      errors['code'] = L10n.current.useAtMostCharacters('$codeMaxLength');
    } else if (!RegExp(r'^[A-Z0-9]+$').hasMatch(normalized)) {
      errors['code'] = L10n.current.onlyLettersAndNumbersAreAllowed;
    } else if (existingCodes.any(
      (c) => c.toUpperCase() == normalized && c.isNotEmpty,
    )) {
      errors['code'] = L10n.current.thisCodeAlreadyExistsForThisStore;
    }

    if (discountType == VoucherType.percentage) {
      if (discountValue <= 0) {
        errors['discountValue'] = L10n.current.enterAPercentageGreaterThan0;
      } else if (discountValue > 100) {
        errors['discountValue'] = L10n.current.percentageCannotExceed100;
      }
    } else if (discountType == VoucherType.fixedAmount) {
      if (discountValue <= 0) {
        errors['discountValue'] = L10n.current.enterAnAmountGreaterThan0;
      }
    }

    if (minOrderAmt < 0) {
      errors['minOrderAmt'] = L10n.current.minimumOrderCannotBeNegative;
    } else if (discountType == VoucherType.fixedAmount &&
        minOrderAmt > 0 &&
        minOrderAmt <= discountValue) {
      errors['minOrderAmt'] =
          'Minimum order should be higher than the discount, '
          'otherwise the order can total zero.';
    }

    if (perUserLimit <= 0) {
      errors['perUserLimit'] = L10n.current.perUserLimitMustBeAtLeast1;
    }

    if (maxUses <= 0) {
      errors['maxUses'] = L10n.current.totalUsageLimitMustBeAtLeast1;
    } else if (maxUses < perUserLimit) {
      errors['maxUses'] =
          L10n.current.totalLimitCannotBeLowerThanThePerUserLimit;
    }

    if (expiryDate != null &&
        (now ?? DateTime.now()).isAfter(
          expiryDate.add(const Duration(days: 1)),
        )) {
      errors['expiryDate'] = L10n.current.expiryDateMustBeInTheFuture;
    }

    if (appliesTo == VoucherScope.specificProduct && productIds.isEmpty) {
      errors['productIds'] = L10n.current.selectAtLeastOneProduct;
    }
    if (appliesTo == VoucherScope.specificCategory && categoryIds.isEmpty) {
      errors['categoryIds'] = L10n.current.selectAtLeastOneCategory;
    }

    return ValidationResult(errors);
  }
}
