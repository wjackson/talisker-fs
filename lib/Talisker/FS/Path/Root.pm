package Talisker::FS::Path::Root;

use Moose;
use namespace::autoclean;
use MooseX::Types::Path::Class qw(File Dir);
use POSIX qw(ENOENT);

use Talisker::FS::Path::Info;
use Talisker::FS::Path::IO;
use Talisker::FS::Path::TS;

with 'Talisker::FS::Path::Role';

# /info
has info => (
    accessor   => 'info',
    does       => 'Talisker::FS::Path::Role',
    lazy_build => 1,
);

# /ts
has ts => (
    accessor   => 'ts',
    does       => 'Talisker::FS::Path::Role',
    lazy_build => 1,
);

# /io
has io => (
    accessor   => 'io',
    does       => 'Talisker::FS::Path::Role',
    lazy_build => 1,
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

sub _build_info {
    my ($self) = @_;
    return Talisker::FS::Path::Info->new( talisker => $self->talisker );
}

sub _build_ts {
    my ($self) = @_;
    return Talisker::FS::Path::TS->new( talisker => $self->talisker );
}

sub _build_io {
    my ($self) = @_;
    return Talisker::FS::Path::IO->new( talisker => $self->talisker );
}

sub _build_subdirs {
    my ($self) = @_;

    return [ $self->info, $self->io, $self->ts ];
}

sub _build_subdir_map {
    my ($self) = @_;

    return { map { $_->name, $_ } @{ $self->subdirs } };
}

sub getattr {
    my ($self, $path) = @_;

    return $self->getattr_dir if $path eq '/';

    $self->_dispatch('getattr', $path);
}

sub getdir {
    my ($self, $path) = @_;

    # handle '/'
    return '.', ( map { $_->name } @{ $self->subdirs } ), 0
        if $path eq '/';

    # dispatch everything else to the right subdir
    return $self->_dispatch('getdir', $path);
}

sub open {
    my ($self, $path, @args) = @_;
    $self->_dispatch('open', $path, @args);
}

sub read {
    my ($self, $path, @args) = @_;
    $self->_dispatch('read', $path, @args);
}

sub write {
    my ($self, $path, @args) = @_;
    $self->_dispatch('write', $path, @args);
}

sub close {
    my ($self, $path, @args) = @_;
    $self->_dispatch('close', $path, @args);
}

sub _dispatch {
    my ($self, $method, $path, @args) = @_;

    my $subdir = $self->_pick_subdir($path);

    return -ENOENT() if !defined $subdir;
    return $subdir->$method($path, @args);
}

sub _pick_subdir {
    my ($self, $path) = @_;

    my (undef, $subdir_path) = split m{/}, $path;

    return $self->subdir_map->{$subdir_path};
}

__PACKAGE__->meta->make_immutable;
1;
