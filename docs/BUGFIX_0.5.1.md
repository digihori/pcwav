> 0.5.2で最終full chunk規則を訂正し、取得した6件の実機録音すべてを検証しました。
> 現行の動作は[0.5.2修正記録](BUGFIX_0.5.2.md)を参照。以下は過去の記録です。

> 2026-10-22追記: 新たなPC-1360K録音で120/240 bytesの最終full chunk規則に差異が判明。
> 0.5.1のDecoderはこの録音を拒否する。境界修正が必要。
> [実機結果](HARDWARE_TEST_0.5.1.md#2026-10-22-実機録音の検証結果)を参照。以下は0.5.1作成時の記録。

# pcwav 0.5.1 不具合修正・引き継ぎ

基準: `14e1ef53596f0d8791b6d14965061f63846d11a7` (0.5)。
PGP側は参照のみで変更していない。ライセンス決定・表記整備は別作業。

## S1 Binary

転送データはlogical byteをnibble swapしたraw byte。
120 data bytesごとに共通S1 checksumを計算し、その結果を一度だけswapして格納する。
最後がちょうど120 bytesでもchunk checksumを付ける。
余った1〜119 bytesにはchunk checksumを付けず、余りraw bytesと最初のFFからtail checksumを
計算し、一度swapして`FF FF SUM`として格納する。2個目のFFは加算しない。
120の倍数ならtailの対象はFFのみ。BASICの最終chunkの規則は変更していない。

Decoderは最後のfull chunkも検証し、宣言長65536を0へ丸めない。
開始アドレスは0x0000〜0xFFFF、長さは1〜65536、開始アドレス＋長さは65536以下。
checksum不一致、途中切断、終端欠落は失敗する。旧Encoderの誤SUMへのfallbackはない。

### 互換性

- `find_and_extract`の正常時のhashのキーは維持。`footer_ok`は成功時常に1。
- 以前は`footer_ok=0`の戻り値や欠落したbodyを返せたが、今後は例外になる。
- header候補の探索は維持。name/metadata checksumが不正な候補はスキップする。
  有効なheader確定後のbody/tail破損では即時失敗し、後続レコードへ進まない。
- CLIは検証成功後に出力を書き込む。破損時は非ゼロ終了し、出力を新規作成・上書きしない。
- 戻り値のoffsetは入力raw内のheader位置。末尾以降のデータの扱いは従来どおり。
- S1/OLD Binary Encoderはアドレス範囲外・空入力・領域超過を拒否する。

## parse_num

Commonに10進数または0x/0X付き16進数の非負整数を読む関数を追加。
未定義、空文字、負数、小数、不正文字、空白付き文字列を拒否する。
正確に扱う整数の上限は9007199254740991。それを超える入力も拒否する。
既存parse_hex_addrの受理形式は変更していない。

アドレス省略時の0xC000、S2 type省略時の0x27は維持。
S2 typeは0x27/0x37のみ。decodeのskip値欠落は明示的にエラーにする。
skip値は非負整数で、WAVのサンプル数を超える指定も拒否する。
従来どおり非ゼロのskip-samplesがskip-msより優先する。
rawモードは従来どおりskipオプションを持たない。

```sh
perl dist/pcwav-encode.pl s1bin program.bin program.wav PROGRAM 0x9000
perl dist/pcwav-encode.pl oldbin program.bin old.wav PROGRAM 0x9000
perl dist/pcwav-encode.pl s2basic input.bas basic.wav PROGRAM 0x27
perl dist/pcwav-decode.pl s1bin --skip-ms 0 program.wav recovered.bin
```

## 生成・検証

リポジトリ直下で実行する。build.plは既存distディレクトリを作り直すため、独自ファイルを置かない。

```sh
perl build.pl
prove t/s1binary.t
python3 t/test_cli.py
perl -c dist/pcwav-encode.pl
perl -c dist/pcwav-decode.pl
shasum -a 256 dist/pcwav-encode.pl dist/pcwav-decode.pl
```

生成物は従来どおりdist配下（Git追跡外）。バージョンは0.5.1。
ソース・build.pl・両生成物のPerl構文確認に成功。
Perlテスト163件: 長さ1、119、120、121、240、4112、65536の独立payload生成と復元、
アドレス境界、checksum破損、途中切断、終端欠落、旧tail拒否、数値変換。
CLIテスト: OLD/S1/S2 BASICとOLD/S1 Binaryの合成WAV往復、明示アドレス、S2 type、
skipの正常値・不正値・欠落、破損WAV拒否と出力非生成。
テストの入力は合成データのみ。ROM・実機録音・ROM由来データは含まない。

### 実機確認の範囲

PGP記録のPC-1360K録音32レコード（各4112 bytes）がtail規則の根拠。
参照: PGP `docs/reference/WAV_S1_S2_FORMAT.md` 第4〜6節と
`docs/development/PORTING_NOTES.md` のpartial-tail correction / Standalone pcwav distribution scripts。
今回の境界値テストはすべて合成検証であり、新Encoderの実機CLOADは未確認。
修正前後のSUMが異なる合成データ（121/4112 bytes等）を実機CLOADし、全バイト一致を確認する。
120/240 bytesの余りなしも回帰確認する。CSAVEし直した録音の復元比較も可能。
実機の使用可能RAMアドレスに合わせて開始アドレスを指定する。
過去の実機成功条件は未特定であり、成功理由を120の倍数だったとは断定しない。

## PGP再取り込み

本修正版から生成した両スクリプトにはparse_numが含まれるので、PGP暫定追加は不要。
生成物に再パッチせず丸ごと置き換え、取得元commit/version/SHA-256を更新する。
ただし実機確認とライセンス整備は未完了。今回PGP同梱版の更新は行わない。

```text
2d24579a28eb1d7b0b9a066e9905b81945dc685005c508986b60b8b8bb500785  pcwav-encode.pl
926037292ab22eecda4ff992a55e9dc0f142139116e203d629966f2c01373667  pcwav-decode.pl
```
