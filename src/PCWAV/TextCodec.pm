package PCWAV::TextCodec;
use strict;
use warnings;
use Exporter 'import';
use utf8;

our @EXPORT_OK = qw(
    preprocess_escape
    encode_text_for_s1
    encode_text_for_s2
    encode_text_for_old
    decode_text_for_s1
    decode_text_for_s2
    decode_text_for_old
);

our %UNICODE_TO_SJIS_HALFKANA = (
    '｡' => 0xA1, '｢' => 0xA2, '｣' => 0xA3, '､' => 0xA4, '･' => 0xA5,
    'ｦ' => 0xA6, 'ｧ' => 0xA7, 'ｨ' => 0xA8, 'ｩ' => 0xA9, 'ｪ' => 0xAA,
    'ｫ' => 0xAB, 'ｬ' => 0xAC, 'ｭ' => 0xAD, 'ｮ' => 0xAE, 'ｯ' => 0xAF,
    'ｰ' => 0xB0, 'ｱ' => 0xB1, 'ｲ' => 0xB2, 'ｳ' => 0xB3, 'ｴ' => 0xB4,
    'ｵ' => 0xB5, 'ｶ' => 0xB6, 'ｷ' => 0xB7, 'ｸ' => 0xB8, 'ｹ' => 0xB9,
    'ｺ' => 0xBA, 'ｻ' => 0xBB, 'ｼ' => 0xBC, 'ｽ' => 0xBD, 'ｾ' => 0xBE,
    'ｿ' => 0xBF, 'ﾀ' => 0xC0, 'ﾁ' => 0xC1, 'ﾂ' => 0xC2, 'ﾃ' => 0xC3,
    'ﾄ' => 0xC4, 'ﾅ' => 0xC5, 'ﾆ' => 0xC6, 'ﾇ' => 0xC7, 'ﾈ' => 0xC8,
    'ﾉ' => 0xC9, 'ﾊ' => 0xCA, 'ﾋ' => 0xCB, 'ﾌ' => 0xCC, 'ﾍ' => 0xCD,
    'ﾎ' => 0xCE, 'ﾏ' => 0xCF, 'ﾐ' => 0xD0, 'ﾑ' => 0xD1, 'ﾒ' => 0xD2,
    'ﾓ' => 0xD3, 'ﾔ' => 0xD4, 'ﾕ' => 0xD5, 'ﾖ' => 0xD6, 'ﾗ' => 0xD7,
    'ﾘ' => 0xD8, 'ﾙ' => 0xD9, 'ﾚ' => 0xDA, 'ﾛ' => 0xDB, 'ﾜ' => 0xDC,
    'ﾝ' => 0xDD, 'ﾞ' => 0xDE, 'ﾟ' => 0xDF,
);

our %SJIS_HALFKANA_TO_UNICODE = reverse %UNICODE_TO_SJIS_HALFKANA;

sub preprocess_escape {
    my ($text) = @_;
    $text =~ s/\\x([0-9A-Fa-f]{2})/chr(0xE000 + hex($1))/ge;
    return $text;
}

sub _is_escaped_raw_char {
    my ($ch) = @_;
    my $ord = ord($ch);
    return $ord >= 0xE000 && $ord <= 0xE0FF;
}

sub _escaped_raw_char_to_byte {
    my ($ch) = @_;
    return ord($ch) - 0xE000;
}

sub _is_ascii_byte {
    my ($b) = @_;
    return defined($b) && $b >= 0x20 && $b <= 0x7E;
}

sub _is_sjis_halfkana_byte {
    my ($b) = @_;
    return defined($b) && $b >= 0xA1 && $b <= 0xDF;
}

sub _encode_unknown_char_fallback {
    my ($ch) = @_;
    my $ord = ord($ch) & 0xFF;
    return map { ord($_) } split //, sprintf('\\x%02X', $ord);
}

sub encode_text_for_s1 {
    my ($text) = @_;
    my @out;

    for my $ch (split //, $text) {
        my $ord = ord($ch);

        if ($ord >= 0x20 && $ord <= 0x7E) {
            push @out, $ord;
            next;
        }

        if (exists $UNICODE_TO_SJIS_HALFKANA{$ch}) {
            push @out, 0xFE, $UNICODE_TO_SJIS_HALFKANA{$ch};
            next;
        }

        if (_is_escaped_raw_char($ch)) {
            push @out, _escaped_raw_char_to_byte($ch);
            next;
        }

        push @out, _encode_unknown_char_fallback($ch);
    }

    return @out;
}

sub encode_text_for_s2 {
    my ($text) = @_;
    my @out;

    for my $ch (split //, $text) {
        my $ord = ord($ch);

        if ($ord >= 0x20 && $ord <= 0x7E) {
            push @out, $ord;
            next;
        }

        if (exists $UNICODE_TO_SJIS_HALFKANA{$ch}) {
            push @out, $UNICODE_TO_SJIS_HALFKANA{$ch};
            next;
        }

        if (_is_escaped_raw_char($ch)) {
            push @out, _escaped_raw_char_to_byte($ch);
            next;
        }

        push @out, _encode_unknown_char_fallback($ch);
    }

    return @out;
}

sub encode_text_for_old {
    my ($text) = @_;
    my @out;

    for my $ch (split //, $text) {
        my $ord = ord($ch);

        if ($ord >= 0x20 && $ord <= 0x7E) {
            push @out, $ord;
            next;
        }

        if (_is_escaped_raw_char($ch)) {
            push @out, _escaped_raw_char_to_byte($ch);
            next;
        }

        push @out, _encode_unknown_char_fallback($ch);
    }

    return @out;
}

sub decode_text_for_s1 {
    my ($bytes_ref) = @_;
    my @bytes = @$bytes_ref;
    my $out = '';

    while (@bytes) {
        my $b = shift @bytes;

        if ($b == 0xFE) {
            if (@bytes) {
                my $next = shift @bytes;
                if (exists $SJIS_HALFKANA_TO_UNICODE{$next}) {
                    $out .= $SJIS_HALFKANA_TO_UNICODE{$next};
                } else {
                    $out .= sprintf('\\x%02X', $next);
                }
            } else {
                $out .= '\\xFE';
            }
            next;
        }

        if (_is_ascii_byte($b)) {
            $out .= chr($b);
        } else {
            $out .= sprintf('\\x%02X', $b);
        }
    }

    return $out;
}

sub decode_text_for_s2 {
    my ($bytes_ref) = @_;
    my $out = '';

    for my $b (@$bytes_ref) {
        if (_is_ascii_byte($b)) {
            $out .= chr($b);
        } elsif (_is_sjis_halfkana_byte($b)) {
            $out .= $SJIS_HALFKANA_TO_UNICODE{$b} // sprintf('\\x%02X', $b);
        } else {
            $out .= sprintf('\\x%02X', $b);
        }
    }

    return $out;
}

sub decode_text_for_old {
    my ($bytes_ref) = @_;
    my $out = '';

    for my $b (@$bytes_ref) {
        if (_is_ascii_byte($b)) {
            $out .= chr($b);
        } else {
            $out .= sprintf('\\x%02X', $b);
        }
    }

    return $out;
}

1;