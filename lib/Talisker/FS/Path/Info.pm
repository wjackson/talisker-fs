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

sub name { 'info' }

sub getattr {
    my ($self, $path) = @_;
    my $file = to_File($path);

    return $self->_getattr_dir  if $path eq '/info';
    return $self->_getattr_file if exists $self->file_map->{$file->basename};
    return -ENOENT();
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

    my $cv = AE::cv;
    $self->th->redis->command(['INFO'], sub { $cv->send(@_) });
    my ($info, $err) = $cv->recv;

    confess $err if $err;

    return substr $info, $offset, $size;
}

sub _read_fields {
    my ($self, $path, $size, $offset) = @_;

    my $cv = AE::cv;
    $self->th->read_fields( cb => sub { $cv->send(@_) } );
    my ($fields, $err) = $cv->recv;

    confess $err if $err;

    return substr to_json($fields, { pretty => 1 }), $offset, $size;
}

sub _read_tags {
    my ($self, $path, $size, $offset) = @_;

    my $cv = AE::cv;
    $self->th->tags( cb => sub { $cv->send(@_) } );
    my ($tags, $err) = $cv->recv;

    confess $err if $err;

    my $tags_str = join("\n", @{ $tags }) . "\n";
    return substr $tags_str, $offset, $size;
}

sub _dispatch {
    my ($self, $base_method, $path, @args) = @_;
    my $file = to_File($path);

    my $method = "_${base_method}_" . $file->basename;

    return $self->$method($path, @args);
}

__PACKAGE__->meta->make_immutable;
1;
