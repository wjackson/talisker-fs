use strict;
use warnings;
use feature 'say';
use Test::More;
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

    t::Util::mount_talisker($tfs);

    { # write some points via /io/in

        open my $in_fh, '>', "$mountpoint/io/in";

        # write some points
        say { $in_fh } join( ',', qw(foo 20110405 1.1) );
        say { $in_fh } join( ',', qw(foo 20110407 1.2) );
        say { $in_fh } join( ',', qw(foo 20110408 1.3) );
        say { $in_fh } join( ',', qw(foo 20110406 1.4) );

        close $in_fh;

        # read the points written to /io/in
        my $ts = t::Util::read_ts($talisker, 'foo');

        is_deeply
            $ts,
            {
                tag => 'foo',
                points => [
                    { stamp => 20110405, value => 1.1 },
                    { stamp => 20110406, value => 1.4 },
                    { stamp => 20110407, value => 1.2 },
                    { stamp => 20110408, value => 1.3 },
                ],
            },
            'successfully wrote ts to io/in'
            ;
    }

};

END {
    system("fusermount -u $mountpoint") == 0
       or croak "Failed to unmount tfs from mount point $mountpoint";
}

done_testing();
