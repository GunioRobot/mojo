#!/usr/bin/env perl
use Mojo::Base -strict;

use utf8;

use Test::More tests => 127;

# "This is the greatest case of false advertising I’ve seen since I sued the
#  movie 'The Never Ending Story.'"
use_ok 'Mojo::Path';

# Basics
my $path = Mojo::Path->new;
is $path->parse('/path')->to_string, '/path', 'right path';
is $path->parts->[0], 'path', 'right part';
is $path->parts->[1], undef,  'no part';
is $path->leading_slash,  1,     'has leading slash';
is $path->trailing_slash, undef, 'no trailing slash';
is $path->parse('path/')->to_string, 'path/', 'right path';
is $path->parts->[0], 'path', 'right part';
is $path->parts->[1], undef,  'no part';
is $path->leading_slash,  undef, 'no leading slash';
is $path->trailing_slash, 1,     'has trailing slash';

# Unicode
is $path->parse('/foo/♥/bar')->to_string, '/foo/%E2%99%A5/bar',
  'right path';
is $path->parts->[0], 'foo', 'right part';
is $path->parts->[1], '♥', 'right part';
is $path->parts->[2], 'bar', 'right part';
is $path->parts->[3], undef, 'no part';
is $path->leading_slash,  1,     'has leading slash';
is $path->trailing_slash, undef, 'no trailing slash';
is $path->parse('/foo/%E2%99%A5/bar')->to_string, '/foo/%E2%99%A5/bar',
  'right path';
is $path->parts->[0], 'foo', 'right part';
is $path->parts->[1], '♥', 'right part';
is $path->parts->[2], 'bar', 'right part';
is $path->parts->[3], undef, 'no part';
is $path->leading_slash,  1,     'has leading slash';
is $path->trailing_slash, undef, 'no trailing slash';

# Zero in path
is $path->parse('/path/0')->to_string, '/path/0', 'right path';
is $path->parts->[0], 'path', 'right part';
is $path->parts->[1], '0',    'right part';
is $path->parts->[2], undef,  'no part';
is $path->leading_slash,  1,     'has leading slash';
is $path->trailing_slash, undef, 'no trailing slash';

# Canonicalizing
$path = Mojo::Path->new(
  '/%2f..%2f..%2f..%2f..%2f..%2f..%2f..%2f..%2f..%2f..%2fetc%2fpasswd');
is "$path", '/../../../../../../../../../../etc/passwd', 'rigth result';
is $path->parts->[0],  '..',     'right part';
is $path->parts->[1],  '..',     'right part';
is $path->parts->[2],  '..',     'right part';
is $path->parts->[3],  '..',     'right part';
is $path->parts->[4],  '..',     'right part';
is $path->parts->[5],  '..',     'right part';
is $path->parts->[6],  '..',     'right part';
is $path->parts->[7],  '..',     'right part';
is $path->parts->[8],  '..',     'right part';
is $path->parts->[9],  '..',     'right part';
is $path->parts->[10], 'etc',    'right part';
is $path->parts->[11], 'passwd', 'right part';
is $path->parts->[12], undef,    'no part';
is $path->canonicalize, '/../../../../../../../../../../etc/passwd',
  'rigth result';
is $path->parts->[0],  '..',     'right part';
is $path->parts->[1],  '..',     'right part';
is $path->parts->[2],  '..',     'right part';
is $path->parts->[3],  '..',     'right part';
is $path->parts->[4],  '..',     'right part';
is $path->parts->[5],  '..',     'right part';
is $path->parts->[6],  '..',     'right part';
is $path->parts->[7],  '..',     'right part';
is $path->parts->[8],  '..',     'right part';
is $path->parts->[9],  '..',     'right part';
is $path->parts->[10], 'etc',    'right part';
is $path->parts->[11], 'passwd', 'right part';
is $path->parts->[12], undef,    'no part';
is $path->leading_slash,  1,     'has leading slash';
is $path->trailing_slash, undef, 'no trailing slash';

# Canonicalizing (alternative)
$path = Mojo::Path->new(
  '/%2ftest%2f..%2f..%2f..%2f..%2f..%2f..%2f..%2f..%2f..%2fetc%2fpasswd');
