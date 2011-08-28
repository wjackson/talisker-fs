use strict;
use warnings;
use feature 'say';
use Test::More;
use English '-no_match_vars';
use File::Temp qw(tempdir);
use Carp;
use File::Slurp qw(slurp);
use autodie;
use Talisker;
use t::Redis;
use t::Util;

use ok 'Talisker::FS';

my $mountpoint = tempdir( CLEANUP => 1 );

test_redis {
    my $port = shift;

    my $talisker = Talisker->new(port => $port);
    my $tfs      = Talisker::FS->new(
        talisker   => $talisker,
        mountpoint => $mountpoint,
        # debug => 1,
    );

    isa_ok $tfs, 'Talisker::FS';

    # write some example data to talisker
    t::Util::init_talisker($talisker);

    t::Util::mount_talisker($tfs);

    {
        ok -d "$mountpoint/ts/foo", '/ts/foo is a directory';

        is_deeply
            [ glob("$mountpoint/ts/*") ],
            [ ],
            '/ts directory appears to contain no files';

        my $foo_mtime = ( stat("$mountpoint/ts/foo") )[9];

        ok $foo_mtime >= $BASETIME && $foo_mtime <= time,
            '/ts/foo was just modified';

        ok -f "$mountpoint/ts/foo/foo.csv", '/ts/foo/foo.csv is a file';

        my @foo_csv_stat  = stat("$mountpoint/ts/foo/foo.csv");
        my $foo_csv_mtime = $foo_csv_stat[9];
        my $foo_csv_size  = $foo_csv_stat[7];

        ok $foo_csv_mtime >= $BASETIME && $foo_csv_mtime <= time,
            '/ts/foo/foo.csv was just modified';

        ok $foo_csv_size > 0 && $foo_csv_size <= 1024,
            '/ts/foo/foo.csv has a reasonable size';

        my @foo_lines = slurp "$mountpoint/ts/foo/foo.csv", chomp => 1;

        is $foo_lines[0], 'foo,20110405,1.1', 'line 0';
        is $foo_lines[1], 'foo,20110406,1.2', 'line 1';
        is $foo_lines[2], 'foo,20110407,1.3', 'line 2';

        is_deeply
            [ glob("$mountpoint/ts/foo/*") ],
            [ "$mountpoint/ts/foo/foo.csv" ],
            '/ts/foo directory contains the right files';
    }

};

END {
    system("fusermount -u $mountpoint") == 0
       or croak "Failed to unmount tfs from mount point $mountpoint";
}

done_testing();
