package PCWAV::Basic::S2Decode;
use strict;
use warnings;

my %TOKEN_MAP = (
    0x10 => "RUN",     0x11 => "NEW",      0x12 => "CONT",     0x13 => "PASS",
    0x14 => "LIST",    0x15 => "LLIST",    0x16 => "CLOAD",    0x17 => "MERGE",
    0x18 => "LOAD",    0x19 => "RENUM",    0x1A => "AUTO",     0x1B => "DELETE",
    0x1C => "FILES",   0x1D => "INIT",     0x1E => "CONVERT",  0x1F => "\0",

    0x20 => "CSAVE",   0x21 => "OPEN",     0x22 => "CLOSE",    0x23 => "SAVE",
    0x24 => "CONSOLE", 0x25 => "RANDOM",   0x26 => "DEGREE",   0x27 => "RADIAN",
    0x28 => "GRAD",    0x29 => "BEEP",     0x2A => "WAIT",     0x2B => "GOTO",
    0x2C => "TRON",    0x2D => "TROFF",    0x2E => "CLEAR",    0x2F => "USING",

    0x30 => "DIM",     0x31 => "CALL",     0x32 => "POKE",     0x33 => "GPRINT",
    0x34 => "\0",      0x35 => "\0",       0x36 => "BASIC",    0x37 => "TEXT",
    0x38 => "\0",      0x39 => "\0",       0x3A => "ERASE",    0x3B => "LFILES",
    0x3C => "KILL",    0x3D => "COPY",     0x3E => "NAME",     0x3F => "SET",

    0x40 => "LTEXT",   0x41 => "GRAPH",    0x42 => "LF",       0x43 => "CSIZE",
    0x44 => "COLOR",   0x45 => "\0",       0x46 => "DEFDBL",   0x47 => "DEFSNG",
    0x48 => "\0",      0x49 => "\0",       0x4A => "\0",       0x4B => "\0",
    0x4C => "\0",      0x4D => "\0",       0x4E => "\0",       0x4F => "\0",

    0x50 => "CLS",     0x51 => "CURSOR",   0x52 => "TO",       0x53 => "STEP",
    0x54 => "THEN",    0x55 => "ON",       0x56 => "IF",       0x57 => "FOR",
    0x58 => "LET",     0x59 => "REM",      0x5A => "END",      0x5B => "NEXT",
    0x5C => "STOP",    0x5D => "READ",     0x5E => "DATA",     0x5F => "PAUSE",

    0x60 => "PRINT",   0x61 => "INPUT",    0x62 => "GOSUB",    0x63 => "AREAD",
    0x64 => "LPRINT",  0x65 => "RETURN",   0x66 => "RESTORE",  0x67 => "CHAIN",
    0x68 => "\0",      0x69 => "\0",       0x6A => "LLINE",    0x6B => "RLINE",
    0x6C => "GLCURSOR",0x6D => "SORGN",    0x6E => "CROTATE",  0x6F => "CIRCLE",

    0x70 => "PAINT",   0x71 => "OUTPUT",   0x72 => "APPEND",   0x73 => "AS",
    0x74 => "ARUN",    0x75 => "AUTOGOTO", 0x76 => "\0",       0x77 => "\0",
    0x78 => "ERROR",   0x79 => "\0",       0x7A => "\0",       0x7B => "\0",
    0x7C => "\0",      0x7D => "\0",       0x7E => "\0",       0x7F => "\0",

    0x80 => "MDF",     0x81 => "REC",      0x82 => "POL",      0x83 => "ROT",
    0x84 => "DECI",    0x85 => "HEX",      0x86 => "TEN",      0x87 => "RCP",
    0x88 => "SQU",     0x89 => "CUR",      0x8A => "HSN",      0x8B => "HCS",
    0x8C => "HTN",     0x8D => "AHS",      0x8E => "AHC",      0x8F => "AHT",

    0x90 => "FACT",    0x91 => "LN",       0x92 => "LOG",      0x93 => "EXP",
    0x94 => "SQR",     0x95 => "SIN",      0x96 => "COS",      0x97 => "TAN",
    0x98 => "INT",     0x99 => "ABS",      0x9A => "SGN",      0x9B => "DEG",
    0x9C => "DMS",     0x9D => "ASN",      0x9E => "ACS",      0x9F => "ATN",

    0xA0 => "RND",     0xA1 => "AND",      0xA2 => "OR",       0xA3 => "NOT",
    0xA4 => "PEEK",    0xA5 => "XOR",      0xA6 => "\0",       0xA7 => "\0",
    0xA8 => "\0",      0xA9 => "\0",       0xAA => "\0",       0xAB => "\0",
    0xAC => "\0",      0xAD => "\0",       0xAE => "PI",       0xAF => "MEM",

    0xB0 => "EOF",     0xB1 => "DSKF",     0xB2 => "LOF",      0xB3 => "LOC",
    0xB4 => "\0",      0xB5 => "\0",       0xB6 => "NCR",      0xB7 => "NRR",
    0xB8 => "\0",      0xB9 => "\0",       0xBA => "\0",       0xBB => "\0",
    0xBC => "\0",      0xBD => "\0",       0xBE => "\0",       0xBF => "\0",

    0xC0 => "ERN",     0xC1 => "ERL",      0xC2 => "\0",       0xC3 => "\0",
    0xC4 => "\0",      0xC5 => "\0",       0xC6 => "\0",       0xC7 => "\0",
    0xC8 => "\0",      0xC9 => "\0",       0xCA => "\0",       0xCB => "\0",
    0xCC => "\0",      0xCD => "\0",       0xCE => "\0",       0xCF => "\0",

    0xD0 => "ASC",     0xD1 => "VAL",      0xD2 => "LEN",      0xD3 => "\0",
    0xD4 => "\0",      0xD5 => "\0",       0xD6 => "\0",       0xD7 => "\0",
    0xD8 => "\0",      0xD9 => "\0",       0xDA => "\0",       0xDB => "\0",
    0xDC => "\0",      0xDD => "\0",       0xDE => "\0",       0xDF => "\0",

    0xE0 => "\0",      0xE1 => "\0",       0xE2 => "\0",       0xE3 => "\0",
    0xE4 => "\0",      0xE5 => "\0",       0xE6 => "\0",       0xE7 => "\0",
    0xE8 => "OPEN\$",  0xE9 => "INKEY\$",  0xEA => "MID\$",    0xEB => "LEFT\$",
    0xEC => "RIGHT\$", 0xED => "\0",       0xEE => "\0",       0xEF => "\0",

    0xF0 => "CHR\$",   0xF1 => "STR\$",    0xF2 => "HEX\$",    0xF3 => "\0",
    0xF4 => "\0",      0xF5 => "\0",       0xF6 => "\0",       0xF7 => "\0",
    0xF8 => "\0",      0xF9 => "\0",       0xFA => "\0",       0xFB => "\0",
    0xFC => "\0",      0xFD => "\0",       0xFE => "\0",       0xFF => "\0",
);