is "$path", '/test/../../../../../../../../../etc/passwd', 'rigth result';
is $path->parts->[0],  'test',   'right part';
is $path->parts->[1],  '..',     'right part';
is $path->parts->[2],  '..',     'right part';
is $path->parts->[3],  '..',     'right part';
is $path->parts->[4],  '..',     'right part';
is $path->parts->[5],  '..',     'right part';
is $path->parts->[6],  '..',     'right part';
is $path->parts->[7],  '..',     'right part';
is $path->parts->[8],  '..',     'right part';
is $path->parts->[9],  '..',     'right part';
is $path->parts->[10], 'etc',    'right part';
is $path->parts->[11], 'passwd', 'right part';
is $path->parts->[12], undef,    'no part';
is $path->canonicalize, '/../../../../../../../../etc/passwd', 'rigth result';
is $path->parts->[0],  '..',     'right part';
is $path->parts->[1],  '..',     'right part';
is $path->parts->[2],  '..',     'right part';
is $path->parts->[3],  '..',     'right part';
is $path->parts->[4],  '..',     'right part';
is $path->parts->[5],  '..',     'right part';
is $path->parts->[6],  '..',     'right part';
is $path->parts->[7],  '..',     'right part';
is $path->parts->[8],  'etc',    'right part';
is $path->parts->[9],  'passwd', 'right part';
is $path->parts->[10], undef,    'no part';
is $path->leading_slash,  1,     'has leading slash';
is $path->trailing_slash, undef, 'no trailing slash';

# Canonicalizing (with escaped "%")
$path = Mojo::Path->new('/%2ftest%2f..%252f..%2f..%2f..%2f..%2fetc%2fpasswd');
is "$path", '/test/..%252f../../../../etc/passwd', 'rigth result';
is $path->parts->[0], 'test',    'right part';
is $path->parts->[1], '..%2f..', 'right part';
is $path->parts->[2], '..',      'right part';
is $path->parts->[3], '..',      'right part';
is $path->parts->[4], '..',      'right part';
is $path->parts->[5], 'etc',     'right part';
is $path->parts->[6], 'passwd',  'right part';
is $path->parts->[7], undef,     'no part';
is $path->canonicalize, '/../etc/passwd', 'rigth result';
is $path->parts->[0], '..',     'right part';
is $path->parts->[1], 'etc',    'right part';
is $path->parts->[2], 'passwd', 'right part';
is $path->parts->[3], undef,    'no part';
is $path->leading_slash,  1,     'has leading slash';
is $path->trailing_slash, undef, 'no trailing slash';

# Contains
$path = Mojo::Path->new('/foo/bar');
ok $path->contains('/'),        'contains path';
ok $path->contains('/foo'),     'contains path';
ok $path->contains('/foo/bar'), 'contains path';
ok !$path->contains('/foobar'),      'does not contain path';
ok !$path->contains('/foo/b'),       'does not contain path';
ok !$path->contains('/foo/bar/baz'), 'does not contain path';
$path = Mojo::Path->new('/♥/bar');
ok $path->contains('/♥'),     'contains path';
ok $path->contains('/♥/bar'), 'contains path';
ok !$path->contains('/♥foo'), 'does not contain path';
ok !$path->contains('/foo♥'), 'does not contain path';
$path = Mojo::Path->new('/');
ok $path->contains('/'), 'contains path';
ok !$path->contains('/foo'), 'does not contain path';
$path = Mojo::Path->new('/0');
ok $path->contains('/'),  'contains path';
ok $path->contains('/0'), 'contains path';
ok !$path->contains('/0/0'), 'does not contain path';
$path = Mojo::Path->new('/0/♥.html');
ok $path->contains('/'),           'contains path';
ok $path->contains('/0'),          'contains path';
ok $path->contains('/0/♥.html'), 'contains path';
ok !$path->contains('/0/♥'),    'does not contain path';
ok !$path->contains('/0/0.html'), 'does not contain path';
ok !$path->contains('/0.html'),   'does not contain path';
ok !$path->contains('/♥.html'), 'does not contain path';
