# jtt_core

Pure-Dart domain models and bidirectional `.gtt` (Guntram's Tabletweaving Thingy XML) <-> `.jtt` (JSON) conversion engine for tablet weaving.

## Highlights

- **Platform-Agnostic**: Zero `dart:io` dependencies—runs on Flutter (iOS, Android, Web, Desktop) and Dart CLI.
- **Dart 3 & Null-Safe**: Uses `package:lints`, Dart 3 enhanced `enum`s, `switch` expressions, and safe XML parsing without `!` crashes on optional tags.
- **Bug Fixes from Legacy CLI**:
  - Fixed `<CurPos>` parsing in `GttCard.fromXml` (previously read `<CurThread>`).
  - Fixed `Dist` attribute parsing in `GttAction.fromXml` (previously read `Dir`).
  - Preserved both `Twist` and `Turn` actions during `.jtt` -> `.gtt` XML round-tripping.
  - Added full support for `BrokenTwill`, `Brocade`, and `LetteredBand` pattern types.
