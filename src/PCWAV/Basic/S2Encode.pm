package PCWAV::Basic::S2Encode;
use strict;
use warnings;
use PCWAV::Common ();
use PCWAV::TextCodec qw(encode_text_for_s2);

my %TOKEN_TO_BYTE = (
    "RUN"      => 0x10, "NEW"      => 0x11, "CONT"     => 0x12, "PASS"     => 0x13,
    "LIST"     => 0x14, "LLIST"    => 0x15, "CLOAD"    => 0x16, "MERGE"    => 0x17,
    "LOAD"     => 0x18, "RENUM"    => 0x19, "AUTO"     => 0x1A, "DELETE"   => 0x1B,
    "FILES"    => 0x1C, "INIT"     => 0x1D, "CONVERT"  => 0x1E,

    "CSAVE"    => 0x20, "OPEN"     => 0x21, "CLOSE"    => 0x22, "SAVE"     => 0x23,
    "CONSOLE"  => 0x24, "RANDOM"   => 0x25, "DEGREE"   => 0x26, "RADIAN"   => 0x27,
    "GRAD"     => 0x28, "BEEP"     => 0x29, "WAIT"     => 0x2A, "GOTO"     => 0x2B,
    "TRON"     => 0x2C, "TROFF"    => 0x2D, "CLEAR"    => 0x2E, "USING"    => 0x2F,

    "DIM"      => 0x30, "CALL"     => 0x31, "POKE"     => 0x32, "GPRINT"   => 0x33,
    "BASIC"    => 0x36, "TEXT"     => 0x37, "ERASE"    => 0x3A, "LFILES"   => 0x3B,
    "KILL"     => 0x3C, "COPY"     => 0x3D, "NAME"     => 0x3E, "SET"      => 0x3F,

    "LTEXT"    => 0x40, "GRAPH"    => 0x41, "LF"       => 0x42, "CSIZE"    => 0x43,
    "COLOR"    => 0x44, "DEFDBL"   => 0x46, "DEFSNG"   => 0x47,

    "CLS"      => 0x50, "CURSOR"   => 0x51, "TO"       => 0x52, "STEP"     => 0x53,
    "THEN"     => 0x54, "ON"       => 0x55, "IF"       => 0x56, "FOR"      => 0x57,
    "LET"      => 0x58, "REM"      => 0x59, "END"      => 0x5A, "NEXT"     => 0x5B,
    "STOP"     => 0x5C, "READ"     => 0x5D, "DATA"     => 0x5E, "PAUSE"    => 0x5F,

    "PRINT"    => 0x60, "INPUT"    => 0x61, "GOSUB"    => 0x62, "AREAD"    => 0x63,
    "LPRINT"   => 0x64, "RETURN"   => 0x65, "RESTORE"  => 0x66, "CHAIN"    => 0x67,
    "LLINE"    => 0x6A, "RLINE"    => 0x6B, "GLCURSOR"=> 0x6C, "SORGN"    => 0x6D,
    "CROTATE"  => 0x6E, "CIRCLE"   => 0x6F,

    "PAINT"    => 0x70, "OUTPUT"   => 0x71, "APPEND"   => 0x72, "AS"       => 0x73,
    "ARUN"     => 0x74, "AUTOGOTO" => 0x75, "ERROR"    => 0x78,

    "MDF"      => 0x80, "REC"      => 0x81, "POL"      => 0x82, "ROT"      => 0x83,
    "DECI"     => 0x84, "HEX"      => 0x85, "TEN"      => 0x86, "RCP"      => 0x87,
    "SQU"      => 0x88, "CUR"      => 0x89, "HSN"      => 0x8A, "HCS"      => 0x8B,
    "HTN"      => 0x8C, "AHS"      => 0x8D, "AHC"      => 0x8E, "AHT"      => 0x8F,

    "FACT"     => 0x90, "LN"       => 0x91, "LOG"      => 0x92, "EXP"      => 0x93,
    "SQR"      => 0x94, "SIN"      => 0x95, "COS"      => 0x96, "TAN"      => 0x97,
    "INT"      => 0x98, "ABS"      => 0x99, "SGN"      => 0x9A, "DEG"      => 0x9B,
    "DMS"      => 0x9C, "ASN"      => 0x9D, "ACS"      => 0x9E, "ATN"      => 0x9F,

    "RND"      => 0xA0, "AND"      => 0xA1, "OR"       => 0xA2, "NOT"      => 0xA3,
    "PEEK"     => 0xA4, "XOR"      => 0xA5, "PI"       => 0xAE, "MEM"      => 0xAF,

    "EOF"      => 0xB0, "DSKF"     => 0xB1, "LOF"      => 0xB2, "LOC"      => 0xB3,
    "NCR"      => 0xB6, "NRR"      => 0xB7,

    "ERN"      => 0xC0, "ERL"      => 0xC1,

    "ASC"      => 0xD0, "VAL"      => 0xD1, "LEN"      => 0xD2,

    'OPEN$'    => 0xE8, 'INKEY$'   => 0xE9, 'MID$'     => 0xEA, 'LEFT$'    => 0xEB,
    'RIGHT$'   => 0xEC,

    'CHR$'     => 0xF0, 'STR$'     => 0xF1, 'HEX$'     => 0xF2,
);

