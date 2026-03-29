# pcwav

SC61860系ポケコンの WAV エンコード/デコード用 Perl ツールの雛形です。

現時点では **s1（第2形式）マシン語 BIN → WAV** を実装しています。
将来的に以下へ拡張しやすい構成にしてあります。

- BASIC（PASS あり/なし）↔ WAV
- マシン語 ↔ WAV
- old / s1 / s2 形式対応
- WAV → raw バイナリダンプ

## ディレクトリ構成

- `src/PCWAV/Common.pm`
  - 汎用関数（ファイルI/O、nibble swap、チェックサム、hex処理）
- `src/PCWAV/WavWriter.pm`
  - PCM WAV 出力
- `src/PCWAV/Format/S1.pm`
  - s1 共通フォーマット処理
- `src/PCWAV/Binary/S1.pm`
  - s1 マシン語 BIN → WAV ペイロード生成
- `src/PCWAV/Basic/S1.pm`
  - 将来の BASIC s1 用プレースホルダ
- `src/encode_main.pl`
  - エンコード CLI 本体
- `src/decode_main.pl`
  - デコード CLI 本体（現時点では骨組み）
- `build.pl`
  - 開発用ファイルを 2 本の配布用スクリプトへ結合

## 開発時

```bash
perl src/encode_main.pl bin --format s1 --addr 4000 --name YAGSHI test.bin test.wav
```

## 配布用生成

```bash
perl build.pl
```

生成物:

- `dist/pcwav-encode.pl`
- `dist/pcwav-decode.pl`
