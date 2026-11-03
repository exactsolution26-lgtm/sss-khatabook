import '../security/tenant_access.dart';

enum DiscountKind { percentage, fixedPaise }

class PlanOffer {
  const PlanOffer({
    required this.kind,
    required this.value,
    required this.startsAtUtc,
    required this.endsAtUtc,
  });

  final DiscountKind kind;
  final int value;
  final DateTime startsAtUtc;
  final DateTime endsAtUtc;
}

class EditablePlan {
  const EditablePlan({
    required this.id,
    required this.name,
    required this.pricePaise,
    required this.billingMonths,
    this.active = true,
    this.offer,
  });

  final String id;
  final String name;
  final int pricePaise;
  final int billingMonths;
  final bool active;
  final PlanOffer? offer;
}

class PriceQuote {
  const PriceQuote({
    required this.originalPaise,
    required this.discountPaise,
  });

  final int originalPaise;
  final int discountPaise;
  int get payablePaise => originalPaise - discountPaise;
}

class PricingPolicy {
  const PricingPolicy._();

  static void validatePlan(EditablePlan plan) {
    if (plan.id.trim().isEmpty || plan.name.trim().isEmpty ||
        plan.pricePaise < 0 || plan.billingMonths <= 0) {
      throw ArgumentError('Invalid subscription plan');
    }
    final offer = plan.offer;
    if (offer == null) return;
    if (!offer.startsAtUtc.isUtc || !offer.endsAtUtc.isUtc ||
        !offer.endsAtUtc.isAfter(offer.startsAtUtc) ||
        offer.value < 0 ||
        (offer.kind == DiscountKind.percentage && offer.value > 100) ||
        (offer.kind == DiscountKind.fixedPaise &&
            offer.value > plan.pricePaise)) {
      throw ArgumentError('Invalid discount offer');
    }
  }

  static EditablePlan updatePlan({
    required TenantPrincipal actor,
    required EditablePlan replacement,
  }) {
    TenantAccess.requirePlatformAdmin(actor);
    validatePlan(replacement);
    return replacement;
  }

  static PriceQuote quote(EditablePlan plan, DateTime nowUtc) {
    validatePlan(plan);
    if (!nowUtc.isUtc) throw ArgumentError('Expected UTC time');
    if (!plan.active) throw StateError('Plan is not available');
    final offer = plan.offer;
    if (offer == null || nowUtc.isBefore(offer.startsAtUtc) ||
        !nowUtc.isBefore(offer.endsAtUtc)) {
      return PriceQuote(originalPaise: plan.pricePaise, discountPaise: 0);
    }
    final discount = offer.kind == DiscountKind.percentage
        ? plan.pricePaise * offer.value ~/ 100
        : offer.value;
    return PriceQuote(
      originalPaise: plan.pricePaise,
      discountPaise: discount,
    );
  }
}
