/// Utilities for converting between legacy Windows 24-bit BGR integer colors
/// used in `.gtt` XML files and standard `#RRGGBB` hex strings.
class ColorUtils {
  const ColorUtils._();

  /// Converts a 24-bit BGR integer (e.g., `16711680` for pure blue in GTT)
  /// to a lowercase 6-digit hex string without `#` (e.g., `'0000ff'`).
  static String bgrIntToHex(int colorDec) {
    final r = (colorDec & 0xff).clamp(0, 255);
    final g = ((colorDec >> 8) & 0xff).clamp(0, 255);
    final b = ((colorDec >> 16) & 0xff).clamp(0, 255);

    return [r, g, b]
        .map((c) => c.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  /// Converts a 6-digit RGB hex string (with or without leading `#`)
  /// into a 24-bit BGR integer expected by GTT `.gtt` XML files.
  static int hexToBgrInt(String hex) {
    final clean = hex.startsWith('#') ? hex.substring(1) : hex;
    if (clean.length != 6) {
      throw FormatException('Invalid hex color string: "$hex"');
    }
    final r = int.parse(clean.substring(0, 2), radix: 16);
    final g = int.parse(clean.substring(2, 4), radix: 16);
    final b = int.parse(clean.substring(4, 6), radix: 16);

    return (b << 16) + (g << 8) + r;
  }
}
