class AppRules {
  static const noLogicInWidgets =
      'Widgets render state only. Business logic belongs outside UI.';

  static const noDirectDbCallsFromUi =
      'Screens and widgets must not query SQLite directly.';

  static const totalsAreSourceOfTruth =
      'Workout and lift totals must come from totals tables, not screen recalculation.';

  static const unifiedPipeline =
      'Stock and custom blocks must follow the same catalog-template-instance-log-totals pipeline.';
}