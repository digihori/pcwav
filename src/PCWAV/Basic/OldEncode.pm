package PCWAV::Basic::OldEncode;
use strict;
use warnings;
use PCWAV::Format::Old ();

my %TOKEN = (
    'ASC'    => 0x7D, 'VAL'    => 0x7E, 'LEN'    => 0x7F,

    'AND'    => 0x81, '>='     => 0x82, '<='     => 0x83, '<>' => 0x84,
    'OR'     => 0x85, 'NOT'    => 0x86, 'SQR'    => 0x87,
    'CHR$'   => 0x88, 'COM$'   => 0x89, 'INKEY$' => 0x8A, 'STR$' => 0x8B,
    'LEFT$'  => 0x8C, 'RIGHT$' => 0x8D, 'MID$'   => 0x8E,

    'TO'     => 0x90, 'STEP'   => 0x91, 'THEN'   => 0x92, 'RANDOM' => 0x93,
    'WAIT'   => 0x95, 'ERROR'  => 0x96, 'KEY'    => 0x99, 'SETCOM' => 0x9B,
    'ROM'    => 0x9E, 'LPRINT' => 0x9F,

    'SIN'    => 0xA0, 'COS'    => 0xA1, 'TAN'    => 0xA2, 'ASN' => 0xA3,
    'ACS'    => 0xA4, 'ATN'    => 0xA5, 'EXP'    => 0xA6, 'LN'  => 0xA7,
    'LOG'    => 0xA8, 'INT'    => 0xA9, 'ABS'    => 0xAA, 'SGN' => 0xAB,
    'DEG'    => 0xAC, 'DMS'    => 0xAD, 'RND'    => 0xAE, 'PEEK' => 0xAF,

    'RUN'    => 0xB0, 'NEW'    => 0xB1, 'MEM'    => 0xB2, 'LIST' => 0xB3,
    'CONT'   => 0xB4, 'DEBUG'  => 0xB5, 'CSAVE'  => 0xB6, 'CLOAD' => 0xB7,
    'MARGE'  => 0xB8, 'TRON'   => 0xB9, 'TROFF'  => 0xBA, 'PASS' => 0xBB,
    'LLIST'  => 0xBC, 'PI'     => 0xBD, 'OUTSTAT'=> 0xBE, 'INSTAT' => 0xBF,

    'GRAD'   => 0xC0, 'PRINT'  => 0xC1, 'INPUT'  => 0xC2, 'RADIAN' => 0xC3,
    'DEGREE' => 0xC4, 'CLEAR'  => 0xC5, 'CALL'   => 0xC9, 'DIM' => 0xCA,
    'DATA'   => 0xCB, 'ON'     => 0xCC, 'OFF'    => 0xCD, 'POKE' => 0xCE,
    'READ'   => 0xCF,

    'IF'     => 0xD0, 'FOR'    => 0xD1, 'LET'    => 0xD2, 'REM' => 0xD3,
    'END'    => 0xD4, 'NEXT'   => 0xD5, 'STOP'   => 0xD6, 'GOTO' => 0xD7,
    'GOSUB'  => 0xD8, 'CHAIN'  => 0xD9, 'PAUSE'  => 0xDA, 'BEEP' => 0xDB,
    'AREAD'  => 0xDC, 'USING'  => 0xDD, 'RETURN' => 0xDE, 'RESTORE' => 0xDF,

    ' ' => 0x11, '"' => 0x12, '?' => 0x13, '!' => 0x14, '#' => 0x15,
    '%' => 0x16, '\\' => 0x17, '$' => 0x18, ',' => 0x1B, ';' => 0x1C,
    ':' => 0x1D, '@' => 0x1E, '&' => 0x1F,

    '(' => 0x30, ')' => 0x31, '>' => 0x32, '<' => 0x33, '=' => 0x34,
    '+' => 0x35, '-' => 0x36, '*' => 0x37, '/' => 0x38, '^' => 0x39,

    '0' => 0x40, '1' => 0x41, '2' => 0x42, '3' => 0x43, '4' => 0x44,
    '5' => 0x45, '6' => 0x46, '7' => 0x47, '8' => 0x48, '9' => 0x49,
    '.' => 0x4A,

    'A' => 0x51, 'B' => 0x52, 'C' => 0x53, 'D' => 0x54, 'E' => 0x55,
    'F' => 0x56, 'G' => 0x57, 'H' => 0x58, 'I' => 0x59, 'J' => 0x5A,
    'K' => 0x5B, 'L' => 0x5C, 'M' => 0x5D, 'N' => 0x5E, 'O' => 0x5F,
    'P' => 0x60, 'Q' => 0x61, 'R' => 0x62, 'S' => 0x63, 'T' => 0x64,
    'U' => 0x65, 'V' => 0x66, 'W' => 0x67, 'X' => 0x68, 'Y' => 0x69,
    'Z' => 0x6A,
);