my %SPACE_AROUND_TOKENS = map { $_ => 1 } qw(
    TO STEP THEN ON AND OR
);

my %SPACE_AFTER_TOKENS = map { $_ => 1 } qw(
    RUN NEW CONT PASS LIST LLIST CSAVE CLOAD
    RANDOM DEGREE RADIAN GRAD BEEP WAIT GOTO TRON TROFF CLEAR
    USING DIM CALL POKE
    IF FOR LET REM END NEXT STOP READ DATA PAUSE PRINT INPUT
    GOSUB AREAD LPRINT RETURN RESTORE
    REC POL ROT DEC HEX TEN RCP SQU CUR HSN HCS HTN AHS AHC AHT
    FAC LN LOG EXP SQR SIN COS TAN INT ABS SGN DEG DMS ASN ACS ATN
    RND NOT ASC VAL LEN PEEK CHR$ STR$ MID$ LEFT$ RIGHT$ INKEY$ PI MEM
);

sub _token_needs_trailing_space {
    my ($tok) = @_;

    my %need_space = map { $_ => 1 } qw(
        RUN NEW CONT PASS LIST LLIST CLOAD MERGE LOAD RENUM AUTO DELETE FILES INIT CONVERT
        CSAVE OPEN CLOSE SAVE CONSOLE RANDOM DEGREE RADIAN GRAD BEEP WAIT GOTO TRON TROFF CLEAR USING
        DIM CALL POKE GPRINT BASIC TEXT ERASE LFILES KILL COPY NAME SET
        LTEXT GRAPH LF CSIZE COLOR DEFDBL DEFSNG
        CLS CURSOR TO STEP THEN ON IF FOR LET REM END NEXT STOP READ DATA PAUSE
        PRINT INPUT GOSUB AREAD LPRINT RETURN RESTORE CHAIN
        PAINT OUTPUT APPEND AS ARUN AUTOGOTO ERROR
    );

    return $need_space{$tok} ? 1 : 0;
}

