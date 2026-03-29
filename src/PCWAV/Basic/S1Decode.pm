package PCWAV::Basic::S1Decode;
use strict;
use warnings;

my %TOKEN_MAP = (
    0x80 => "\0",      0x81 => "REC",     0x82 => "POL",     0x83 => "ROT",
    0x84 => "DEC",     0x85 => "HEX",     0x86 => "TEN",     0x87 => "RCP",
    0x88 => "SQU",     0x89 => "CUR",     0x8A => "HSN",     0x8B => "HCS",
    0x8C => "HTN",     0x8D => "AHS",     0x8E => "AHC",     0x8F => "AHT",

    0x90 => "FAC",     0x91 => "LN",      0x92 => "LOG",     0x93 => "EXP",
    0x94 => "SQR",     0x95 => "SIN",     0x96 => "COS",     0x97 => "TAN",
    0x98 => "INT",     0x99 => "ABS",     0x9A => "SGN",     0x9B => "DEG",
    0x9C => "DMS",     0x9D => "ASN",     0x9E => "ACS",     0x9F => "ATN",

    0xA0 => "RND",     0xA1 => "AND",     0xA2 => "OR",      0xA3 => "NOT",
    0xA4 => "ASC",     0xA5 => "VAL",     0xA6 => "LEN",     0xA7 => "PEEK",
    0xA8 => 'CHR$',    0xA9 => 'STR$',    0xAA => 'MID$',    0xAB => 'LEFT$',
    0xAC => 'RIGHT$',  0xAD => 'INKEY$',  0xAE => 'PI',      0xAF => 'MEM',

    0xB0 => "RUN",     0xB1 => "NEW",     0xB2 => "CONT",    0xB3 => "PASS",
    0xB4 => "LIST",    0xB5 => "LLIST",   0xB6 => "CSAVE",   0xB7 => "CLOAD",
    0xB8 => "\0",      0xB9 => "\0",      0xBA => "\0",      0xBB => "\0",
    0xBC => "\0",      0xBD => "\0",      0xBE => "\0",      0xBF => "\0",

    0xC0 => "RANDOM",  0xC1 => "DEGREE",  0xC2 => "RADIAN",  0xC3 => "GRAD",
    0xC4 => "BEEP",    0xC5 => "WAIT",    0xC6 => "GOTO",    0xC7 => "TRON",
    0xC8 => "TROFF",   0xC9 => "CLEAR",   0xCA => "USING",   0xCB => "DIM",
    0xCC => "CALL",    0xCD => "POKE",    0xCE => "\0",      0xCF => "\0",

    0xD0 => "TO",      0xD1 => "STEP",    0xD2 => "THEN",    0xD3 => "ON",
    0xD4 => "IF",      0xD5 => "FOR",     0xD6 => "LET",     0xD7 => "REM",
    0xD8 => "END",     0xD9 => "NEXT",    0xDA => "STOP",    0xDB => "READ",
    0xDC => "DATA",    0xDD => "PAUSE",   0xDE => "PRINT",   0xDF => "INPUT",

    0xE0 => "GOSUB",   0xE1 => "AREAD",   0xE2 => "LPRINT",  0xE3 => "RETURN",
    0xE4 => "RESTORE", 0xE5 => "\0",      0xE6 => "\0",      0xE7 => "\0",
    0xE8 => "\0",      0xE9 => "\0",      0xEA => "\0",      0xEB => "\0",
    0xEC => "\0",      0xED => "\0",      0xEE => "\0",      0xEF => "\0",

    0xF0 => "\0",      0xF1 => "\0",      0xF2 => "\0",      0xF3 => "\0",
    0xF4 => "\0",      0xF5 => "\0",      0xF6 => "\0",      0xF7 => "\0",
    0xF8 => "\0",      0xF9 => "\0",      0xFA => "\0",      0xFB => "\0",
    0xFC => "\0",      0xFD => "\0",      0xFE => "\0",      0xFF => "\0",
);

my %SPACE_AROUND_TOKENS = map { $_ => 1 } qw(
    TO STEP THEN ON AND OR
);

