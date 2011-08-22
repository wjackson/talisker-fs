package Talisker::FS::Path::Root;

use Moose;
use namespace::autoclean;
use MooseX::Types::Path::Class qw(File Dir);
use POSIX qw(ENOENT);

use Talisker::FS::Path::Info;
use Talisker::FS::Path::TS;

with 'Talisker::FS::Path::Role';

has info => (
    accessor => 'info',
    isa      => 'Object',
    default  => sub { Talisker::FS::Path::Info->new( th => shift->th ) },
    lazy     => 1,
);

has ts => (
    accessor => 'ts',
    isa      => 'Object',
    default  => sub { Talisker::FS::Path::TS->new( th => shift->th ) },
    lazy     => 1,
);

has subdirs => (
    accessor   => 'subdirs',
    isa        => 'ArrayRef',
    lazy_build => 1,
);

has subdir_map => (
    accessor   => 'subdir_map',
    isa        => 'HashRef',
    lazy_build => 1,
);

sub name { '' }

sub _build_subdirs {
    my ($self) = @_;

    return [ $self->info, $self->ts ];
}

sub _build_subdir_map {
    my ($self) = @_;

    return { map { $_->name, $_ } @{ $self->subdirs } };
}

sub getattr {
    my ($self, $path) = @_;

    return $self->_getattr_dir if $path eq '/';

    $self->_dispatch('getattr', $path);
}

sub getdir {
    my ($self, $path) = @_;

    # handle '/'
    return '.', ( map { $_->name } @{ $self->subdirs } ), 0 if $path eq '/';

    # dispatch everything else
    return $self->_dispatch('getdir', $path);
}

sub _dispatch {
    my ($self, $method, $path, @args) = @_;

    my $subdir = $self->_pick_subdir($path);

    return -ENOENT() if !defined $subdir;
    return $subdir->$method($path, @args);
}

sub read {
    my ($self, $path, @args) = @_;
    $self->_dispatch('read', $path, @args);
}

sub _pick_subdir {
    my ($self, $path) = @_;

    my (undef, $subdir_path) = split m{/}, $path;

    return $self->subdir_map->{$subdir_path};
}

__PACKAGE__->meta->make_immutable;
1;
