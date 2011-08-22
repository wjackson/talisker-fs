package Talisker::FS;

use feature ':5.10';
use Moose;
use namespace::autoclean;
use MooseX::Types::Path::Class qw(File Dir);
use MooseX::Types::Moose qw(Bool Str);
use Fuse;
use Talisker;
use Talisker::FS::Path::Root;

my @FUSE_METHODS = qw(
    getattr readlink getdir
    open    read     release
    statfs  flush
);

with 'MooseX::Runnable';
with 'MooseX::Getopt';

has 'mountpoint' => (
    is       => 'ro',
    isa      => Dir,
    required => 1,
    coerce   => 1,
);

has 'mountopts' => (
    is       => 'ro',
    isa      => Str,
    default  => sub { "" },
    required => 0,
);

has 'debug' => (
    init_arg => 'debug',
    reader   => 'is_debug',
    isa      => Bool,
    default  => sub { 0 },
    required => 1,
);

has talisker => (
    is      => 'ro',
    isa     => 'Talisker',
    default => sub { Talisker->new },
    lazy    => 1,
);

has th => (
    is      => 'ro',
    isa     => 'Talisker::Handle',
    default => sub { shift->talisker->handle },
);

has dirs => (
    accessor => 'dirs',
    isa => 'HashRef',
    lazy_build => 1,
);

has root => (
    accessor => 'root',
    isa      => 'Object',
    handles  => \@FUSE_METHODS,
    default  => sub { Talisker::FS::Path::Root->new(th => shift->th) },
    lazy     => 1,
);

sub run {
    my ($self) = @_;

    my $subify = sub {
        my $method = shift;
        return sub { $self->$method(@_) };
    };

    my @method_map = map { $_ => $subify->($_) } @FUSE_METHODS;

    return Fuse::main(
        debug      => $self->is_debug ? 1 : 0,
        mountpoint => $self->mountpoint->stringify,
        mountopts  => $self->mountopts,
        @method_map,
    ) || 0;
}

__PACKAGE__->meta->make_immutable;
1;
