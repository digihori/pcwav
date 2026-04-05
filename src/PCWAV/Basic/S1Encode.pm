package PCWAV::Basic::S1Encode;
use strict;
use warnings;
use PCWAV::Common ();
use PCWAV::TextCodec qw(encode_text_for_s1);

my %TOKEN_TO_BYTE = (
    "REC"     => 0x81, "POL"     => 0x82, "ROT"     => 0x83,
    "DEC"     => 0x84, "HEX"     => 0x85, "TEN"     => 0x86, "RCP"     => 0x87,
    "SQU"     => 0x88, "CUR"     => 0x89, "HSN"     => 0x8A, "HCS"     => 0x8B,
    "HTN"     => 0x8C, "AHS"     => 0x8D, "AHC"     => 0x8E, "AHT"     => 0x8F,

    "FAC"     => 0x90, "LN"      => 0x91, "LOG"     => 0x92, "EXP"     => 0x93,
    "SQR"     => 0x94, "SIN"     => 0x95, "COS"     => 0x96, "TAN"     => 0x97,
    "INT"     => 0x98, "ABS"     => 0x99, "SGN"     => 0x9A, "DEG"     => 0x9B,
    "DMS"     => 0x9C, "ASN"     => 0x9D, "ACS"     => 0x9E, "ATN"     => 0x9F,

    "RND"     => 0xA0, "AND"     => 0xA1, "OR"      => 0xA2, "NOT"     => 0xA3,
    "ASC"     => 0xA4, "VAL"     => 0xA5, "LEN"     => 0xA6, "PEEK"    => 0xA7,
    'CHR$'    => 0xA8, 'STR$'    => 0xA9, 'MID$'    => 0xAA, 'LEFT$'   => 0xAB,
    'RIGHT$'  => 0xAC, 'INKEY$'  => 0xAD, "PI"      => 0xAE, "MEM"     => 0xAF,

    "RUN"     => 0xB0, "NEW"     => 0xB1, "CONT"    => 0xB2, "PASS"    => 0xB3,
    "LIST"    => 0xB4, "LLIST"   => 0xB5, "CSAVE"   => 0xB6, "CLOAD"   => 0xB7,

    "RANDOM"  => 0xC0, "DEGREE"  => 0xC1, "RADIAN"  => 0xC2, "GRAD"    => 0xC3,
    "BEEP"    => 0xC4, "WAIT"    => 0xC5, "GOTO"    => 0xC6, "TRON"    => 0xC7,
    "TROFF"   => 0xC8, "CLEAR"   => 0xC9, "USING"   => 0xCA, "DIM"     => 0xCB,
    "CALL"    => 0xCC, "POKE"    => 0xCD,

    "TO"      => 0xD0, "STEP"    => 0xD1, "THEN"    => 0xD2, "ON"      => 0xD3,
    "IF"      => 0xD4, "FOR"     => 0xD5, "LET"     => 0xD6, "REM"     => 0xD7,
    "END"     => 0xD8, "NEXT"    => 0xD9, "STOP"    => 0xDA, "READ"    => 0xDB,
    "DATA"    => 0xDC, "PAUSE"   => 0xDD, "PRINT"   => 0xDE, "INPUT"   => 0xDF,

    "GOSUB"   => 0xE0, "AREAD"   => 0xE1, "LPRINT"  => 0xE2, "RETURN"  => 0xE3,
    "RESTORE" => 0xE4,
);

my @TOKENS_DESC = sort {
       length($b) <=> length($a)
    || $a cmp $b
} keys %TOKEN_TO_BYTE;

