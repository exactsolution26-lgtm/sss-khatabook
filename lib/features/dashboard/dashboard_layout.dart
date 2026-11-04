/// Stable identities for the six user-approved dashboard slots.
/// Visual names and renderers require the original approved references.
/// A selection is a presentation preference, never a financial data partition.
enum DashboardLayout {
  dashboard1('dashboard_1'),
  dashboard2('dashboard_2'),
  dashboard3('dashboard_3'),
  dashboard4('dashboard_4'),
  dashboard5('dashboard_5'),
  dashboard6('dashboard_6');

  const DashboardLayout(this.preferenceId);

  final String preferenceId;

  static DashboardLayout fromPreference(Object? value) {
    for (final layout in values) {
      if (layout.preferenceId == value) return layout;
    }
    return dashboard1;
  }
}
