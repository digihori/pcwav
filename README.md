# PCWAV

ポケコン（SC61860系）のカセットデータ（WAV）とバイナリ／BASICの相互変換ツール。

現在は S1形式（PC-1250/1260/1350/1360/1401 など）に対応。

---

## 機能

### 1. BASIC → WAV（S1 BASIC）

perl encode_main.pl s1basic input.bas output.wav


- テキストBASICをトークン化してWAVに変換
- 実機で読み込み可能

---

### 2. WAV → BASIC（S1 BASIC）

perl decode_main.pl s1basic input.wav output.bas


- WAVをデコードしてBASICソースへ復元
- raw解析にも対応

---

### 3. バイナリ → WAV（S1）

perl encode_main.pl s1 input.bin output.wav


---

### 4. WAV → バイナリ（S1）

perl decode_main.pl s1 input.wav output.bin


---

### 5. WAV → rawダンプ

perl decode_main.pl raw input.wav output.txt


- nibble単位の解析結果を出力
- フォーマット解析・デバッグ用

---

## 対応フォーマット

- S1（第2形式）
- 対象機種例:
  - PC-1250 / 1251 / 1255
  - PC-1350 / 1360
  - PC-1401

---

## ディレクトリ構成


src/
encode_main.pl
decode_main.pl
PCWAV/
Common.pm
WavReader.pm
WavWriter.pm
PcmNormalize.pm
RawDecode.pm
Format/
S1.pm
Binary/
S1Encode.pm
S1Decode.pm
Basic/
S1Encode.pm
S1Decode.pm

dist/
(build.pl で生成)


---

## ビルド


perl build.pl


- `src/` の内容を `dist/` にコピー
- `dist/` を実行用として使用

---

## 実行例


perl dist/encode_main.pl s1basic sample.bas sample.wav
perl dist/decode_main.pl s1basic sample.wav sample.bas


---

## S1 BASIC チェックサム仕様（重要）

S1 BASIC ではチェックサムの扱いが特殊：

### ● 中間チェックサム（120バイトごと）
- nibble-swap後のデータで計算
- nibble単位加算（キャリーあり）

### ● tailチェックサム（最後）
- last chunk（未swap）で計算
- nibble単位の単純加算（キャリーなし）
- 最後に `0xFF` を加算
- 出力時に nibble swap


※ chunk checksum と tail checksum は計算方式が異なる


---

## 注意点

- BASICの文字は ASCII 範囲のみ対応
- 未対応トークンはエラー
- WAVの品質によっては decode に失敗することあり
- 実機データでもフォーマット差異あり（完全一致しない場合あり）

---

## 今後の予定

- 他形式（S2など）対応
- エラーハンドリング強化
- decode精度改善（末尾処理など）

---

## 作者

Horiuchi