sub encode_s1_basic_text {
    my ($text, $filename) = @_;
    die "encode_s1_basic_text: text is undefined\n" unless defined $text;
    die "encode_s1_basic_text: filename is undefined\n" unless defined $filename;

    my @lines = split /\r?\n/, $text;
    my @body;

    for my $src_line (@lines) {
        next if $src_line =~ /^\s*$/;

        my ($line_no, $stmt) = _parse_source_line($src_line);
        my @stmt_bytes = _encode_statement($stmt);

        my $line_len = scalar(@stmt_bytes) + 1;  # + 0D
        die "line length too large at line $line_no\n" if $line_len > 255;

        push @body,
            (($line_no >> 8) & 0xFF),
            ($line_no & 0xFF),
            $line_len,
            @stmt_bytes,
            0x0D;
    }

    my @out;

    # header: 07 + reversed filename(7 bytes) + F5 + checksum
    push @out, 0x07;
    my @name_rev = _encode_reversed_name_7($filename);
    push @out, @name_rev;
    push @out, 0xF5;

    my $hdr_ck = PCWAV::Common::checksum_s1_logical(@name_rev, 0xF5);
    push @out, PCWAV::Common::nibswap($hdr_ck);

    # body を 120バイト chunk に分割
    my @chunks;
    for (my $pos = 0; $pos < @body; $pos += 120) {
        my $end = $pos + 119;
        $end = $#body if $end > $#body;
        push @chunks, [ @body[$pos .. $end] ];
    }

    # full chunk は checksum 付きで出力
    for (my $i = 0; $i < @chunks - 1; $i++) {
        my @chunk = @{ $chunks[$i] };
        my @chunk_swapped = map { PCWAV::Common::nibswap($_) } @chunk;

        my $sum = PCWAV::Common::checksum_s1_logical(@chunk_swapped);
        my $sum_out = PCWAV::Common::nibswap($sum);

        push @out, @chunk_swapped;
        push @out, $sum_out;
    }

    # 最後の chunk は checksum なしで出力
    my @last_chunk_logical = @{ $chunks[-1] };
    my @last_chunk_swapped = map { PCWAV::Common::nibswap($_) } @last_chunk_logical;

    push @out, @last_chunk_swapped;


    # tail checksum = last_chunk + first FF
    my $tail_sum = _checksum_s1_basic_tail(@last_chunk_logical, 0xFF);
    my $tail_out = PCWAV::Common::nibswap($tail_sum);

    # terminator
    push @out, 0xFF, 0xFF, $tail_out;

    return pack('C*', @out);
}

sub _parse_source_line {
    my ($line) = @_;

    $line =~ s/^\s+//;

    die "line does not start with line number: $line\n"
        unless $line =~ /^(\d+)(?::|[ \t])(.*)$/;

    my $line_no = int($1);
    my $stmt    = $2;

    die "line number out of range: $line_no\n"
        if $line_no < 1 || $line_no > 65279;

    return ($line_no, $stmt);
}

sub _encode_statement {
    my ($stmt) = @_;
    my @out;

    my $i = 0;
    my $len = length($stmt);
    my $in_quote = 0;
    my $after_rem = 0;

    while ($i < $len) {
        my $ch = substr($stmt, $i, 1);

        # quote mode
        if ($in_quote) {
            push @out, encode_text_for_s1($ch);
            $in_quote = 0 if $ch eq '"';
            $i++;
            next;
        }

        # REM text mode
        if ($after_rem) {
            push @out, encode_text_for_s1($ch);
            $i++;
            next;
        }

        # quote start
        if ($ch eq '"') {
            push @out, encode_text_for_s1($ch);
            $in_quote = 1;
            $i++;
            next;
        }

        # spaces/tabs outside quote/REM are ignored
        if ($ch =~ /[ \t]/) {
            $i++;
            next;
        }

        # try token match
        my $matched = 0;
        for my $tok (@TOKENS_DESC) {
            my $tlen = length($tok);
            next if $i + $tlen > $len;

            my $frag = substr($stmt, $i, $tlen);
            next unless uc($frag) eq $tok;
            next unless _is_token_boundary($stmt, $i, $tlen, $tok);

            push @out, $TOKEN_TO_BYTE{$tok};
            $i += $tlen;
            $matched = 1;

            if ($tok eq 'REM') {
                # REM直後の区切り用スペース/タブを1個だけ吸収
                if ($i < $len) {
                    my $next = substr($stmt, $i, 1);
                    if ($next =~ /[ \t]/) {
                        $i++;
                    }
                }
                $after_rem = 1;
            }
            last;
        }
        next if $matched;

        my @bytes = encode_text_for_s1($ch);
        push @out, @bytes;
        $i++;
    }

    die "unterminated double quote in statement: $stmt\n" if $in_quote;

    return @out;
}

