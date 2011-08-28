package Talisker::FS::Path::Role;

use Moose::Role;
use namespace::autoclean;
use MooseX::Types::Path::Class qw(File Dir);
use AnyEvent;

has talisker => (
    is       => 'ro',
    isa      => 'Talisker',
    required => 1,
);

has name => (
    accessor => 'name',
    isa => 'Str',
    lazy_build => 1,
);

sub _build_name {
    my ($self) = @_;
    my @pkg = split /::/, $self->meta->name;
    return lc pop @pkg;
}

sub read {
    return '';
}

sub readlink {
    my $self = shift;
    my $file = to_File(shift);

    return;
}

sub statfs {
    my ($self, $file) = @_;

    return 255, 1, 1, 1, 1, 2;
}

# $VAR1 = [
#     '/are', 32768,
#     {
#         'direct_io'  => 0,
#         'keep_cache' => 0
#     }
# ];
sub open {
    my $self = shift;
    my $file = to_File(shift);
    my ($flag, $file_info) = @_;

    # lets read return data even though size is 0
    $file_info->{direct_io} = 1;

    return 0;
}

sub flush {
    my $self = shift;
    my $file = to_File(shift);
    my $fh   = shift;

    return 0;
}

sub release {
    my $self  = shift;
    my $file  = to_File(shift);
    my $flags = shift;
    my $fh    = shift;

    return 0;
}

sub mknod {
    return 0;
}

sub create {
    return 0;
}

sub setattr {
    return 0;
}

sub mkdir {
    return 0;
}

sub unlink {
    return 0;
}

sub rmdir {
    return 0;
}

sub symlink {
    return 0;
}

sub rename {
    return 0;
}

sub link {
    return 0;
}

sub chmod {
    return 0;
}

sub chown {
    return 0;
}

sub truncate {
    return 0;
}

sub utime {
    return 0;
}

sub write {
    return 0;
}

sub fsync {
    return 0;
}

sub _fields {
    my ($self) = @_;

    my $cv = AE::cv;
    $self->talisker->read_fields( cb => sub { $cv->send(@_) } );
    my ( $fields, $err ) = $cv->recv;

    confess $err if $err;

    return $fields;
}

sub getattr_file {
    my ($self, %attr) = @_;

    my $mode = 0644;
    $mode += 0100 << 9;

    return $self->_getattr(mode => $mode, %attr);
}

sub getattr_dir {
    my ($self, %attr) = @_;

    my $mode = 0644;
    $mode += 0040 << 9;
    $mode += 0111;

    return $self->_getattr(mode => $mode, %attr);
}

sub _getattr {
    my ($self, %attr) = @_;

    return (
        $attr{dev}     // 1,
        $attr{ino}     // 0,
        $attr{mode}    // 33188,
        $attr{nlink}   // 1,
        $attr{uid}     // 0,
        $attr{gid}     // 0,
        $attr{rdev}    // 0,
        $attr{size}    // 0,
        $attr{atime}   // 0,
        $attr{mtime}   // 0,
        $attr{ctime}   // 0,
        $attr{blksize} // 1024,
        $attr{blocks}  // 1,
    );
}

1;
