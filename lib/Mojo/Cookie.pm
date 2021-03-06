package Mojo::Cookie;
use Mojo::Base -base;
use overload
  'bool'   => sub {1},
  '""'     => sub { shift->to_string },
  fallback => 1;

use Carp 'croak';
use Mojo::Util 'unquote';

has [qw/name path value version/];

my $COOKIE_SEPARATOR_RE = qr/^\s*\,\s*/;
my $NAME_RE             = qr/
  ^\s*
  (?<name>[^\=\;\,]+)   # Relaxed Netscape token, allowing whitespace
  \s*
  \=?                   # '=' (optional)
  \s*
/x;
my $SEPARATOR_RE = qr/^\s*\;\s*/;
my $VALUE_RE     = qr/
  ^
  (?<value>
    "(?:\\\\|\\"|[^"])+"   # Quoted
  |
    [^\;\,]+               # Unquoted
  )
  \s*
/x;

# "My Homer is not a communist.
#  He may be a liar, a pig, an idiot, a communist,
#  but he is not a porn star."
sub to_string { croak 'Method "to_string" not implemented by subclass' }

sub _tokenize {
  my ($self, $string) = @_;

  # Nibbling parser
  my (@tree, @token);
  while ($string) {

    # Name
    if ($string =~ s/$NAME_RE//) {
      my $name = $+{name};

      # "expires" is a special case, thank you Netscape...
      $string =~ s/^([^\;\,]+\,?[^\;\,]+)/"$1"/ if $name =~ /^expires$/i;

      # Value
      my $value;
      if ($string =~ s/$VALUE_RE//) {
        $value = $+{value};
        unquote $value;
      }

      # Token
      push @token, [$name, $value];

      # Separator
      $string =~ s/$SEPARATOR_RE//;
      if ($string =~ s/$COOKIE_SEPARATOR_RE//) {
        push @tree, [@token];
        @token = ();
      }
    }

    # Bad format
    else {last}

  }

  # No separator
  push @tree, [@token] if @token;

  return @tree;
}

1;
__END__

=head1 NAME

Mojo::Cookie - HTTP 1.1 cookie base class

=head1 SYNOPSIS

  use Mojo::Base 'Mojo::Cookie';

=head1 DESCRIPTION

L<Mojo::Cookie> is an abstract base class for HTTP 1.1 cookies.

=head1 ATTRIBUTES

L<Mojo::Cookie> implements the following attributes.

=head2 C<name>

  my $name = $cookie->name;
  $cookie  = $cookie->name('foo');

Cookie name.

=head2 C<path>

  my $path = $cookie->path;
  $cookie  = $cookie->path('/test');

Cookie path.

=head2 C<value>

  my $value = $cookie->value;
  $cookie   = $cookie->value('/test');

Cookie value.

=head2 C<version>

  my $version = $cookie->version;
  $cookie     = $cookie->version(1);

Cookie version.

=head1 METHODS

L<Mojo::Cookie> inherits all methods from L<Mojo::Base> and implements the
following new ones.

=head2 C<to_string>

  my $string = $cookie->to_string;

Render cookie.

=head1 SEE ALSO

L<Mojolicious>, L<Mojolicious::Guides>, L<http://mojolicio.us>.

=cut
