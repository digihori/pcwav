#!/usr/bin/perl
use strict;
use warnings;
use File::Path qw(make_path);

my %targets = (
    'dist/pcwav-encode.pl' => {
        modules => [
            'src/PCWAV/Common.pm',
            'src/PCWAV/WavWriter.pm',
            'src/PCWAV/Format/S1.pm',
            'src/PCWAV/Binary/S1Encode.pm',
        ],
        main => 'src/encode_main.pl',
    },

    'dist/pcwav-decode.pl' => {
        modules => [
            'src/PCWAV/Common.pm',
            'src/PCWAV/WavReader.pm',
            'src/PCWAV/PcmNormalize.pm',
            'src/PCWAV/RawDecode.pm',
            'src/PCWAV/Binary/S1Decode.pm',
            'src/PCWAV/Basic/S1Decode.pm',
        ],
        main => 'src/decode_main.pl',
    },
);

make_path('dist') unless -d 'dist';

for my $out (sort keys %targets) {
    build_one($out, $targets{$out});
}

sub build_one {
    my ($output, $spec) = @_;

    open my $fh, '>', $output or die "cannot write $output: $!";

    print {$fh} "#!/usr/bin/perl\n";
    print {$fh} "use strict;\nuse warnings;\n\n";

    for my $file (@{$spec->{modules}}) {
        my $text = slurp($file);

        $text =~ s/^\s*use\s+strict\s*;\s*$//mg;
        $text =~ s/^\s*use\s+warnings\s*;\s*$//mg;
        $text =~ s/^\s*use\s+PCWAV::[A-Za-z0-9_:]+\s*;\s*$//mg;

        print {$fh} "# ===== BEGIN $file =====\n";
        print {$fh} $text;
        print {$fh} "\n# ===== END $file =====\n\n";
    }

    my $main = slurp($spec->{main});

    $main =~ s/^\s*use\s+strict\s*;\s*$//mg;
    $main =~ s/^\s*use\s+warnings\s*;\s*$//mg;
    $main =~ s/^\s*use\s+FindBin\b.*?;\s*$//mg;
    $main =~ s/^\s*use\s+lib\b.*?;\s*$//mg;
    $main =~ s/^\s*use\s+PCWAV::[A-Za-z0-9_:]+\s*;\s*$//mg;

    print {$fh} "package main;\n\n";
    print {$fh} "# ===== BEGIN $spec->{main} =====\n";
    print {$fh} $main;
    print {$fh} "\n# ===== END $spec->{main} =====\n";

    close $fh;
    chmod 0755, $output;
    print "built $output\n";
}

sub slurp {
    my ($path) = @_;
    open my $fh, '<', $path or die "cannot read $path: $!";
    local $/;
    my $text = <$fh>;
    close $fh;
    return $text;
}