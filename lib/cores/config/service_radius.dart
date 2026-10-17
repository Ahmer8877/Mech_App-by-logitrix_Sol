/// Single source of truth for mechanic/customer service distance checks.
/// Keeping the value here prevents request lists and offer validation from
/// drifting apart when the service radius changes in the future.
const double mechanicServiceRadiusMeters = 8000.0;
const String mechanicServiceRadiusLabel = '8 km';