sub _is_token_boundary {
    my ($stmt, $pos, $tlen, $tok) = @_;

    my $prev = $pos > 0 ? substr($stmt, $pos - 1, 1) : '';
    my $next = ($pos + $tlen < length($stmt)) ? substr($stmt, $pos + $tlen, 1) : '';

    # 文・命令系は連結していても token 優先
    my %always_ok = map { $_ => 1 } qw(
        GOTO GOSUB IF FOR TO STEP THEN ON LET REM PRINT INPUT READ DATA
        NEXT STOP RETURN RESTORE PAUSE WAIT DIM CALL POKE CLEAR RANDOM
        TRON TROFF RUN NEW CONT PASS LIST LLIST CSAVE CLOAD AREAD LPRINT
    );

    return 1 if $always_ok{$tok};

    # 関数系・短い予約語は単語境界を見る
    my $prev_ok = ($prev eq '' || $prev !~ /[A-Za-z0-9\$]/);
    my $next_ok = ($next eq '' || $next !~ /[A-Za-z0-9\$]/);

    return $prev_ok && $next_ok;
}

sub _encode_reversed_name_7 {
    my ($name) = @_;
    my @chars = split //, $name;

    die "filename too long for s1 basic: $name\n" if @chars > 7;

    for my $c (@chars) {
        my $o = ord($c);
        die sprintf("invalid filename char 0x%02X\n", $o)
            if $o < 0x20 || $o > 0x7E;
    }

    # 7文字未満は後ろに 00 埋め → reverse 時に先頭側へ来る
    my @pad  = map { "\x00" } (1 .. (7 - @chars));
    my @full = (@chars, @pad);
    my @rev  = reverse @full;

    return map { ord($_) } @rev;
}

# tail checksum (S1 BASIC):
#
# ・120バイトchunk:
#   - nibble-swap後のデータに対して checksum を計算
#
# ・last chunk（120未満）:
#   - chunk内checksumは付かない
#   - tail checksum は「論理データ（未swap）」で計算する
#
# ・計算方法:
#   - 各byteを upper/lower nibble に分解して単純加算
#   - キャリー補正は行わない（単純 mod 256）
#   - 最後に 0xFF を加算
#
# ・出力:
#   - nibble swap して末尾に格納（FF FF の後ろ）
#
# ※ 注意:
#   chunk checksum と tail checksum では
#   「swap前/後」と「加算方法」が異なるので混同しないこと
sub _checksum_s1_basic_tail {
    my (@bytes) = @_;
    my $sum = 0;

    for my $b (@bytes) {
        # 上位ニブルを先に加算
        my $tmp = $sum + (($b & 0xF0) >> 4);
        if ($tmp > 0xFF) {
            ++$tmp;
            $tmp &= 0xFF;
        }

        # そのあと下位ニブルを加算
        $sum = ($tmp + ($b & 0x0F)) & 0xFF;
    }

    return $sum;
}
sub _checksum_simple_nibbles {
    my (@bytes) = @_;
    my $sum = 0;
    for my $b (@bytes) {
        $sum = ($sum + ($b & 0x0F) + (($b >> 4) & 0x0F)) & 0xFF;
    }
    return $sum;
}

sub _checksum_carry_each_nibble {
    my (@bytes) = @_;
    my $sum = 0;

    for my $b (@bytes) {
        $sum += ($b & 0x0F);
        $sum = ($sum + 1) & 0xFF if $sum > 0xFF;

        $sum += (($b >> 4) & 0x0F);
        $sum = ($sum + 1) & 0xFF if $sum > 0xFF;
    }
    return $sum & 0xFF;
}

sub _checksum_common_style {
    my (@bytes) = @_;
    return PCWAV::Common::checksum_s1_logical(@bytes);
}

1;