my @TOKENS_DESC = sort {
       length($b) <=> length($a)
    || $a cmp $b
} keys %TOKEN_TO_BYTE;

# 数値行番号参照に変換したい token
my %LINE_REF_TOKENS = map { $_ => 1 } qw(GOTO GOSUB);

sub encode_s2_basic_text {
    my ($text, $filename, $type) = @_;
    die "encode_s2_basic_text: text is undefined\n" unless defined $text;
    die "encode_s2_basic_text: filename is undefined\n" unless defined $filename;

    $type = defined $type ? $type : 0x27;
    die sprintf("unsupported s2 basic type: %02X\n", $type)
        unless $type == 0x27 || $type == 0x37;

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

    # header: type + reversed filename(7 bytes) + F5 + checksum
    push @out, $type;
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

    # full chunk は checksum 付き
    for (my $i = 0; $i < @chunks - 1; $i++) {
        my @chunk = @{ $chunks[$i] };
        my @chunk_swapped = map { PCWAV::Common::nibswap($_) } @chunk;

        my $sum = PCWAV::Common::checksum_s1_logical(@chunk_swapped);
        my $sum_out = PCWAV::Common::nibswap($sum);

        push @out, @chunk_swapped;
        push @out, $sum_out;
    }

    # last chunk
    my @last_chunk_logical = @{ $chunks[-1] };
    my @last_chunk_swapped = map { PCWAV::Common::nibswap($_) } @last_chunk_logical;
    push @out, @last_chunk_swapped;

    # tail checksum: 現状は S1 と同じ暫定
    my $tail_sum = _checksum_s2_basic_tail(@last_chunk_logical, 0xFF);
    my $tail_out = PCWAV::Common::nibswap($tail_sum);

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
    my $on_pending = 0;   # ON ... GOTO/GOSUB を待っている状態
    my ($stmt) = @_;
    my @out;

    my $i = 0;
    my $len = length($stmt);
    my $in_quote = 0;
    my $after_rem = 0;
    my $last_token = '';
    my $line_ref_mode = '';   # '', 'single', 'list'

    while ($i < $len) {
        my $ch = substr($stmt, $i, 1);

        # quote mode
        if ($in_quote) {
            push @out, encode_text_for_s2($ch);
            $in_quote = 0 if $ch eq '"';
            $i++;
            next;
        }

        # REM text mode
        if ($after_rem) {
            push @out, encode_text_for_s2($ch);
            $i++;
            next;
        }

        # quote start
        if ($ch eq '"') {
            push @out, encode_text_for_s2($ch);
            $in_quote = 1;
            $i++;
            next;
        }

        # 行番号参照モード
        if ($line_ref_mode eq 'single' || $line_ref_mode eq 'list') {

            # 空白は無視
            if ($ch =~ /[ \t]/) {
                $i++;
                next;
            }

            # 数値なら 1F hh ll に変換
            if ($ch =~ /\d/) {
                my $j = $i;
                $j++ while $j < $len && substr($stmt, $j, 1) =~ /\d/;
                my $num = substr($stmt, $i, $j - $i);
                my $line_ref = int($num);

                die "line reference out of range: $line_ref\n"
                    if $line_ref < 0 || $line_ref > 65535;

                push @out, 0x1F, (($line_ref >> 8) & 0xFF), ($line_ref & 0xFF);
                $i = $j;

                if ($line_ref_mode eq 'single') {
                    $line_ref_mode = '';
                }
                next;
            }

            # list モードではカンマ継続
            if ($line_ref_mode eq 'list' && $ch eq ',') {
                push @out, ord(',');
                $i++;
                next;
            }

            # single は解除
            if ($line_ref_mode eq 'single') {
                $line_ref_mode = '';
            }
            # list は維持したまま通常処理へ
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

            push @out, 0xFE, $TOKEN_TO_BYTE{$tok};
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
                $line_ref_mode = '';
            }
            elsif ($tok eq 'ON') {
                $line_ref_mode = '';
                $on_pending = 1;
            }
            elsif ($tok eq 'THEN') {
                $line_ref_mode = 'single';
            }
            elsif ($tok eq 'GOTO' || $tok eq 'GOSUB') {
                if ($on_pending) {
                    $line_ref_mode = 'list';
                } else {
                    $line_ref_mode = 'single';
                }
                $on_pending = 0;
            }
            else {
                $line_ref_mode = '';
            }

            $last_token = $tok;
            last;
        }
        next if $matched;

        my @bytes = encode_text_for_s2($ch);
        push @out, @bytes;
        $i++;
        $last_token = '';
    }

    die "unterminated double quote in statement: $stmt\n" if $in_quote;

    return @out;
}

