package Talisker::FS::Path::Info;

use Moose;
use namespace::autoclean;
use MooseX::Types::Path::Class qw(File Dir);
use AnyEvent;
use JSON;
use POSIX qw(ENOENT);

with 'Talisker::FS::Path::Role';

my @INFO_FILES = qw(
    fields
    redis
    tags
);

has file_map => (
    accessor   => 'file_map',
    isa        => 'HashRef',
    lazy_build => 1,
);

sub _build_file_map {
    my ($self) = @_;

    return { map { $_ => 1 } @INFO_FILES };
}

sub getattr {
    my ($self, $path) = @_;
    my $file = to_File($path);

    my $name = $self->name;

    return $self->getattr_dir  if $path eq "/$name";

    return -ENOENT() if !exists $self->file_map->{$file->basename};

    return $self->_dispatch('getattr', $path);
}

sub _getattr_redis {
    my ($self, $path) = @_;

    my $size = length $self->_redis_info_txt;
    my $t    = time;

    return $self->getattr_file(
        size  => $size,
        atime => $t,
        mtime => $t,
        ctime => $t,
    );
}

sub _getattr_fields {
    my ($self, $path) = @_;

    my $size = length $self->_fields_txt;
    my $t    = time;

    return $self->getattr_file(
        size  => $size,
        atime => $t,
        mtime => $t,
        ctime => $t,
    );
}

sub _getattr_tags {
    my ($self, $path) = @_;

    my $size = length $self->_tags_txt;
    my $t    = time;

    return $self->getattr_file(
        size  => $size,
        atime => $t,
        mtime => $t,
        ctime => $t,
    );
}

sub getdir {
    return '.', @INFO_FILES, 0;
}

sub read {
    my ($self, @args) = @_;

    return $self->_dispatch('read', @args);
}

sub _read_redis {
    my ($self, $path, $size, $offset) = @_;

    return substr $self->_redis_info_txt, $offset, $size;
}

sub _redis_info_txt {
    my ($self) = @_;

    my $cv = AE::cv;
    $self->talisker->redis->command(['INFO'], sub { $cv->send(@_) });
    my ($info, $err) = $cv->recv;

    confess $err if $err;

    return $info;
}

sub _read_fields {
    my ($self, $path, $size, $offset) = @_;

    return substr $self->_fields_txt, $offset, $size;
}

sub _fields_txt {
    my ($self) = @_;

    my $fields = $self->_fields;

    return to_json($fields, { pretty => 1 });
}

sub _read_tags {
    my ($self, $path, $size, $offset) = @_;

    return substr $self->_tags_txt, $offset, $size;
}

sub _tags_txt {
    my ($self) = @_;

    my $cv = AE::cv;
    $self->talisker->tags( cb => sub { $cv->send(@_) } );
    my ($tags, $err) = $cv->recv;

    confess $err if $err;

    my $tags_str = join '', map { "$_\n" } @{ $tags };

    return $tags_str;
}

sub _dispatch {
    my ($self, $base_method, $path, @args) = @_;
    my $file = to_File($path);

    my $method = "_${base_method}_" . $file->basename;

    return $self->$method($path, @args);
}

__PACKAGE__->meta->make_immutable;
1;
