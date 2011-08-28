package t::Util;
use strict;
use warnings;
use Talisker::Util qw(merge_point);
use Time::HiRes qw(usleep);
use Carp;

use base qw(Exporter);
our @EXPORT = qw(init_talisker mount_talisker);

sub init_talisker {
    my ($talisker, $tsz) = @_;

    $tsz //= [
        {
            tag => 'foo',
            points => [
                { stamp => 20110405, value => 1.1 },
                { stamp => 20110406, value => 1.2 },
                { stamp => 20110407, value => 1.3 },
            ],
        },
        {
            tag => 'bar',
            points => [
                { stamp => 20110405, value => 2.1 },
                { stamp => 20110406, value => 2.2 },
                { stamp => 20110407, value => 2.3 },
            ],
        },
    ];

    my $cv = AE::cv;

    merge_point(
        inputs => $tsz,
        work   => sub {
            my ($ts, $cb) = @_;

            $talisker->write(
                %{ $ts },
                cb => $_[1],
            );
        },
        finished => sub { $cv->send(@_) },
    );

    my (undef, $err) = $cv->recv;

    confess $err if $err;

    return;
}

sub mount_talisker {
    my ($tfs) = @_;

    # mount the ts
    if (fork != 0) { #child
        $tfs->run;
        POSIX::_exit(0); # no END blocks for this PID
    }

    _wait_for_tfs($tfs);

    return;
}

sub _wait_for_tfs {
    my ($tfs) = @_;

    my $mountpoint = $tfs->mountpoint;

    for (1..100) {
        usleep 100;

        return if -d "$mountpoint/info";
    }

    croak "mount point never showed up";
}

sub read_ts {
    my ($talisker, $tag) = @_;

    my $cv = AE::cv;
    $talisker->read(tag => $tag, cb => sub { $cv->send(@_) } );
    my ($ts, $err) = $cv->recv;

    confess $err if $err;

    return $ts;
}

1;
