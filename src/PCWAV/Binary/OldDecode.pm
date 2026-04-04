package PCWAV::Binary::OldDecode;
use strict;
use warnings;
use PCWAV::Format::Old ();

sub decode_payload {
    my ($raw_or_payload) = @_;

    my $info = PCWAV::Format::Old::unwrap_payload($raw_or_payload);
    die "decode_payload: not OLD binary\n"
        unless $info->{kind} && $info->{kind} eq 'binary';

    my @body = _to_bytes($info->{body_bytes});
    my $size = $info->{end_offset} + 1;
    my $end_addr = $info->{start_addr} + $info->{end_offset};

    return {
        kind       => 'binary',
        type       => $info->{type},
        filename   => $info->{filename},
        reserved   => $info->{reserved},
        start_addr => $info->{start_addr},
        end_offset => $info->{end_offset},
        end_addr   => $end_addr,
        size       => $size,
        body_bytes => \@body,
        body       => pack('C*', @body),
    };
}

sub find_and_extract {
    my ($raw_or_payload) = @_;
    return decode_payload($raw_or_payload);
}

sub decode_body {
    my ($body) = @_;
    my @bytes = _to_bytes($body);

    return {
        body_bytes => \@bytes,
        body       => pack('C*', @bytes),
        size       => scalar(@bytes),
    };
}

sub _to_bytes {
    my ($v) = @_;
    return () unless defined $v;
    return @$v if ref($v) eq 'ARRAY';
    return unpack('C*', $v);
}

1;