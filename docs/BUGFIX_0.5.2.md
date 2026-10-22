# pcwav 0.5.2 — PC-1360K実機録音に合わせたS1 Binary末尾修正

0.5.1は、長さが120の倍数の場合に最後のchunkにも個別SUMを付け、tailをFFだけから計算していた。
今回ユーザーが提供したPC-1360KのCSAVE M録音120/240 bytesにより、この想定を訂正した。

## 確定した処理

- 最後以外の120 raw bytesごとにchunk SUMを付ける。
- 最後のchunkは1〜120 raw bytes。ちょうど120でも個別chunk SUMを付けない。
- 最後のchunk＋最初のFFから共通S1 checksumを計算し、一度だけnibble swapして格納する。
- 終端はFF FF SUM。2個目のFFは加算しない。
- Decoderはremaining > 120の間だけ通常chunkを検証し、残り1〜120をtailと一緒に検証する。
  0.5.1で修正した65536の長さ復元、範囲検証、checksum破損時の即時失敗は維持する。

S1/S2 BASIC Encoderの既存末尾chunk処理と同じ規則であり、BASICコードは変更していない。
parse_numと用途別範囲検証も0.5.1の修正を維持する。

## 実機確認

ユーザーにより0.5.1生成WAVの全6ケースのCLOAD M成功を確認済み。
再保存の001a/119/120/121/240/4112.wav（合成データの実機CSAVE録音）を0.5.2配布Decoderで検証し、
すべて開始0x9000、指定長、全byte一致、header/metadata/chunk/tail checksum正常を確認した。
初回001.wavはユーザーの保存範囲が2 bytesだったため、1 byteの再録音001a.wavで合格とした。

| bytes | 最終chunk bytes | 実機tail SUM（格納値） |
|---:|---:|---|
| 1 | 1 | 0x22 |
| 119 | 119 | 0x3E |
| 120 | 120 | 0x5E |
| 121 | 1 | 0xD2 |
| 240 | 120 | 0x66 |
| 4112 | 32 | 0xDF |

合成テストの独立期待値も実機規則へ訂正。上記の実測SUMは固定の回帰期待値として追加。
旧0.5.1の「個別SUM付き最終full chunk＋FF-only tail」構造を拒否するテストも追加した。
176件のPerlテスト、全5モードの配布CLI往復・数値エラー・破損WAV拒否、全Perl構文確認に成功。
65536 bytesその他の境界は合成検証。実機で確認した条件と混同しない。

## 互換性と再テスト

0.5.1が生成した120の倍数のBinary WAVは、新Decoderでは失敗する場合がある。
誤った構造を黙って受理するfallbackは追加していない。原本binから再生成する。
正常時の戻り値キーとCLIは0.5.1と同じで、footer_okは成功時1。

修正版のテストデータは`hardware-tests-0.5.2/`へ別途生成した。
以前の`hardware-tests/`は0.5.1ロード成功の証拠と混同しないよう保持した。
新Encoderの120/240 bytes WAVは実機CSAVEと同じbody/tail構造だが、新WAVの実機CLOADは未実施。
余りありのWAVは0.5.1からbody構造に変更なし。新WAVの確認では120/240を優先する。
録音はDownloadsから読み取り専用で使用し、Gitへ追加・コピーしていない。

```sh
perl build.pl
prove t/s1binary.t
python3 t/test_cli.py
python3 tools/make_hardware_tests.py --addr 0x9000 --output /tmp/pcwav-tests-0.5.2
python3 tools/check_hardware_capture.py hardware-tests-0.5.2 S00120 /path/to/120.wav
shasum -a 256 dist/pcwav-encode.pl dist/pcwav-decode.pl
```

生成先は未作成フォルダを指定する。原本は合成binのみ。ライセンス整備は引き続き別作業。
PGPは変更していない。PGPへはこの修正版commitから生成した2本を取り込む。
暫定parse_num追加は不要で、取得元commit/version/SHA-256を更新する。

```text
3af7b5871f44fe2113ec94682930ac855c309120ea46cad3c62299dacae8d671  pcwav-encode.pl
4de1109697af337715a8febd164f940d9a06d9581d49e7ff4638fe2f31be4549  pcwav-decode.pl
```
