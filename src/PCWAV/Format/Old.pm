package PCWAV::Format::Old;
use strict;
use warnings;
use PCWAV::Common ();

our $CHUNK_SIZE = 8;

sub chunk_size {
    return $CHUNK_SIZE;
}

sub build_basic_header {
    my (%opt) = @_;

    my $filename = _normalize_filename($opt{filename} // '');
    my $file_type = $opt{password} ? 0x21 : 0x20;   # 論理値
    # raw上では nibswap されて 0x12 / 0x02 になる

    return (
        $file_type,
        @{$filename},
        0xF5,
    );
}

sub build_binary_header {
    my (%opt) = @_;

    my $filename   = _normalize_filename($opt{filename} // '');
    my $start_addr = $opt{start_addr};
    my $end_offset = $opt{end_offset};

    die "build_binary_header: start_addr is required\n"
        unless defined $start_addr;
    die "build_binary_header: end_offset is required\n"
        unless defined $end_offset;

    return (
        0x26,                  # 論理値。raw上では 0x62
        @{$filename},
        0xF5,
        0x00, 0x00, 0x00, 0x60,
        ($start_addr >> 8) & 0xFF,
        $start_addr & 0xFF,
        ($end_offset >> 8) & 0xFF,
        $end_offset & 0xFF,
    );
}

sub wrap_basic_payload {
    my (%opt) = @_;
    my @header = build_basic_header(%opt);
    my @body   = _to_bytes($opt{body});
    my @all    = (@header, @body);

    return _pack_old_stream(@all);
}

sub wrap_binary_payload {
    my (%opt) = @_;
    my @header = build_binary_header(%opt);
    my @body   = _to_bytes($opt{body});
    my @all    = (@header, @body);

    return _pack_old_stream(@all);
}

sub unwrap_payload {
    my ($raw) = @_;
    my @raw = _to_bytes($raw);
    my @logical = map { PCWAV::Common::nibswap($_) } @raw;
    my @stream  = _remove_old_checksums(@logical);

    die "unwrap_payload: empty stream\n" unless @stream;

    my $type = shift @stream;

    if ($type == 0x20 || $type == 0x21) {
        my @filename = splice(@stream, 0, 7);
        my $f5 = shift @stream;
        die sprintf("unwrap_payload: invalid BASIC header terminator %02X\n", $f5)
            unless defined $f5 && $f5 == 0xF5;

        return {
            kind      => 'basic',
            password  => ($type == 0x21 ? 1 : 0),
            type      => $type,
            filename  => _decode_filename(@filename),
            body_bytes => \@stream,
        };
    }
    elsif ($type == 0x26) {
        my @filename = splice(@stream, 0, 7);
        my $f5 = shift @stream;
        die sprintf("unwrap_payload: invalid BINARY header terminator %02X\n", $f5)
            unless defined $f5 && $f5 == 0xF5;

        my @reserved = splice(@stream, 0, 4);
        my $start_hi = shift @stream;
        my $start_lo = shift @stream;
        my $off_hi   = shift @stream;
        my $off_lo   = shift @stream;

        die "unwrap_payload: truncated binary metadata\n"
            unless defined $off_lo;

        my $start_addr = ($start_hi << 8) | $start_lo;
        my $end_offset = ($off_hi   << 8) | $off_lo;

        return {
            kind       => 'binary',
            type       => $type,
            filename   => _decode_filename(@filename),
            reserved   => \@reserved,
            start_addr => $start_addr,
            end_offset => $end_offset,
            body_bytes => \@stream,
        };
    }
    else {
        die sprintf("unwrap_payload: unknown OLD logical type %02X\n", $type);
    }
}

sub _pack_old_stream {
    my (@logical) = @_;

    my @with_sum = _insert_old_checksums(@logical);
    #my @raw      = map { PCWAV::Common::nibswap($_) } @with_sum;

    #return wantarray ? @raw : pack('C*', @raw);
    
    # OLD の WAV 化では encode_byte_old() 側で nibble 順が効くので、
    # ここでは nibswap しない
    return wantarray ? @with_sum : pack('C*', @with_sum);
}

sub _insert_old_checksums {
    my (@bytes) = @_;
    my @out;

    while (@bytes >= $CHUNK_SIZE) {
        my @chunk = splice(@bytes, 0, $CHUNK_SIZE);
        my $sum   = PCWAV::Common::checksum_old_logical(@chunk);
        push @out, @chunk, $sum;
    }

    push @out, @bytes;   # 端数には checksum なし
    return @out;
}

sub _remove_old_checksums {
    my (@bytes) = @_;
    my @out;

    while (@bytes > $CHUNK_SIZE) {
        last if @bytes <= $CHUNK_SIZE;

        if (@bytes >= $CHUNK_SIZE + 1) {
            my @chunk = splice(@bytes, 0, $CHUNK_SIZE);
            if (@bytes > 0) {
                my $sum  = shift @bytes;
                my $want = PCWAV::Common::checksum_old_logical(@chunk);
                die sprintf(
                    "OLD checksum mismatch: got=%02X want=%02X\n",
                    $sum, $want
                ) if $sum != $want;
            }
            push @out, @chunk;
        }
    }

    push @out, @bytes;
    return @out;
}

sub _normalize_filename {
    my ($name) = @_;
    $name = uc($name // '');
    $name =~ s/\.[^.]+$//;
    $name =~ s/[^A-Z0-9]//g;
    $name = substr($name, 0, 7);
    $name .= '0' x (7 - length($name));

    my @bytes = map { _filename_char_to_code($_) } split //, $name;
    return \@bytes;
}

sub _decode_filename {
    my (@bytes) = @_;
    my $name = join '', map { _filename_code_to_char($_) } @bytes;
    $name =~ s/0+$//;
    return $name;
}

sub _filename_char_to_code {
    my ($ch) = @_;
    return 0x40 + ord($ch) - ord('0') if $ch ge '0' && $ch le '9';
    return 0x51 + ord($ch) - ord('A') if $ch ge 'A' && $ch le 'Z';
    die "invalid OLD filename char: $ch\n";
}

sub _filename_code_to_char {
    my ($b) = @_;
    return chr(ord('0') + ($b - 0x40)) if $b >= 0x40 && $b <= 0x49;
    return chr(ord('A') + ($b - 0x51)) if $b >= 0x51 && $b <= 0x6A;
    return '?';
}

sub _to_bytes {
    my ($v) = @_;
    return () unless defined $v;
    return @$v if ref($v) eq 'ARRAY';
    return unpack('C*', $v);
}

1;