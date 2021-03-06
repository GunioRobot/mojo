#!/usr/bin/env perl
use Mojo::Base -strict;

# Disable Bonjour, IPv6 and libev
BEGIN {
  $ENV{MOJO_NO_BONJOUR} = $ENV{MOJO_NO_IPV6} = 1;
  $ENV{MOJO_IOWATCHER} = 'Mojo::IOWatcher';
}

# To regenerate all required certificates run these commands
# openssl genrsa -out ca.key 1024
# openssl req -new -key ca.key -out ca.csr -subj "/C=US/CN=ca"
# openssl req -x509 -days 7300 -key ca.key -in ca.csr -out ca.crt
#
# openssl genrsa -out server.key 1024
# openssl req -new -key server.key -out server.csr -subj "/C=US/CN=server"
# openssl x509 -req -days 7300 -in server.csr -out server.crt -CA ca.crt \
#   -CAkey ca.key -CAcreateserial
#
# openssl genrsa -out client.key 1024
# openssl req -new -key client.key -out client.csr -subj "/C=US/CN=client"
# openssl x509 -req -days 7300 -in client.csr -out client.crt -CA ca.crt \
#   -CAkey ca.key -CAcreateserial
#
# openssl genrsa -out badclient.key 1024
# openssl req -new -key badclient.key -out badclient.csr \
#   -subj "/C=US/CN=badclient"
# openssl req -x509 -days 7300 -key badclient.key -in badclient.csr \
#   -out badclient.crt
use Test::More;
use Mojo::IOLoop::Server;
plan skip_all => 'set TEST_TLS to enable this test (developer only!)'
  unless $ENV{TEST_TLS};
plan skip_all => 'IO::Socket::SSL 1.37 required for this test!'
  unless Mojo::IOLoop::Server::TLS;
plan tests => 29;

# "To the panic room!
#  We don't have a panic room.
#  To the panic room store!"
use_ok 'Mojo::IOLoop';

my $loop = Mojo::IOLoop->new;
my $port = Mojo::IOLoop->generate_port;
my ($server, $client) = '';
$loop->listen(
  port      => $port,
  tls       => 1,
  on_accept => sub {
    shift->write(shift, 'test', sub { shift->write(shift, '321') });
  },
  on_read => sub { $server .= pop }
);
my $id = $loop->connect(
  address    => 'localhost',
  port       => $port,
  tls        => 1,
  on_connect => sub {
    shift->write(shift, 'tset', sub { shift->write(shift, '123') });
  },
  on_read => sub { $client .= pop }
);
$loop->timer(1 => sub { shift->stop });
$loop->start;
is $server, 'tset123', 'right content';
is $client, 'test321', 'right content';

# Valid client certificate
$loop   = Mojo::IOLoop->singleton;
$port   = Mojo::IOLoop->generate_port;
$server = $client = '';
my ($drop, $running, $error, $server_close, $client_close);
Mojo::IOLoop->drop(Mojo::IOLoop->recurring(0 => sub { $drop++ }));
$loop->listen(
  port      => $port,
  tls       => 1,
  tls_cert  => 't/mojo/certs/server.crt',
  tls_key   => 't/mojo/certs/server.key',
  tls_ca    => 't/mojo/certs/ca.crt',
  on_accept => sub {
    shift->write(shift, 'test', sub { shift->write(shift, '321') });
    $running = Mojo::IOLoop->is_running;
  },
  on_close => sub { $server_close++ },
  on_error => sub { $error = pop },
  on_read  => sub { $server .= pop }
);
$id = $loop->connect(
  address    => 'localhost',
  port       => $port,
  tls        => 1,
  tls_cert   => 't/mojo/certs/client.crt',
  tls_key    => 't/mojo/certs/client.key',
  on_close   => sub { $client_close++ },
  on_connect => sub {
    shift->write(shift, 'tset', sub { shift->write(shift, '123') });
  },
  on_read => sub { $client .= pop }
);
$loop->connection_timeout($id => '0.5');
$loop->timer(1 => sub { shift->stop });
$loop->start;
is $server,       'tset123', 'right content';
is $client,       'test321', 'right content';
is $server_close, 1,         'server emitted close event once';
is $client_close, 1,         'client emitted close event once';
ok $running,      'loop was running';
ok !$drop,  'event dropped successfully';
ok !$error, 'no error';

# Delayed TLS handshake with valid client certificate
$server       = $client       = '';
$server_close = $client_close = 0;
$id           = $loop->connect(
  address    => 'localhost',
  port       => $port,
  on_connect => sub {
    my ($loop, $id) = @_;
    $loop->start_tls(
      $id => {
        on_close   => sub { $client_close++ },
        on_connect => sub {
          shift->write(shift, 'tset', sub { shift->write(shift, '123') });
        },
        on_read => sub { $client .= pop },
        tls_cert => 't/mojo/certs/client.crt',
        tls_key  => 't/mojo/certs/client.key'
      }
    );
  }
);
$loop->connection_timeout($id => '0.5');
$loop->timer(1 => sub { shift->stop });
$loop->start;
is $server,       'tset123', 'right content';
is $client,       'test321', 'right content';
is $server_close, 1,         'server emitted close event once';
is $client_close, 1,         'client emitted close event once';
ok $running,      'loop was running';
ok !$drop,  'event dropped successfully';
ok !$error, 'no error';

