use strict;
use warnings;
use File::Copy qw(copy);
use File::Path qw(make_path remove_tree);
use File::Basename qw(dirname);
use File::Find;

my $SRC_DIR  = 'src';
my $DIST_DIR = 'dist';

sub wanted_copy {
    my $src_path = $File::Find::name;

    # ディレクトリはコピーしない
    return if -d $src_path;

    # src/ 直下からの相対パスを作る
    my $rel_path = $src_path;
    $rel_path =~ s{^\Q$SRC_DIR\E/?}{};

    my $dst_path = "$DIST_DIR/$rel_path";
    my $dst_dir  = dirname($dst_path);

    make_path($dst_dir) unless -d $dst_dir;

    copy($src_path, $dst_path)
        or die "copy failed: $src_path -> $dst_path: $!";
    print "copied: $src_path -> $dst_path\n";
}

if (-d $DIST_DIR) {
    remove_tree($DIST_DIR) or die "remove_tree failed: $DIST_DIR";
}
make_path($DIST_DIR);

find({ wanted => \&wanted_copy, no_chdir => 1 }, $SRC_DIR);

print "build complete.\n";