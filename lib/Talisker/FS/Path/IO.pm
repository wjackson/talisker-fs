package Talisker::FS::Path::IO;

use Moose;
use namespace::autoclean;
use MooseX::Types::Path::Class qw(File Dir);
use AnyEvent;
use JSON;
use POSIX qw(ENOENT);
use Talisker::Util qw(merge_point);

with 'Talisker::FS::Path::Role';

my @IO_FILES = qw(
    in
);

has file_map => (
    accessor   => 'file_map',
    isa        => 'HashRef',
    lazy_build => 1,
);

has open_count => (
    is      => 'rw',
    isa     => 'Int',
    default => 0,
);

has pending_in_buffers => (
    is      => 'ro',
    isa     => 'HashRef',
    default => sub { {} },
);

sub _build_file_map {
    my ($self) = @_;

    return { map { $_ => 1 } @IO_FILES };
}

sub getattr {
    my ($self, $path) = @_;
    my $file = to_File($path);

    my $name = $self->name;

    return $self->getattr_dir  if $path eq "/$name";
    return $self->getattr_file if exists $self->file_map->{$file->basename};
    return -ENOENT();
}

sub getdir {
    return '.', @IO_FILES, 0;
}

sub open {
    my ($self, $path, $flag, $file_info) = @_;

    # TODO: make sure this is an open for write

    # lets read return data even though size is 0
    # $file_info->{direct_io} = 1;

    my $open_id = $self->open_count;

    $self->open_count( $self->open_count + 1 );

    $self->pending_in_buffers->{$path}->{$open_id} = '';

    return 0, $open_id;
}

sub write {
    my ($self, @args) = @_;

    return $self->_dispatch('write', @args);
}


sub _write_in {
    my ($self, $path, $current_buffer, $offset, $open_id) = @_;

    my $pending_in_buffer = $self->pending_in_buffers->{$path}->{$open_id};
    my $buffer            = $pending_in_buffer . $current_buffer;
    my @lines             = split "\n", $buffer, -1;
    my $last_line         = pop @lines;

    # store incomplete lines for later writing
    if (defined $last_line) {
        $self->pending_in_buffers->{$path}->{$open_id} = $last_line;
    }

    my $talisker = $self->talisker;
    my $fields   = $self->_fields;
    my @tsz      = map { $self->_line_to_ts($_, $fields) } @lines;


    my $work_cb = sub {
        my ($ts, $cb) = @_;
        $talisker->write(%{ $ts }, cb => $cb);
    };

    my $cv = AE::cv;

    merge_point(
        inputs   => \@tsz,
        work     => $work_cb,
        finished => sub { $cv->send(@_) },
    );

    my (undef, $err) = $cv->recv;

    confess $err if $err;

    return length($current_buffer);
}

sub close {
    # TODO: cleanup pending write buffer

    return 0;
}

sub _line_to_ts {
    my ($self, $line, $fields) = @_;

    my ($tag, $stamp, @field_vals) = split ',', $line;

    my $pt = { stamp => $stamp };

    for my $i (0..$#{ $fields }) {
        my $field     = $fields->[$i];
        my $field_val = $field_vals[$i];

        $pt->{ $field->{name} } = $field_val;
    }

    return { tag => $tag, points => [ $pt ] };
}

sub _dispatch {
    my ($self, $base_method, $path, @args) = @_;
    my $file = to_File($path);

    my $method = "_${base_method}_" . $file->basename;

    return $self->$method($path, @args);
}

__PACKAGE__->meta->make_immutable;
1;