# Invalid client certificate
$error = '';
$id    = $loop->connect(
  address  => 'localhost',
  port     => $port,
  tls      => 1,
  tls_cert => 't/mojo/certs/badcert.key',
  tls_key  => 't/mojo/certs/badcert.crt',
  on_error => sub { $error = pop },
);
$loop->connection_timeout($id => '0.5');
$loop->timer(1 => sub { shift->stop });
$loop->start;
ok $error, 'has error';

# Delayed TLS handshake with invalid client certificate
$error = '';
$id    = $loop->connect(
  address    => 'localhost',
  port       => $port,
  on_connect => sub {
    my ($loop, $id) = @_;
    $loop->start_tls(
      $id => {
        tls_cert => 't/mojo/certs/badcert.key',
        tls_key  => 't/mojo/certs/badcert.crt',
        on_error => sub { $error = pop },
      }
    );
  },
  on_error => sub { }
);
$loop->connection_timeout($id => '0.5');
$loop->timer(1 => sub { shift->stop });
$loop->start;
ok $error, 'has error';

# Valid client certificate but rejected by callback
$loop = Mojo::IOLoop->new;
$port = Mojo::IOLoop->generate_port;
my $cerror = $error = '';
$loop->listen(
  port       => $port,
  tls        => 1,
  tls_cert   => 't/mojo/certs/server.crt',
  tls_key    => 't/mojo/certs/server.key',
  tls_ca     => 't/mojo/certs/ca.crt',
  tls_verify => sub {0},
  on_error   => sub { $error = pop },
);
$id = $loop->connect(
  address  => 'localhost',
  port     => $port,
  tls      => 1,
  tls_cert => 't/mojo/certs/client.crt',
  tls_key  => 't/mojo/certs/client.key',
  on_error => sub { $cerror = pop }
);
$loop->connection_timeout($id => '0.5');
$loop->timer(1 => sub { shift->stop });
$loop->start;
ok !$error, 'no error';
ok $cerror, 'has error';

# Valid client certificate accepted by callback
$loop         = Mojo::IOLoop->new;
$port         = Mojo::IOLoop->generate_port;
$server       = $client = '';
$server_close = $client_close = 0;
$loop->listen(
  port       => $port,
  tls        => 1,
  tls_cert   => 't/mojo/certs/server.crt',
  tls_key    => 't/mojo/certs/server.key',
  tls_ca     => 't/mojo/certs/ca.crt',
  tls_verify => sub {1},
  on_accept  => sub {
    shift->write(shift, 'test', sub { shift->write(shift, '321') });
  },
  on_close => sub { $server_close++ },
  on_error => sub { $error = pop },
  on_read  => sub { $server .= pop }
);
$id = $loop->connect(
  address    => 'localhost',
  port       => $port,
  tls        => 1,
  tls_cert   => 't/mojo/certs/client.crt',
  tls_key    => 't/mojo/certs/client.key',
  on_close   => sub { $client_close++ },
  on_connect => sub {
    shift->write(shift, 'tset', sub { shift->write(shift, '123') });
  },
  on_read => sub { $client .= pop }
);
$loop->connection_timeout($id => '0.5');
$loop->timer(1 => sub { shift->stop });
$loop->start;
is $server,       'tset123', 'right content';
is $client,       'test321', 'right content';
is $server_close, 1,         'server emitted close event once';
is $client_close, 1,         'client emitted close event once';

# Missing client certificate
$error = $cerror = '';
$id = $loop->connect(
  address  => 'localhost',
  port     => $port,
  tls      => 1,
  on_error => sub { $cerror = pop }
);
$loop->connection_timeout($id => '0.5');
$loop->timer(1 => sub { shift->stop });
$loop->start;
ok !$error, 'no error';
ok $cerror, 'has error';

# Invalid certificate authority
$loop  = Mojo::IOLoop->new;
$port  = Mojo::IOLoop->generate_port;
$error = $cerror = '';
$loop->listen(
  port      => $port,
  tls       => 1,
  tls_cert  => 't/mojo/certs/server.crt',
  tls_key   => 't/mojo/certs/server.key',
  tls_ca    => 'no cert',
  on_accept => sub {
    shift->write(shift, 'test', sub { shift->write(shift, '321') });
  },
  on_error => sub { $error = pop }
);
$id = $loop->connect(
  address  => 'localhost',
  port     => $port,
  tls      => 1,
  tls_cert => 't/mojo/certs/client.crt',
  tls_key  => 't/mojo/certs/client.key',
  on_error => sub { $cerror = pop }
);
$loop->connection_timeout($id => '0.5');
$loop->timer(1 => sub { shift->stop });
$loop->start;
ok !$error, 'no error';
ok $cerror, 'has error';
