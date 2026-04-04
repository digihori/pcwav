package PCWAV::Basic::OldDecode;
use strict;
use warnings;
use PCWAV::Format::Old ();

my %TOKEN = (
    0x11 => ' ', 0x12 => '"', 0x13 => '?', 0x14 => '!', 0x15 => '#',
    0x16 => '%', 0x17 => '\\', 0x18 => '$', 0x1B => ',', 0x1C => ';',
    0x1D => ':', 0x1E => '@', 0x1F => '&',

    0x30 => '(', 0x31 => ')', 0x32 => '>', 0x33 => '<', 0x34 => '=',
    0x35 => '+', 0x36 => '-', 0x37 => '*', 0x38 => '/', 0x39 => '^',

    0x40 => '0', 0x41 => '1', 0x42 => '2', 0x43 => '3', 0x44 => '4',
    0x45 => '5', 0x46 => '6', 0x47 => '7', 0x48 => '8', 0x49 => '9',
    0x4A => '.',

    0x51 => 'A', 0x52 => 'B', 0x53 => 'C', 0x54 => 'D', 0x55 => 'E',
    0x56 => 'F', 0x57 => 'G', 0x58 => 'H', 0x59 => 'I', 0x5A => 'J',
    0x5B => 'K', 0x5C => 'L', 0x5D => 'M', 0x5E => 'N', 0x5F => 'O',
    0x60 => 'P', 0x61 => 'Q', 0x62 => 'R', 0x63 => 'S', 0x64 => 'T',
    0x65 => 'U', 0x66 => 'V', 0x67 => 'W', 0x68 => 'X', 0x69 => 'Y',
    0x6A => 'Z',

    0x7D => 'ASC', 0x7E => 'VAL', 0x7F => 'LEN',

    0x81 => 'AND', 0x82 => '>=', 0x83 => '<=', 0x84 => '<>',
    0x85 => 'OR',  0x86 => 'NOT', 0x87 => 'SQR',
    0x88 => 'CHR$', 0x89 => 'COM$', 0x8A => 'INKEY$',
    0x8B => 'STR$', 0x8C => 'LEFT$', 0x8D => 'RIGHT$', 0x8E => 'MID$',

    0x90 => 'TO', 0x91 => 'STEP', 0x92 => 'THEN', 0x93 => 'RANDOM',
    0x95 => 'WAIT', 0x96 => 'ERROR', 0x99 => 'KEY', 0x9B => 'SETCOM',
    0x9E => 'ROM', 0x9F => 'LPRINT',

    0xA0 => 'SIN', 0xA1 => 'COS', 0xA2 => 'TAN', 0xA3 => 'ASN',
    0xA4 => 'ACS', 0xA5 => 'ATN', 0xA6 => 'EXP', 0xA7 => 'LN',
    0xA8 => 'LOG', 0xA9 => 'INT', 0xAA => 'ABS', 0xAB => 'SGN',
    0xAC => 'DEG', 0xAD => 'DMS', 0xAE => 'RND', 0xAF => 'PEEK',

    0xB0 => 'RUN', 0xB1 => 'NEW', 0xB2 => 'MEM', 0xB3 => 'LIST',
    0xB4 => 'CONT', 0xB5 => 'DEBUG', 0xB6 => 'CSAVE', 0xB7 => 'CLOAD',
    0xB8 => 'MARGE', 0xB9 => 'TRON', 0xBA => 'TROFF', 0xBB => 'PASS',
    0xBC => 'LLIST', 0xBD => 'PI', 0xBE => 'OUTSTAT', 0xBF => 'INSTAT',

    0xC0 => 'GRAD', 0xC1 => 'PRINT', 0xC2 => 'INPUT', 0xC3 => 'RADIAN',
    0xC4 => 'DEGREE', 0xC5 => 'CLEAR', 0xC9 => 'CALL', 0xCA => 'DIM',
    0xCB => 'DATA', 0xCC => 'ON', 0xCD => 'OFF', 0xCE => 'POKE',
    0xCF => 'READ',

    0xD0 => 'IF', 0xD1 => 'FOR', 0xD2 => 'LET', 0xD3 => 'REM',
    0xD4 => 'END', 0xD5 => 'NEXT', 0xD6 => 'STOP', 0xD7 => 'GOTO',
    0xD8 => 'GOSUB', 0xD9 => 'CHAIN', 0xDA => 'PAUSE', 0xDB => 'BEEP',
    0xDC => 'AREAD', 0xDD => 'USING', 0xDE => 'RETURN', 0xDF => 'RESTORE',
);

my %SPACE_AROUND_TOKENS = map { $_ => 1 } qw(
    TO STEP THEN ON AND OR
);