sub _is_token_boundary {
    my ($stmt, $pos, $tlen, $tok) = @_;

    my $prev = $pos > 0 ? substr($stmt, $pos - 1, 1) : '';
    my $next = ($pos + $tlen < length($stmt)) ? substr($stmt, $pos + $tlen, 1) : '';

    my %always_ok = map { $_ => 1 } qw(
        GOTO GOSUB IF FOR TO STEP THEN ON IF FOR LET REM PRINT INPUT READ DATA
        NEXT STOP RETURN RESTORE PAUSE WAIT DIM CALL POKE CLEAR RANDOM
        TRON TROFF RUN NEW CONT PASS LIST LLIST CSAVE CLOAD MERGE LOAD RENUM AUTO DELETE
        FILES INIT CONVERT OPEN CLOSE SAVE CONSOLE USING BASIC TEXT ERASE LFILES KILL COPY
        NAME SET LTEXT GRAPH LF CSIZE COLOR DEFDBL DEFSNG CLS CURSOR AREAD LPRINT CHAIN
        PAINT OUTPUT APPEND AS ARUN AUTOGOTO ERROR
    );

    return 1 if $always_ok{$tok};

    my $prev_ok = ($prev eq '' || $prev !~ /[A-Za-z0-9\$]/);
    my $next_ok = ($next eq '' || $next !~ /[A-Za-z0-9\$]/);

    return $prev_ok && $next_ok;
}

sub _encode_reversed_name_7 {
    my ($name) = @_;
    my @chars = split //, $name;

    die "filename too long for s2 basic: $name\n" if @chars > 7;

    for my $c (@chars) {
        my $o = ord($c);
        die sprintf("invalid filename char 0x%02X\n", $o)
            if $o < 0x20 || $o > 0x7E;
    }

    my @pad  = map { "\x00" } (1 .. (7 - @chars));
    my @full = (@chars, @pad);
    my @rev  = reverse @full;

    return map { ord($_) } @rev;
}

sub _checksum_s2_basic_tail {
    my (@bytes) = @_;
    my $sum = 0;
    for my $b (@bytes) {
        $sum = ($sum + ($b & 0x0F) + (($b >> 4) & 0x0F)) & 0xFF;
    }
    return $sum;
}

1;