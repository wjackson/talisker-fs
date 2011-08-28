use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use Carp;
use File::Slurp qw(slurp);
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
    );

    isa_ok $tfs, 'Talisker::FS';

    mount_talisker($tfs);

    # put some data into talisker
    init_talisker($talisker);

    like slurp("$mountpoint/info/redis"), qr/redis_version:/, 'info/redis';
    like slurp("$mountpoint/info/fields"), qr/value/, 'info/fields';

    is_deeply
        [ slurp("$mountpoint/info/tags", chomp => 1) ],
        [ qw(bar foo) ],
        'info/tags'
};

END {
    system("fusermount -u $mountpoint") == 0
       or croak "Failed to unmount tfs from mount point $mountpoint";
}

done_testing();
