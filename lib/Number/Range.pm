package Number::Range;

use strict;
use warnings;
use warnings::register;
use Carp;

require Exporter;

our @ISA = qw(Exporter);


our $VERSION = '0.08';

sub new {
  my $this = shift;
  my $class = ref($this) || $this;
  my $self = {};
  bless $self, $class;
  $self->initialize("add", @_);
  return $self;
}

sub initialize {
  my $self = shift;
  my $type = shift;
  my $rangesep = qr/(?:\.\.)/;
  my $sectsep  = qr/(?:\s|,)/;
  my $validation = qr/(?:
       [^0-9,. -]|        # These are the only allowed characters (Numbers and "separators")
       $rangesep$sectsep| # We don't want a range separator followed by section separator
       $sectsep$rangesep| # We don't want a section separator followed by range separator
       \d-\d|             # We don't want 10-10 since - is for negative numbers
       ^$sectsep|         # We don't want a section separator at the start
       ^$rangesep|        # We don't want a range separator at the start
       $sectsep$|         # We don't want a section separator at the end
       $rangesep$         # We don't want a range separator at the end
       )/x;
  foreach my $item (@_) {
    croak "$item contains invalid data" if ($item =~ m/$validation/g);
    foreach my $section (split(/$sectsep/, $item)) {
      if ($section =~ m/$rangesep/) {
        my ($start, $end) = split(/$rangesep/, $section, 2);
        if ($start > $end) {
          carp "$start is > $end" if (warnings::enabled());
          ($start, $end) = ($end, $start);
        }
        if ($start == $end) {
          carp "$start:$end is pointless" if (warnings::enabled());
          if ($type eq "add") {
            $self->_addnumbers($start);
          }
          elsif ($type eq "del") {
            $self->_delnumbers($start);
          }
          else {
            die "Neither 'add' nor 'del' was passed initialize()";
          }
        }
        else {
          if ($type eq "add") {
            $self->_addnumbers($start .. $end);
          }
          elsif ($type eq "del") {
            $self->_delnumbers($start .. $end);
          }
          else {
            die "Neither 'add' nor 'del' was passed initialize()";
          }
        }
      }
      else {
        if ($type eq "add") {
           $self->_addnumbers($section);
         }
         elsif ($type eq "del") {
          $self->_delnumbers($section);
         }
         else {
          die "Neither 'add' nor 'del' was passed initialize()";
        }
      }
    }
  }
}

sub _addnumbers {
  my $self = shift;
  foreach my $number (@_) {
    if (warnings::enabled()) {
      carp "$number already in range" if $self->inrange($number);
    }
    $self->{_rangehash}{$number} = 1;
  }
}

sub _delnumbers {
  my $self = shift;
  foreach my $number (@_) {
    if (warnings::enabled()) {
      carp "$number not in range or already removed" if (!$self->inrange($number));
    }
    delete $self->{_rangehash}{$number};
  }
}

sub inrange {
  my $self   = shift;
  if (scalar(@_) == 1) {
    return (exists($self->{_rangehash}{-+-$_[0]})) ? 1 : 0;
  } else {
    if (wantarray) {
      my @returncodes;
      foreach my $test (@_) {
        push(@returncodes, ($self->inrange($test)) ? 1 : 0);
      }
      return @returncodes;
    } else {
      foreach my $test (@_) {
        if (!$self->inrange($test)) {
          return 0;
        }
        return 1;
      }
    }
  }
}

sub addrange {
  my $self = shift;
  $self->initialize("add", @_);
}

sub delrange {
  my $self = shift;
  $self->initialize("del", @_);
}

sub range {
  my $self = shift;
  if (wantarray) {
    my @range = keys(%{$self->{_rangehash}});
    my @sorted = sort {$a <=> $b} @range;
    return @sorted;
  }
  else {
    my @range    = $self->range;
    my $previous = shift @range;
    my $format   = "$previous";
    foreach my $current (@range) {
      if ($current == ($previous + 1)) {
        $format =~ s/\.\.$previous$//;
        $format .= "..$current"; 
      }
      else {
        $format .= ",$current";
      }
      $previous = $current;
    }
    return $format;
  }
}

sub size {
  my $self = shift;
  my @temp = $self->range;
  return scalar(@temp);
}

1;
__END__

=head1 NAME

Number::Range - Perl extension defining ranges of numbers and testing if a
number is found in the range. You can also add and delete from this range.

=head1 SYNOPSIS

  use Number::Range;

  my $range = Number::Range->new("-10..10,12,100..120");
  if ($range->inrange("13")) {
    print "In range\n";
  } else {
    print "Not in range\n";
  }
  $range->addrange("200..300");
  $range->delrange("250..255");
  my $format = $range->range;
  # $format will be '-10..10,12,100..120,200..249,256..300'

=head1 DESCRIPTION

Number::Range will take a description of a range, and then allow you to test on
if a number falls within the range. You can also add and delete from the range.

=head2 RANGE FORMAT

The format used for range is pretty straight forward. To separate sections of
ranges it uses a C<,> or whitespace. To create the range, it uses C<..> to do
this, much like Perl's own binary C<..> range operator in list context.

=head2 METHODS

=over

=item new

  $range = Number::Range->new("10..20","25..30");

Creates the range object. It will accept any number of ranges as its 
input.

=item addrange

  $range->addrange("22");

This will also take any number of ranges as input and add them to the 
existing range.

=item delrange

  $range->delrange("10");

This will also take any number of ranges as input and delete them from the
existing range.

=item inrange

  $range->inrange("26"); my @results = $range->inrange("27","200");

This will take one or more numbers and check if each of them exists in the
range. If passed a list, and in array context, it will return a list of C<0>'s
or C<1>'s, depending if that one was true or false in the list position. If in
scalar context, it will return a single C<1> if all are true, or a single C<0>
if one of them failed.

=item range

  $format = $range->range; @numbers = $range->range;

Depending on context this will return either an array of all the numbers found
in the range, for list context. For scalar context it will return a range
string.

=item size

  $size = $range->size;

This will return the total number of entries in the range.

=back

=head2 EXPORT

None by default.

=head1 SEE ALSO

L<Number::Tolerant>, L<Tie::RangeHash>, and L<Array::IntSpan> for similar
modules.

=head1 AUTHOR

Larry Shatzer, Jr., E<lt>larrysh@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2004-8 by Larry Shatzer, Jr.

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