my %SPACE_AFTER_TOKENS = map { $_ => 1 } qw(
    FOR IF LET REM READ DATA PAUSE PRINT INPUT
    GOSUB AREAD LPRINT RETURN RESTORE USING DIM CALL POKE
    NEXT
);

sub find_and_extract_basic {
    my ($raw_ref) = @_;
    my @b = ref($raw_ref) eq 'ARRAY' ? @$raw_ref : unpack('C*', $raw_ref);

    my $n = scalar @b;
    for (my $i = 0; $i < $n - 12; $i++) {
        next unless $b[$i] == 0xFF;

        my ($name_pos, $body_start);

        # FF 00 ...... F5 CS BODY...
        if ($i + 9 < $n && $b[$i + 1] == 0x00 && $b[$i + 8] == 0xF5) {
            $name_pos   = $i + 1;
            $body_start = $i + 10;
        }
        # FF XX 00 ...... F5 CS BODY...
        elsif ($i + 10 < $n && $b[$i + 2] == 0x00 && $b[$i + 9] == 0xF5) {
            $name_pos   = $i + 2;
            $body_start = $i + 11;
        }
        else {
            next;
        }

        my @name_blk = @b[$name_pos .. $name_pos + 7];
        my $name = _decode_name_block(@name_blk);

        my $end = _find_basic_terminator(\@b, $body_start);
        next if $end < 0;

        my @body_raw = @b[$body_start .. $end - 1];
        my @body     = map { _nibble_swap($_) } @body_raw;

        return {
            offset     => $i,
            name       => $name,
            body_bytes => \@body,
        };
    }

    die "s1 basic header not found\n";
}

sub decode_s1_basic_body {
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

sub decode_s1_basic {
    my ($bytes) = @_;
    return decode_s1_basic_body($bytes);
}

sub _find_basic_terminator {
    my ($bref, $start) = @_;
    my @b = @$bref;
    my $n = @b;

    for (my $i = $start; $i < $n - 2; $i++) {
        if ($b[$i] == 0xFF && $b[$i + 1] == 0xFF) {
            return $i;
        }
    }
    return -1;
}

sub _decode_name_block {
    my (@blk) = @_;
    my @mid = @blk[1 .. 6];
    my @chars = reverse @mid;
    my $name = join '', map { ($_ >= 0x20 && $_ <= 0x7E) ? chr($_) : '' } grep { $_ != 0x00 } @chars;
    $name =~ s/\s+$//;
    return $name;
}

sub _decode_line_tokens {
    my ($bytes_ref) = @_;
    my @bytes = @$bytes_ref;

    my @items;
    my $in_quote  = 0;
    my $after_rem = 0;

    for my $c (@bytes) {
        if ($after_rem) {
            push @items, { type => 'text', value => _decode_text_char($c) };
            next;
        }

        if ($in_quote) {
            my $ch = _decode_text_char($c);
            push @items, { type => 'text', value => $ch };
            if ($c == 0x22) {
                $in_quote = 0;
            }
            next;
        }

        if ($c == 0x22) {
            push @items, { type => 'text', value => '"' };
            $in_quote = 1;
            next;
        }

        if ($c >= 0x20 && $c <= 0x7E) {
            push @items, { type => 'text', value => _decode_text_char($c) };
            next;
        }

        my $tok = exists $TOKEN_MAP{$c} ? $TOKEN_MAP{$c} : undef;
        if (!defined $tok || $tok eq "\0") {
            push @items, { type => 'text', value => '?' };
            next;
        }

        push @items, { type => 'token', value => $tok };
        if ($tok eq 'REM') {
            $after_rem = 1;
        }
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

    # コロンの前後や行末の余計な空白を整理
    $out =~ s/[ ]+:/:/g;
    $out =~ s/:[ ]+/:/g;
    $out =~ s/[ ]+$//;

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

    return 1 if $SPACE_AROUND_TOKENS{$tok};
    return 1 if $SPACE_AFTER_TOKENS{$tok};

    return 0;
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