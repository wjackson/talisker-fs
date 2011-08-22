package Talisker::FS::Path::Role;

use Moose::Role;
use namespace::autoclean;
use MooseX::Types::Path::Class qw(File Dir);

requires qw(
    name
);

has th => (
    is       => 'ro',
    isa      => 'Talisker::Handle',
    required => 1,
);

sub _getattr_dir {

    my $mode = 0644;
    $mode += 0040 << 9;
    $mode += 0111;

    return (
        1,     # dev
        0,     # ino
        $mode, # mode
        1,     # nlink
        0,     # uid
        0,     # gid
        0,     # rdev
        0,     # size
        1,     # atime
        1,     # mtime
        1,     # ctime
        1024,  # blksize
        1,     # blocks
    );

}

sub _getattr_file {
    my ($self) = @_;

    my $mode = 0644;
    $mode += 0100 << 9;

    return (
        1,     # dev
        0,     # ino
        $mode, # mode
        1,     # nlink
        0,     # uid
        0,     # gid
        0,     # rdev
        0,     # size
        1,     # atime
        0,     # mtime
        1,     # ctime
        1024,  # blksize
        0,     # blocks
    );
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

1;
