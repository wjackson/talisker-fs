package Talisker::FS::Path::TS;

use Moose;
use namespace::autoclean;
use MooseX::Types::Path::Class qw(File Dir);
use AnyEvent;
use POSIX qw(ENOENT);

with 'Talisker::FS::Path::Role';

sub getattr {
    my ( $self, $path ) = @_;

    my @path = split m{/}, $path;

    return $self->_getattr_top         if @path == 2; # ex: /ts
    return $self->_getattr_dir($path)  if @path == 3; # ex: /ts/foo
    return $self->_getattr_file($path) if @path == 4; # ex: /ts/foo/foo.csv

    return -ENOENT();
}

# /ts
sub _getattr_top {
    my ( $self, $path ) = @_;
    my $file = to_File($path);

    return $self->getattr_dir;
}

# /ts/<some ts>
sub _getattr_dir {
    my ( $self, $path ) = @_;
    my $file = to_File($path);

    my $tag     = $file->basename;
    my $ts_meta = $self->_ts_meta($tag);

    return -ENOENT() if !defined $ts_meta;

    return $self->getattr_dir(
        mtime => $ts_meta->{mtime}
    );
}

# /ts/<some ts>/<some file>
sub _getattr_file {
    my ( $self, $path ) = @_;
    my $file = to_File($path);

    my ($tag, $extension) = split /\./, $file->basename;
    my $ts_meta = $self->_ts_meta($tag);

    return -ENOENT() if !defined $ts_meta;

    my $fields = $self->_fields;

    # todo make this extension based
    my $size   = length $self->_ts_csv($tag);

    return $self->getattr_file(
        mtime => $ts_meta->{mtime},
        size  => $size,
    );
}

sub read {
    my ( $self, $path, $size, $offset ) = @_;
    my $file = to_File($path);

    my ($tag, $extension) = split /\./, $file->basename;

    my $content_method = "_read_${extension}";

    return $self->$content_method($tag, $path, $size, $offset);
}

sub _read_csv {
    my ($self, $tag, $path, $size, $offset) = @_;

    my $ts_csv = $self->_ts_csv($tag);

    return substr $ts_csv, $offset, $size;
}

sub _ts_csv {
    my ( $self, $tag ) = @_;

    my $ts     = $self->_ts($tag);
    my $fields = $self->_fields;

    my @fnames = map { $_->{name} } @{$fields};
    my $header = join ',', qw(tag stamp), @fnames;

    # my @lines  = ($header);
    my @lines = ();

    for my $pt ( @{ $ts->{points} } ) {
        my @cells = ( $tag, $pt->{stamp}, map { $pt->{$_} // '' } @fnames );
        push @lines, join ',', @cells;
    }

    return join( "\n", @lines ) . "\n";
}

# sub _ts_prn {
#     my ( $self, $tag ) = @_;
#
#     my $ts     = $self->_ts($tag);
#     my $fields = $self->_fields;
#
#     my @fnames = map { $_->{name} } @{$fields};
#     my $header = join ',', qw(tag stamp), @fnames;
#
#     # my @lines  = ($header);
#     my @lines = ();
#
#     for my $pt ( @{ $ts->{points} } ) {
#
#         push @lines,
#           join '',
#           map { _pad($_) } $tag,
#           $pt->{stamp},
#           map { $pt->{$_} } @fnames;
#     }
#
#     return join( "\r\n", @lines ) . "\r\n";
# }
#
# sub _pad {
#     my ( $txt, $width ) = @_;
#
#     $width //= 20;
#
#     return sprintf "%-${width}s", $txt // '';
# }

sub _ts {
    my ( $self, $tag ) = @_;

    my $cv = AE::cv;
    $self->talisker->read(
        tag => $tag,
        cb  => sub { $cv->send(@_) },
    );
    my ( $ts, $err ) = $cv->recv;

    confess $err if $err;

    return $ts;
}

sub _ts_meta {
    my ( $self, $tag ) = @_;

    my $cv = AE::cv;

    $self->talisker->ts_meta(
        tag => $tag,
        cb  => sub { $cv->send(@_) },
    );

    my ( $ts_meta, $err ) = $cv->recv;

    confess $err if $err;

    return if keys(%{ $ts_meta }) == 0;
    return $ts_meta;
}

sub _tag_exists {
    my ( $self, $path ) = @_;

    my $file = to_File($path);
    my ($tag) = split /\./, $file->basename;

    my $cv = AE::cv;
    $self->talisker->exists(
        tag => $tag,
        cb  => sub { $cv->send(@_) },
    );
    my ( $exists, $err ) = $cv->recv;

    confess $err if $err;

    return $exists;
}

sub getdir {
    my ( $self, $path ) = @_;

    my @path = split m{/}, $path;

    return ('.', 0) if @path == 2; # /ts

    my $tag  = $path[-1];

    return -ENOENT() if !$self->_tag_exists($tag);

    return ('.', "${tag}.csv", 0); # /ts/<some ts>
}

__PACKAGE__->meta->make_immutable;
1;