sub find_and_extract_basic {
    my ($raw_ref) = @_;
    my @b = ref($raw_ref) eq 'ARRAY' ? @$raw_ref : unpack('C*', $raw_ref);

    my $n = scalar @b;
    for (my $i = 0; $i < $n - 10; $i++) {
        my $type_pos;

        if ($b[$i] == 0x27 || $b[$i] == 0x37) {
            $type_pos = $i;
        }
        elsif ($i + 1 < $n && $b[$i] == 0xFF && ($b[$i + 1] == 0x27 || $b[$i + 1] == 0x37)) {
            $type_pos = $i + 1;
        }
        else {
            next;
        }

        next unless $type_pos + 9 < $n;
        next unless $b[$type_pos + 8] == 0xF5;

        my @name_rev = @b[$type_pos + 1 .. $type_pos + 7];
        my $name = _decode_reversed_name_7(@name_rev);

        my $pos = $type_pos + 10;  # type + 7 name + F5 + checksum
        my @body_raw;

        while ($pos < $n) {
            last if $pos + 2 < $n && $b[$pos] == 0xFF && $b[$pos + 1] == 0xFF;

            my $remain = $n - $pos;

            if ($remain >= 123) {
                my @chunk = @b[$pos .. $pos + 119];

                if ($b[$pos + 120] == 0xFF && $b[$pos + 121] == 0xFF) {
                    push @body_raw, @chunk;
                    $pos += 120;
                    next;
                }

                push @body_raw, @chunk;
                $pos += 121;  # 120 data + 1 checksum
                next;
            }

            while ($pos < $n) {
                last if $pos + 2 < $n && $b[$pos] == 0xFF && $b[$pos + 1] == 0xFF;
                push @body_raw, $b[$pos++];
            }
            last;
        }

        next unless $pos + 2 < $n;
        next unless $b[$pos] == 0xFF && $b[$pos + 1] == 0xFF;

        my @body = map { _nibble_swap($_) } @body_raw;

        return {
            offset     => $i,
            type_pos   => $type_pos,
            type       => $b[$type_pos],
            name       => $name,
            body_bytes => \@body,
        };
    }

    die "s2 basic header not found\n";
}

sub decode_s2_basic_body {
    my ($bytes) = @_;
    my @b = ref($bytes) eq 'ARRAY' ? @$bytes : unpack('C*', $bytes);
    my $pos = 0;

    $pos++ if @b && $b[0] == 0xFF;

    my @lines;

    while ($pos < @b) {
        last if $b[$pos] == 0xFF;

        die "truncated before line number\n" if $pos + 2 >= @b;

        my $line_no = ($b[$pos] << 8) | $b[$pos + 1];
        $pos += 2;

        my $line_len = $b[$pos++];
        die "invalid line length at line $line_no\n" if $line_len == 0;
        die "truncated line body at line $line_no\n" if $pos + $line_len - 1 >= @b;

        my @line = @b[$pos .. $pos + $line_len - 1];
        $pos += $line_len;

        my $eol = pop @line;
        die sprintf("line %d missing 0D (got %02X)\n", $line_no, $eol)
            unless $eol == 0x0D;

        my $stmt = _decode_line_tokens(\@line);
        push @lines, sprintf("%d:%s", $line_no, $stmt);
    }

    return join("", map { "$_\n" } @lines);
}

sub decode_s2_basic {
    my ($bytes) = @_;
    return decode_s2_basic_body($bytes);
}

