package PCWAV::Format::Old;
use strict;
use warnings;
use PCWAV::Common ();

our $CHUNK_SIZE = 8;

sub chunk_size {
    return $CHUNK_SIZE;
}

# -----------------------------
# Encode
# -----------------------------

sub wrap_basic_payload {
    my (%opt) = @_;

    my $type     = $opt{password} ? 0x12 : 0x02;   # rawで見える値
    my @filename = @{ _normalize_filename($opt{filename} // '') };  # rawで見える順
    my @body     = _to_bytes($opt{body});

    my @out;

    # type は単独
    push @out, $type;

    # filename(7)+F5 が最初の 8byte ブロック
    my @name_block = (@filename, 0xF5);
    push @out, @name_block;
    push @out, PCWAV::Common::nibswap(
        PCWAV::Common::checksum_old_logical(@name_block)
    );

    # body は論理値 -> raw側表現(nibswap) にしてから 8byte checksum
    my @body_raw = map { PCWAV::Common::nibswap($_) } @body;
    push @out, _insert_old_checksums_cumulative(@body_raw);

    return wantarray ? @out : pack('C*', @out);
}

sub wrap_binary_payload {
    my (%opt) = @_;

    my $start_addr = $opt{start_addr};
    my $end_offset = $opt{end_offset};

    die "wrap_binary_payload: start_addr is required\n"
        unless defined $start_addr;
    die "wrap_binary_payload: end_offset is required\n"
        unless defined $end_offset;

    my $type     = 0x62;  # rawで見える値
    my @filename = @{ _normalize_filename($opt{filename} // '') };
    my @body     = _to_bytes($opt{body});

    my @meta_raw = (
        0x00, 0x00, 0x00, 0x60,
        ($start_addr >> 8) & 0xFF,
        $start_addr & 0xFF,
        ($end_offset >> 8) & 0xFF,
        $end_offset & 0xFF,
    );

    my @out;

    push @out, $type;

    my @name_block = (@filename, 0xF5);
    push @out, @name_block;
    push @out, PCWAV::Common::nibswap(
        PCWAV::Common::checksum_old_logical(@name_block)
    );

    # binary meta も raw のまま 8byte + checksum
    push @out, @meta_raw;
    push @out, PCWAV::Common::nibswap(
        PCWAV::Common::checksum_old_logical(@meta_raw)
    );

    # body は raw側表現にしてから chunk checksum
    my @body_raw = map { PCWAV::Common::nibswap($_) } @body;
    push @out, _insert_old_checksums_cumulative(@body_raw);

    return wantarray ? @out : pack('C*', @out);
}

# -----------------------------
# Decode
# -----------------------------

sub unwrap_payload {
    my ($raw) = @_;
    my @raw = _to_bytes($raw);

    die "unwrap_payload: too short\n" unless @raw >= 10;

    # type は単独
    my $type = shift @raw;

    # filename(7)+F5
    my @name_block = splice(@raw, 0, 8);
    my $name_sum   = shift @raw;

    die "unwrap_payload: truncated OLD filename block\n"
        unless @name_block == 8 && defined $name_sum;

    my @filename = @name_block[0 .. 6];
    my $f5       = $name_block[7];

    die sprintf("unwrap_payload: invalid OLD filename terminator %02X\n", $f5)
        unless $f5 == 0xF5;

    # 実機 raw では filename block 自体はそのまま見え、
    # checksum byte は nibswap された見え方になる
    my $want_name_sum = PCWAV::Common::checksum_old_logical(@name_block);
    my $got_name_sum  = PCWAV::Common::nibswap($name_sum);

    die sprintf("OLD filename checksum mismatch: got=%02X want=%02X\n", $got_name_sum, $want_name_sum)
        if $got_name_sum != $want_name_sum;

    if ($type == 0x02 || $type == 0x12) {
        my @body_logical = _remove_old_checksums_body_stream(@raw);

        return {
            kind       => 'basic',
            password   => ($type == 0x12 ? 1 : 0),
            type       => $type,
            filename   => _decode_filename_raw(@filename),
            body_bytes => \@body_logical,
        };
    }
    elsif ($type == 0x62) {
        die "unwrap_payload: truncated OLD binary metadata\n" unless @raw >= 9;

        my @meta_raw = splice(@raw, 0, 8);
        my $meta_sum = shift @raw;

        my $want_meta_sum = PCWAV::Common::checksum_old_logical(@meta_raw);
        my $got_meta_sum  = PCWAV::Common::nibswap($meta_sum);

        die sprintf("OLD binary meta checksum mismatch: got=%02X want=%02X\n", $got_meta_sum, $want_meta_sum)
            if $got_meta_sum != $want_meta_sum;

        my @reserved = @meta_raw[0 .. 3];
        my $start_addr = ($meta_raw[4] << 8) | $meta_raw[5];
        my $end_offset = ($meta_raw[6] << 8) | $meta_raw[7];

        my @body_logical = _remove_old_checksums_body_stream(@raw);

        return {
            kind       => 'binary',
            type       => $type,
            filename   => _decode_filename_raw(@filename),
            reserved   => \@reserved,
            start_addr => $start_addr,
            end_offset => $end_offset,
            body_bytes => \@body_logical,
        };
    }
    else {
        die sprintf("unwrap_payload: unknown OLD raw type %02X\n", $type);
    }
}

# -----------------------------
# Internal helpers
# -----------------------------

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

sub _insert_old_checksums_cumulative {
    my (@bytes) = @_;
    my @out;

    my $sum = 0;
    my $chunk_no = 0;

    while (@bytes >= $CHUNK_SIZE) {
        my @chunk = splice(@bytes, 0, $CHUNK_SIZE);

        for my $b (@chunk) {
            $sum += ($b & 0xF0) >> 4;
            $sum = ($sum + 1) & 0xFF if $sum > 0xFF;
            $sum = ($sum + ($b & 0x0F)) & 0xFF;
        }

        #print STDERR sprintf(
        #    "ENC CHK #%d chunk=%s sum=%02X\n",
        #    $chunk_no,
        #    join(' ', map { sprintf '%02X', $_ } @chunk),
        #    $sum,
        #);
        push @out, @chunk, PCWAV::Common::nibswap($sum);
        $chunk_no++;
    }

    push @out, @bytes;   # 端数には checksum なし
    return @out;
}

sub _remove_old_checksums_body {
    my (@raw_body) = @_;
    my @out;

    while (@raw_body >= $CHUNK_SIZE + 1) {
        my @chunk_raw = splice(@raw_body, 0, $CHUNK_SIZE);
        my $sum_raw   = shift @raw_body;

        # body chunk は rawでは nibswap 後に見えている。
        # checksum は logical値に対して計算され、保存時に nibswap された値になる。
        my @chunk_logical = map { PCWAV::Common::nibswap($_) } @chunk_raw;
        my $got           = PCWAV::Common::nibswap($sum_raw);
        my $want          = PCWAV::Common::checksum_old_logical(@chunk_logical);

        die sprintf("OLD checksum mismatch: got=%02X want=%02X\n", $got, $want)
            if $got != $want;

        push @out, @chunk_logical;
    }

    # 最後の余りは checksum なし。logical に戻して返す
    push @out, map { PCWAV::Common::nibswap($_) } @raw_body;

    return @out;
}

sub _remove_old_checksums_body_stream {
    my (@raw_body) = @_;

    my @out;

    my $check_sum = 0;
    my $sc        = 0;
    my $sc_next   = 8;

    for my $raw (@raw_body) {
        my $logical = PCWAV::Common::nibswap($raw);

        if ($sc == $sc_next) {
            my $read_sum = $logical;

            die sprintf("OLD checksum mismatch: got=%02X want=%02X\n", $read_sum, $check_sum)
                if $check_sum != $read_sum;

            # 以後も累積のまま次の8byteへ
            $sc_next = $sc + 8;
            next;
        }

        $check_sum += ($logical & 0xF0) >> 4;
        $check_sum = ($check_sum + 1) & 0xFF if $check_sum > 0xFF;
        $check_sum = ($check_sum + ($logical & 0x0F)) & 0xFF;

        $sc++;
        push @out, $logical;
    }

    return @out;
}

sub _normalize_filename {
    my ($name) = @_;
    $name = uc($name // '');
    $name =~ s/\.[^.]+$//;
    $name =~ s/[^A-Z0-9]//g;
    $name = substr($name, 0, 7);

    # 実機 raw では逆順に見える
    my @chars = reverse split //, $name;
    my @bytes = map { _filename_char_to_code($_) } @chars;

    # 空きは 0x00 埋め
    while (@bytes < 7) {
        unshift @bytes, 0x00;
    }

    return \@bytes;
}

sub _decode_filename_raw {
    my (@bytes) = @_;

    my @chars;
    for my $b (@bytes) {
        next if $b == 0x00;
        push @chars, _filename_code_to_char($b);
    }

    return join('', reverse @chars);
}

sub _filename_char_to_code {
    my ($ch) = @_;

    if ($ch ge '0' && $ch le '9') {
        return 0x40 + ord($ch) - ord('0');
    }
    elsif ($ch ge 'A' && $ch le 'Z') {
        return 0x51 + ord($ch) - ord('A');
    }
    else {
        die "invalid OLD filename char: $ch\n";
    }
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