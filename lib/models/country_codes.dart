/// Country code data for phone number input.
/// Focused on West Africa + diaspora countries.
class CountryCode {
  final String name;
  final String code;
  final String dialCode;
  final String flag;

  const CountryCode({
    required this.name,
    required this.code,
    required this.dialCode,
    required this.flag,
  });

  String get display => '$flag $dialCode';
  String get fullDisplay => '$flag $name ($dialCode)';
}

/// Curated list - diaspora-relevant countries first, then common ones
const List<CountryCode> countryCodes = [
  // Priority: US (where most operators are based)
  CountryCode(name: 'United States', code: 'US', dialCode: '+1', flag: '🇺🇸'),
  
  // West Africa destinations
  CountryCode(name: 'Burkina Faso', code: 'BF', dialCode: '+226', flag: '🇧🇫'),
  CountryCode(name: "Cote d'Ivoire", code: 'CI', dialCode: '+225', flag: '🇨🇮'),
  CountryCode(name: 'Togo', code: 'TG', dialCode: '+228', flag: '🇹🇬'),
  CountryCode(name: 'Ghana', code: 'GH', dialCode: '+233', flag: '🇬🇭'),
  CountryCode(name: 'Senegal', code: 'SN', dialCode: '+221', flag: '🇸🇳'),
  CountryCode(name: 'Mali', code: 'ML', dialCode: '+223', flag: '🇲🇱'),
  CountryCode(name: 'Niger', code: 'NE', dialCode: '+227', flag: '🇳🇪'),
  CountryCode(name: 'Benin', code: 'BJ', dialCode: '+229', flag: '🇧🇯'),
  CountryCode(name: 'Guinea', code: 'GN', dialCode: '+224', flag: '🇬🇳'),
  CountryCode(name: 'Cameroon', code: 'CM', dialCode: '+237', flag: '🇨🇲'),
  CountryCode(name: 'Nigeria', code: 'NG', dialCode: '+234', flag: '🇳🇬'),

  // Diaspora countries
  CountryCode(name: 'France', code: 'FR', dialCode: '+33', flag: '🇫🇷'),
  CountryCode(name: 'Canada', code: 'CA', dialCode: '+1', flag: '🇨🇦'),
  CountryCode(name: 'United Kingdom', code: 'GB', dialCode: '+44', flag: '🇬🇧'),
  CountryCode(name: 'Italy', code: 'IT', dialCode: '+39', flag: '🇮🇹'),
  CountryCode(name: 'Germany', code: 'DE', dialCode: '+49', flag: '🇩🇪'),
  CountryCode(name: 'Belgium', code: 'BE', dialCode: '+32', flag: '🇧🇪'),
  CountryCode(name: 'Spain', code: 'ES', dialCode: '+34', flag: '🇪🇸'),
  CountryCode(name: 'Portugal', code: 'PT', dialCode: '+351', flag: '🇵🇹'),
];

/// Default country code (US - where most diaspora operators are)
const CountryCode defaultCountryCode = CountryCode(
  name: 'United States',
  code: 'US',
  dialCode: '+1',
  flag: '🇺🇸',
);

/// Find a CountryCode by its dial code string (e.g., "+226")
CountryCode? findCountryByDialCode(String dialCode) {
  try {
    return countryCodes.firstWhere((c) => c.dialCode == dialCode);
  } catch (_) {
    return null;
  }
}
