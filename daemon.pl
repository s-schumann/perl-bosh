#!/usr/bin/perl
############################################################
# Perl BOSH Publisher for integrating OpenSIPS and XMPP    #
# Author: Sebastian Schumann (seb.schumann@gmail.com       #
# Version: 0.3                                             #
# Last modified: 25.09.2009                                #
############################################################

use strict;
use warnings;
use POSIX qw(setsid);
use DBI;
require "bosh_connect.pl";

# fork the daemon, kill the parent
# TODO check and optimize fork
defined(my $pid = fork) or die "Can't fork: $!";
exit if $pid;
setsid or die "Can't start a new session: $!";

# initial configuration variables
# TODO config.ini file
my $dbhost='HOST';
my $dbport=3306;
my $database='opensips_1_5';
my $table='perl';
my $dbuser='opensips';
my $dbpassword='opensipsrw';
my $dsn = "DBI:mysql:database=$database;host=$dbhost;port=$dbport";
my $sth;
my $ref;

# Connect to the database.
my $dbh = DBI->connect($dsn, $dbuser, $dbpassword, {'RaiseError' => 1});

while(1) {
	# run each second
	sleep(1);
	if(checkNew() != 0) {
		# modifications found, requesting parameters
		$sth = $dbh->prepare("SELECT * FROM $table");
		$sth->execute();
		while ($ref = $sth->fetchrow_hashref()) {
			print "DEBUG: Found a row: id = $ref->{'id'}, uri = $ref->{'uri'}, state = $ref->{'state'}\n";
			&getPassed($ref->{'uri'}, $ref->{'state'});
			&read;
			&search;
			&connect;
			&write;
		}
		# deleting parameters
		$sth = $dbh->prepare("DELETE FROM $table");
		$sth->execute();
	}
	# done with DB interaction
	$sth->finish();
	print "DEBUG: Daemon is still running...\n";
}

sub checkNew {
	# check database for modifications
	$sth = $dbh->prepare("SELECT count(*) FROM $table");
	$sth->execute();
	$ref = $sth->fetchrow_hashref();
	return $ref->{'count(*)'};
}

print "DEBUG: End daemon.pl";

__END__
