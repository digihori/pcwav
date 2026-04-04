package PCWAV::Binary::OldEncode;
use strict;
use warnings;
use PCWAV::Format::Old ();
use PCWAV::WavWriter ();

sub payload_to_pcm {
    my (@payload) = @_;

    my $pcm = '';

    my $lead = PCWAV::WavWriter::w1_old();
    for (1 .. 0x400) {
        $pcm .= $lead;
    }

    for my $b (@payload) {
        $pcm .= PCWAV::WavWriter::encode_byte_old($b);
    }

    return $pcm;
}

sub encode_body {
    my (%opt) = @_;

    my @body = _to_bytes($opt{body});
    if (!@body && exists $opt{bytes}) {
        @body = @{ $opt{bytes} || [] };
    }

    die "encode_body: binary body is empty\n" unless @body;

    return wantarray ? @body : pack('C*', @body);
}

sub encode_payload {
    my (%opt) = @_;

    #my @body = _to_bytes(encode_body(%opt));
    my @body = encode_body(%opt);

    my $start_addr = $opt{start_addr};
    die "encode_payload: start_addr is required\n"
        unless defined $start_addr;

    my $end_offset;
    if (defined $opt{end_offset}) {
        $end_offset = $opt{end_offset};
    } else {
        $end_offset = @body - 1;
    }

    die "encode_payload: body is empty\n" if $end_offset < 0;

    return PCWAV::Format::Old::wrap_binary_payload(
        filename   => ($opt{filename} // ''),
        start_addr => $start_addr,
        end_offset => $end_offset,
        body       => \@body,
    );
}

sub encode_from_dump_lines {
    my (%opt) = @_;
    my $text = $opt{text};
    die "encode_from_dump_lines: text is undefined\n"
        unless defined $text;

    my ($start_addr, @body) = _parse_dump_text($text);

    return encode_payload(
        filename   => ($opt{filename} // ''),
        start_addr => $start_addr,
        body       => \@body,
    );
}

sub _parse_dump_text {
    my ($text) = @_;
    my @body;
    my $start_addr;
    my $next_addr;

    for my $line (split /\r?\n/, $text) {
        next if $line =~ /^\s*$/;
        next if $line =~ /^\s*[#;]/;

        my ($addr_hex, $bytes_part) =
            $line =~ /^\s*([0-9A-Fa-f]{4})\s*:\s*(.*?)\s*(?::\s*[0-9A-Fa-f]{2})?\s*$/;

        die "invalid OLD dump line: [$line]\n"
            unless defined $addr_hex;

        my $addr = hex($addr_hex);
        $start_addr = $addr unless defined $start_addr;

        if (defined $next_addr && $addr != $next_addr) {
            die sprintf(
                "non-contiguous OLD dump line: expected %04X got %04X\n",
                $next_addr, $addr
            );
        }

        my @vals = grep { length($_) } split /\s+/, $bytes_part;
        for my $hx (@vals) {
            die "invalid byte [$hx] in OLD dump line\n"
                unless $hx =~ /^[0-9A-Fa-f]{2}$/;
            push @body, hex($hx);
        }

        $next_addr = $addr + scalar(@vals);
    }

    die "no binary data found in OLD dump text\n"
        unless defined $start_addr && @body;

    return ($start_addr, @body);
}

sub _to_bytes {
    my ($v) = @_;
    return () unless defined $v;
    return @$v if ref($v) eq 'ARRAY';
    return unpack('C*', $v);
}

1;