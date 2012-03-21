#!/usr/bin/perl
use strict;
use warnings;
use DBI;
use LWP::UserAgent;
use YAML::XS;

=pod
CREATE DATABASE seo;
CREATE TABLE `watcher_google_index` (
  `domain` varchar(255) NOT NULL DEFAULT '',
  `count` bigint(20) NOT NULL DEFAULT '0',
  `date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY `idx_key` (`domain`,`date`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8
=cut

my $ua         = LWP::UserAgent->new;
my $config     = YAML::XS::LoadFile('config.yml');
my $db_config  = $config->{db};
my $user_agent = $config->{user_agent};
my @domain     = @{ $config->{domains} };

my @result = ();
for my $domain (@domain) {
    my $request_url = 'https://www.google.co.jp/search?q=site%3A' .$domain.'&ie=utf-8&oe=utf-8&aq=t&rls=org.mozilla:ja-JP-mac:official&hl=ja&client=firefox-a';
    $ua->agent($user_agent);
    my $response = $ua->get($request_url);
    my $body = $response->content;
    my @index = $body =~ /約 ([0-9,]+) 件<nobr>/g;
    my $index = $index[0];
    $index && $index =~ s/,//g;

    push @result, [$domain, $index];
    sleep 1;
}

bulk_insert($db_config, \@result);

sub bulk_insert {
    my $config = shift;
    my $values = shift;

    my $ds = $config->{ds};
    my $user = $config->{user};
    my $password = $config->{password};
    my $dbh = DBI->connect($ds, $user, $password);

    my $sql = 'INSERT INTO watcher_google_index VALUES ';
    my @value = ();

    for (@{ $values }) {
        push @value, ($_->[0], $_->[1]);
        $sql .= '(?,?,CURRENT_TIMESTAMP),';
    }
    chop($sql);
    my $sth = $dbh->prepare($sql);
    $sth->execute(@value);
    $dbh->disconnect();
}