sub _decode_line_tokens {
    my ($bytes_ref) = @_;
    my @bytes = @$bytes_ref;

    my @items;
    my $in_quote = 0;
    my $after_rem = 0;
    my $i = 0;

    while ($i < @bytes) {
        my $c = $bytes[$i];

        if ($after_rem) {
            push @items, { type => 'text', value => _decode_text_char($c) };
            $i++;
            next;
        }

        if ($in_quote) {
            my $ch = _decode_text_char($c);
            push @items, { type => 'text', value => $ch };
            $in_quote = 0 if $c == 0x22;
            $i++;
            next;
        }

        if ($c == 0x22) {
            push @items, { type => 'text', value => '"' };
            $in_quote = 1;
            $i++;
            next;
        }

        # FE xx token
        if ($c == 0xFE) {
            if ($i + 1 >= @bytes) {
                push @items, { type => 'text', value => '?' };
                last;
            }

            my $t = $bytes[$i + 1];
            my $tok = exists $TOKEN_MAP{$t} ? $TOKEN_MAP{$t} : undef;

            if (!defined $tok || $tok eq "\0") {
                push @items, { type => 'text', value => '?' };
                $i += 2;
                next;
            }

            push @items, { type => 'token', value => $tok };
            $after_rem = 1 if $tok eq 'REM';
            $i += 2;
            next;
        }

        # line reference: 1F hh ll
        if ($c == 0x1F) {
            if ($i + 2 >= @bytes) {
                push @items, { type => 'text', value => '?' };
                last;
            }
            my $ref_line = ($bytes[$i + 1] << 8) | $bytes[$i + 2];
            push @items, { type => 'text', value => $ref_line };
            $i += 3;
            next;
        }

        if ($c >= 0x20 && $c <= 0x7E) {
            push @items, { type => 'text', value => _decode_text_char($c) };
            $i++;
            next;
        }

        push @items, { type => 'text', value => '?' };
        $i++;
    }

    return _format_items(@items);
}

sub _format_items {
    my @items = @_;
    my $out = '';

    for (my $i = 0; $i < @items; $i++) {
        my $cur  = $items[$i];
        my $prev = $i > 0       ? $items[$i - 1] : undef;
        my $next = $i < $#items ? $items[$i + 1] : undef;

        if ($cur->{type} eq 'text') {
            $out .= $cur->{value};
            next;
        }

        my $tok = $cur->{value};

        if (_need_space_before_token($prev, $tok)) {
            $out .= ' ' unless $out =~ / $/;
        }

        $out .= $tok;

        if (_need_space_after_token($tok, $next)) {
            $out .= ' ' unless $out =~ / $/;
        }
    }

    # コロンや行末の余計な空白を整理
    $out =~ s/[ ]+:/:/g;
    $out =~ s/:[ ]+/:/g;
    $out =~ s/[ ]+$//;

    # 二重空白を1個に圧縮（文字列/REM中は items化の時点で保持済みなのでここは実質安全）
    $out =~ s/ {2,}/ /g;

    # ただし "( " は "(" に、"; " は ";" に寄せる
    $out =~ s/\( +/(/g;
    $out =~ s/; +/;/g;

    return $out;
}

sub _need_space_before_token {
    my ($prev, $tok) = @_;
    return 0 unless $prev;

    return 1 if $SPACE_AROUND_TOKENS{$tok};

    return 0 unless $prev->{type} eq 'text';
    my $pv = $prev->{value};
    return 0 unless length $pv;

    my $ch = substr($pv, -1, 1);

    # 英数字・$・"・) の直後なら区切る
    return 1 if $ch =~ /[A-Za-z0-9\$\")]|\)/;

    return 0;
}

sub _need_space_after_token {
    my ($tok, $next) = @_;
    return 0 unless $next;

    # まず、空白候補トークンでなければ入れない
    return 0 unless $SPACE_AROUND_TOKENS{$tok} || $SPACE_AFTER_TOKENS{$tok};

    # 次が text の場合、中身を見る
    if ($next->{type} eq 'text') {
        my $nv = $next->{value};

        # すでに空白なら追加しない
        return 0 if $nv =~ /^ /;

        # 次が "(" なら空白を入れない
        return 0 if $nv =~ /^\(/;
    }

    return 1;
}

sub _decode_reversed_name_7 {
    my (@blk) = @_;
    my @chars = reverse @blk;
    my $name = join '', map { ($_ >= 0x20 && $_ <= 0x7E) ? chr($_) : '' } grep { $_ != 0x00 } @chars;
    $name =~ s/\s+$//;
    return $name;
}

sub _decode_text_char {
    my ($c) = @_;
    return chr($c) if $c >= 0x20 && $c <= 0x7E;
    return '?';
}

sub _nibble_swap {
    my ($v) = @_;
    return (($v & 0x0F) << 4) | (($v & 0xF0) >> 4);
}

1;