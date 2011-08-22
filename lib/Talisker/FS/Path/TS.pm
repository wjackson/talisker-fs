package Talisker::FS::Path::TS;

use Moose;
use namespace::autoclean;
use MooseX::Types::Path::Class qw(File Dir);
use AnyEvent;
use POSIX qw(ENOENT);

with 'Talisker::FS::Path::Role';

sub name { 'ts' }

sub getattr {
    my ($self, $path) = @_;
    my $file = to_File($path);

    return $self->_getattr_dir         if $path eq '/ts';
    return $self->_getattr_file($path) if $self->_tag_exists($file->basename);
    return -ENOENT();
}

sub _tag_exists {
    my ($self, $tag) = @_;

    my $cv = AE::cv;
    $self->th->exists(
        tag => $tag,
        cb  => sub { $cv->send(@_) },
    );
    my ($exists, $err) = $cv->recv;

    confess $err if $err;

    return $exists;
}

sub _getattr_file {
    my ($self, $path) = @_;
    my $file = to_File($path);

    my $tag = $file->basename;

    my $cv = AE::cv;
    $self->th->ts_meta(
        tag => $tag,
        cb  => sub { $cv->send(@_) },
    );
    my ($ts_meta, $err) = $cv->recv;

    my $mode = 0644;
    $mode += 0100 << 9;

    return (
        1,                 # dev
        0,                 # ino
        $mode,             # mode
        1,                 # nlink
        0,                 # uid
        0,                 # gid
        0,                 # rdev
        0,                 # size
        1,                 # atime
        $ts_meta->{mtime}, # mtime
        1,                 # ctime
        1024,              # blksize
        0,                 # blocks
    );
}

sub read {
    my ($self, $path, $size, $offset) = @_;
    my $file = to_File($path);

    my $tag    = $file->basename;
    my $ts_csv = $self->_ts_csv($tag);

    return '' if $offset > 0;

    return substr $ts_csv, $offset, $size;
}

sub _ts_csv {
    my ($self, $tag) = @_;

    my $ts     = $self->_ts($tag);
    my $fields = $self->_fields;

    my @fnames = map { $_->{name} } @{ $fields };
    my $header = join ',', qw(tag stamp), @fnames;
    my @lines  = ($header);

    for my $pt (@{ $ts->{points}}) {
        my @cells = ($tag, $pt->{stamp}, map { $pt->{$_} // '' } @fnames);
        push @lines, join ',', @cells;
    }

    return join("\n", @lines) . "\n";
}

sub _fields {
    my ($self) = @_;

    my $cv = AE::cv;
    $self->th->read_fields( cb => sub { $cv->send(@_) } );
    my ($fields, $err) = $cv->recv;

    confess $err if $err;

    return $fields;
}

sub _ts {
    my ($self, $tag) = @_;

    my $cv = AE::cv;
    $self->th->read(
        tag => $tag,
        cb  => sub { $cv->send(@_) },
    );
    my ($ts, $err) = $cv->recv;

    confess $err if $err;

    return $ts;
}

sub getdir {
    my ($self, $path) = @_;

    my $cv = AE::cv;
    $self->th->tags(cb => sub { $cv->send(@_) } );
    my ($tags, $err) = $cv->recv;

    confess $err if $err;

    return '.', @{ $tags }, 0;
}

__PACKAGE__->meta->make_immutable;
1;