my @TOKENS = sort {
    length($b) <=> length($a) || $a cmp $b
} keys %TOKEN;

sub encode_body {
    my ($text) = @_;
    die "encode_body: text is undefined\n" unless defined $text;

    my @out;
    for my $line (split /\r?\n/, $text) {
        next if $line =~ /^\s*$/;
        push @out, _encode_line($line);
    }

    push @out, 0xF0;
    return wantarray ? @out : pack('C*', @out);
}

sub encode_payload {
    my (%opt) = @_;

    my @body = encode_body($opt{text});

    return PCWAV::Format::Old::wrap_basic_payload(
        filename => ($opt{filename} // ''),
        password => ($opt{password} // 0),
        body     => \@body,
    );
}

sub _encode_line {
    my ($line) = @_;
    my ($line_no, $stmt) = _split_line($line);

    return (
        _encode_line_number_bcd($line_no),
        _encode_statement($stmt),
        0x00,
    );
}

sub _split_line {
    my ($line) = @_;
    $line =~ s/\r$//;
    $line =~ s/^\s+//;

    die "missing OLD line number: [$line]\n"
        unless $line =~ /^(\d{1,3})(.*)$/;

    my $line_no = int($1);
    my $rest    = $2 // '';

    die "OLD line number out of range: $line_no\n"
        if $line_no < 1 || $line_no > 999;

    $rest =~ s/^\s+//;
    $rest =~ s/^://;
    $rest =~ s/^\s+//;

    return ($line_no, $rest);
}

sub _encode_line_number_bcd {
    my ($n) = @_;

    if ($n >= 100) {
        my $s = sprintf('%03d', $n);
        return (
            0xE0 + substr($s, 0, 1),
            (substr($s, 1, 1) << 4) + substr($s, 2, 1),
        );
    }
    elsif ($n >= 10) {
        my $s = sprintf('%02d', $n);
        return (
            0xE0,
            (substr($s, 0, 1) << 4) + substr($s, 1, 1),
        );
    }
    else {
        return (0xE0, $n);
    }
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

        if ($in_quote) {
            my $u = uc($ch);
            die "unsupported OLD char in quote: [$ch]\n"
                unless exists $TOKEN{$u};

            push @out, $TOKEN{$u};
            $in_quote = 0 if $ch eq '"';
            $i++;
            next;
        }

        if ($after_rem) {
            my $u = uc($ch);
            die "unsupported OLD char after REM: [$ch]\n"
                unless exists $TOKEN{$u};

            push @out, $TOKEN{$u};
            $i++;
            next;
        }

        # OLDでは外側の空白は無視
        if ($ch =~ /[ \t]/) {
            $i++;
            next;
        }

        my $matched = 0;
        for my $tok (@TOKENS) {
            my $tlen = length($tok);
            next if $i + $tlen > $len;

            my $frag = substr($stmt, $i, $tlen);
            next unless uc($frag) eq $tok;

            push @out, $TOKEN{$tok};
            $i += $tlen;
            $matched = 1;

            if ($tok eq '"') {
                $in_quote = 1;
            }
            elsif ($tok eq 'REM') {
                $after_rem = 1;
            }

            last;
        }

        next if $matched;

        my $u = uc($ch);
        die "unsupported OLD char: [$ch]\n"
            unless exists $TOKEN{$u};

        push @out, $TOKEN{$u};
        $i++;
    }

    die "unterminated double quote in OLD statement: [$stmt]\n"
        if $in_quote;

    return @out;
}

sub _to_bytes {
    my ($v) = @_;
    return () unless defined $v;
    return @$v if ref($v) eq 'ARRAY';
    return unpack('C*', $v);
}

1;