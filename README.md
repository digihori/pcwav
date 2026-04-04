# PCWAV

SHARP ポケットコンピュータ（SC61860系）のカセットデータ（WAV）を扱うツールです。

- WAV ↔ バイナリ / BASIC
- OLD / S1 / S2 形式対応

---

## 対応フォーマット

| Format | BASIC | BIN |
|--------|------|-----|
| OLD    | ✓    | ✓   |
| S1     | ✓    | ✓   |
| S2     | ✓    | -   |

---

## 使い方

### Encode

perl src/encode_main.pl oldbasic input.bas output.wav [filename]
perl src/encode_main.pl oldbin   input.bin output.wav [filename] [addr]

perl src/encode_main.pl s1basic  input.bas output.wav [filename]
perl src/encode_main.pl s1bin    input.bin output.wav [filename] [addr]

perl src/encode_main.pl s2basic  input.bas output.wav [filename]

### Decode
perl src/decode_main.pl raw      input.wav output.bin

perl src/decode_main.pl oldbasic input.wav output.bas
perl src/decode_main.pl oldbin   input.wav output.bin

perl src/decode_main.pl s1basic  input.wav output.bas
perl src/decode_main.pl s1bin    input.wav output.bin

perl src/decode_main.pl s2basic  input.wav output.bas