my %SPACE_AFTER_TOKENS = map { $_ => 1 } qw(
    RUN NEW MEM LIST CONT DEBUG CSAVE CLOAD MARGE TRON TROFF PASS LLIST PI
    OUTSTAT INSTAT GRAD PRINT INPUT RADIAN DEGREE CLEAR CALL DIM DATA ON OFF
    POKE READ IF FOR LET REM END NEXT STOP GOTO GOSUB CHAIN PAUSE BEEP AREAD
    USING RETURN RESTORE ASC VAL LEN NOT SQR CHR$ COM$ INKEY$ STR$ LEFT$
    RIGHT$ MID$ RANDOM WAIT ERROR KEY SETCOM ROM LPRINT SIN COS TAN ASN ACS
    ATN EXP LN LOG INT ABS SGN DEG DMS RND PEEK
);

sub decode_payload {
    my ($raw_or_payload) = @_;

    my $info = PCWAV::Format::Old::unwrap_payload($raw_or_payload);
    die "decode_payload: not OLD BASIC\n"
        unless $info->{kind} && $info->{kind} eq 'basic';

    my $text = decode_body($info->{body_bytes});

    return wantarray ? ($text, $info) : $text;
}

sub decode_body {
    my ($body) = @_;
    my @b = _to_bytes($body);

    my $pos = 0;
    my @lines;

    while ($pos < @b) {
        my $cur = $b[$pos];
        last if defined $cur && $cur == 0xF0;

        die "decode_body: truncated before line header\n"
            if $pos + 1 >= @b;

        my $line_no = _decode_line_number_bcd($b[$pos], $b[$pos + 1]);
        $pos += 2;

        my @line_bytes;
        while ($pos < @b) {
            my $c = $b[$pos++];
            last if $c == 0x00;
            push @line_bytes, $c;
        }

        #my @items = _decode_line_items(\@line_bytes);
        #my $stmt  = _format_items(@items);
        my $stmt = _decode_line_items(\@line_bytes);

        push @lines, sprintf('%d:%s', $line_no, $stmt);
    }

    return join('', map { "$_\n" } @lines);
}

sub _decode_line_items {
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
            if ($c == 0x12) {
                $in_quote = 0;
            }
            next;
        }

        if ($c == 0x12) {
            push @items, { type => 'text', value => '"' };
            $in_quote = 1;
            next;
        }

        # 文字コード領域
        if (($c >= 0x11 && $c <= 0x1F) || ($c >= 0x30 && $c <= 0x6A)) {
            push @items, { type => 'text', value => _decode_text_char($c) };
            next;
        }

        my $tok = exists $TOKEN{$c} ? $TOKEN{$c} : undef;
        if (!defined $tok) {
            push @items, { type => 'text', value => sprintf('\\x%02X', $c) };
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
        my $prev = $i > 0        ? $items[$i - 1] : undef;
        my $next = $i < $#items  ? $items[$i + 1] : undef;

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

    # S1Decode.pm と同じ思想で最低限の後処理
    $out =~ s/[ ]+:/:/g;
    $out =~ s/:[ ]+/:/g;
    $out =~ s/[ ]+$//;
    $out =~ s/ {2,}/ /g;
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
    return 1 if $ch =~ /[A-Za-z0-9\$\")]/;

    return 0;
}

sub _need_space_after_token {
    my ($tok, $next) = @_;
    return 0 unless $next;

    return 0 unless $SPACE_AROUND_TOKENS{$tok} || $SPACE_AFTER_TOKENS{$tok};

    if ($next->{type} eq 'text') {
        my $nv = $next->{value};

        return 0 if $nv =~ /^ /;   # すでに空白
        return 0 if $nv =~ /^\(/;  # 関数呼び出し風
    }

    return 1;
}

sub _decode_text_char {
    my ($c) = @_;

    return $TOKEN{$c} if exists $TOKEN{$c} && (
        ($c >= 0x11 && $c <= 0x1F) ||
        ($c >= 0x30 && $c <= 0x6A)
    );

    return sprintf('\\x%02X', $c);
}

sub _decode_line_number_bcd {
    my ($hi, $lo) = @_;

    die sprintf("invalid OLD line header: %02X %02X\n", $hi, $lo)
        unless defined $hi && defined $lo && $hi >= 0xE0 && $hi <= 0xE9;

    my $hundreds = $hi - 0xE0;
    my $tens     = ($lo >> 4) & 0x0F;
    my $ones     = $lo & 0x0F;

    return $hundreds * 100 + $tens * 10 + $ones;
}

sub _to_bytes {
    my ($v) = @_;
    return () unless defined $v;
    return @$v if ref($v) eq 'ARRAY';
    return unpack('C*', $v);
}

1;