#!/usr/bin/perl
############################################################
# Perl BOSH Publisher for integrating OpenSIPS and XMPP    #
# Author: Sebastian Schumann (seb.schumann@gmail.com       #
# Version: 0.3                                             #
# Last modified: 25.09.2009                                #
############################################################

use strict;
use warnings;
use LWP::UserAgent;
use LWP::ConnCache;
use HTTP::Request::Common;
use MIME::Base64;
use Digest::MD5;
use Text::CSV_XS;
use IO::File;

# initial variables
# TODO config.ini file
my $to = "BOSHSERVERIP";				#BOSH server
my $route = "XMPPSERVERIP:5222";			#XMPP server
my $bindUrl = "http://BOSHSERVERIP:5280/http-bind/";	#BOSH URL
my $presenceId = 120;					#initial presence ID
my $resource = "SIP-phone";				#XMPP resource
my $file = '/usr/local/share/perl-bosh/trunk/data.csv';	# configuration file
my $wait = 350;
my @data;						# CSV array
my $debug = 0;

# Passed variables
my $sipid;			# SIP URI sip:user@domain.tld
my $passedState;		# state (online, offline, onthephone, still-)

# config read
my $rid;			# RID
my $sid;			# SID
my $pid;			# presence ID
my $user;			# XMPP user
my $password;			# XMPP password

print "DEBUG: Begin bosh_connect.pl";

sub getPassed {
	# read passed parameters (sub called with 2 parameters)
	$sipid = shift;
	print "SIP ID argument: ".$sipid."\n";
	$passedState = shift;
	print "State argument: ".$passedState."\n";
}

sub getcli {
	# read command-line parameters
	my $numArgs = $#ARGV + 1;
	print "Found ".$numArgs." arguments.\n";
	# TODO Check if 2 parameters are passed, otherwise quit
	# TODO Check passed state, otherwise quit
	$numArgs=1;
	if($debug) {
		foreach my $arg (@ARGV) {
			print "Argument ".$numArgs++.":".$arg."\n";
		};
	}
	my $vec=0;
	if($#ARGV >= $vec) {
		$sipid=$ARGV[$vec++];
		print "SIP ID argument: ".$sipid."\n";
	}
	if($#ARGV >= $vec) {
		$passedState=$ARGV[$vec++];
		print "State argument: ".$passedState."\n";
	}
}

sub connect {
	my $ua = LWP::UserAgent->new(agent => 'Mozilla/4.0 (compatible; MSIE 5.5; Windows 98)');
	$ua->conn_cache(LWP::ConnCache->new());

	if($passedState eq 'online') {
		print "== Initial Request\n";
		my $response = $ua->request(
		POST $bindUrl
		,Content_Type => 'text/xml; charset=utf-8'
		,Content => "<body content='text/xml; charset=utf-8'
		      hold='1'
		      rid='".$rid++."'
		      to='".$to."'
		      route='xmpp:".$route."'
		      secure='true'
		      wait='".$wait."'
		      xml:lang='en'
		      xmpp:version='1.0'
		      xmlns='http://jabber.org/protocol/httpbind'
		      xmlns:xmpp='urn:xmpp:xbosh'/>");
		print "Status: ".$response->status_line."\n";
		print "Content: ".$response->content."\n";
		$_ = $response->content;

		if ( /\ssid='([^']*)'\s/ || /\ssid="([^"]*)"\s/ ) {
			$sid = $1;
			print "SID: ".$sid."\n";
		}

		print "== PLAIN request\n";
		$response = $ua->request(
		POST $bindUrl
		,Content_Type => 'text/xml; charset=utf-8'
		,Content => "<body rid='".$rid++."'
		     sid='$sid'
		     to='".$to."'
		     xmlns='http://jabber.org/protocol/httpbind'>
		<auth xmlns='urn:ietf:params:xml:ns:xmpp-sasl' mechanism='PLAIN'>".encode_base64("\x00$user\x00$password",'')."</auth>
		</body>");
		print "Status: ".$response->status_line."\n";
		print "Content: ".$response->content."\n";

		print "== RESET request\n";
		$response = $ua->request(
		POST $bindUrl
		,Content_Type => 'text/xml; charset=utf-8'
		,Content => "<body rid='".$rid++."'
		     sid='$sid'
		     secure='false'
		     to='".$to."'
		     xml:lang='en'
		     xmpp:restart='true'
		     xmlns:xmpp='urn:xmpp:xbosh'
		     xmlns='http://jabber.org/protocol/httpbind' />
		");
		print "Status: ".$response->status_line."\n";
		print "Content: ".$response->content."\n";

		print "== BIND request\n";
		$response = $ua->request(
		POST $bindUrl
		,Content_Type => 'text/xml; charset=utf-8'
		,Content => "<body rid='".$rid++."'
		     sid='$sid'
		     to='".$to."'
		     xmlns='http://jabber.org/protocol/httpbind'>
		<iq type='set' id='bind_1' xmlns='jabber:client'><bind xmlns='urn:ietf:params:xml:ns:xmpp-bind'><resource>".$resource."</resource></bind></iq>
		</body>");
		print "Status: ".$response->status_line."\n";
		print "Content: ".$response->content."\n";

		print "== SESSION request\n";
		$response = $ua->request(
		POST $bindUrl
		,Content_Type => 'text/xml; charset=utf-8'
		,Content => "<body rid='".$rid++."'
		     sid='$sid'
		     to='".$to."'
		     xmlns='http://jabber.org/protocol/httpbind'>
		<iq type='set' id='session_1'><session xmlns='urn:ietf:params:xml:ns:xmpp-session' /></iq>
		</body>");
		print "Status: ".$response->status_line."\n";
		print "Content: ".$response->content."\n";

		print "== PRESENCE request +++++ online\n";
		$response = $ua->request(
		POST $bindUrl
		,Content_Type => 'text/xml; charset=utf-8'
		,Content => "<body rid='".$rid++."'
		     sid='$sid'
		     to='".$to."'
		     xmlns='http://jabber.org/protocol/httpbind'>
		<presence xmlns='jabber:client' id='".$pid++."'><priority>0</priority></presence>
		</body>");
		print "Status: ".$response->status_line."\n";
		print "Content: ".$response->content."\n";
	}

	if($passedState eq 'onthephone') {
		print "== PRESENCE request +++++ onthephone\n";
		my $response = $ua->request(
		POST $bindUrl
		,Content_Type => 'text/xml; charset=utf-8'
		,Content => "<body rid='".$rid++."'
		     sid='$sid'
		     to='".$to."'
		     xmlns='http://jabber.org/protocol/httpbind'>
		<presence xmlns='jabber:client' id='".$pid++."'><show>away</show><status>On the phone.</status><priority>90</priority></presence>
		</body>");
		print "Status: ".$response->status_line."\n";
		print "Content: ".$response->content."\n";
	}

	if($passedState eq 'still-onthephone') {
		print "== PRESENCE request +++++ still-onthephone\n";
		my $response = $ua->request(
		POST $bindUrl
		,Content_Type => 'text/xml; charset=utf-8'
		,Content => "<body rid='".$rid++."'
		     sid='$sid'
		     to='".$to."'
		     xmlns='http://jabber.org/protocol/httpbind'>
		<presence xmlns='jabber:client' id='".$pid++."'><show>away</show><status>On the phone.</status><priority>90</priority></presence>
		</body>");
		print "Status: ".$response->status_line."\n";
		print "Content: ".$response->content."\n";
	}

	if($passedState eq 'still-online') {
		print "== PRESENCE request +++++ still-online\n";
		my $response = $ua->request(
		POST $bindUrl
		,Content_Type => 'text/xml; charset=utf-8'
		,Content => "<body rid='".$rid++."'
		     sid='$sid'
		     to='".$to."'
		     xmlns='http://jabber.org/protocol/httpbind'>
		<presence xmlns='jabber:client' id='".$pid++."'><priority>0</priority></presence>
		</body>");
		print "Status: ".$response->status_line."\n";
		print "Content: ".$response->content."\n";
	}

	if($passedState eq 'offline') {
		print "== TERMINATE request +++++ offline\n";
		my $response = $ua->request(
		POST $bindUrl
		,Content_Type => 'text/xml; charset=utf-8'
		,Content => "<body rid='".$rid++."'
		     sid='$sid'
		     to='".$to."'
		     type='terminate'
		     xmlns='http://jabber.org/protocol/httpbind'>
		<presence xmlns='jabber:client' type='unavailable'/>
		</body>");
		print "Status: ".$response->status_line."\n";
		print "Content: ".$response->content."\n";
	}
}

sub read {
	my $csv = Text::CSV_XS->new();
	open (CSV, "<", $file) or die $!;

	my $i = 0;
	while (<CSV>) { #each line
		if ($csv->parse($_)) { #parse line
			my @columns = $csv->fields(); #all fields into @columns array
			my $j = 0;
			print "=".$i."=:";
			foreach my $column (@columns) { #each column of the line
				$data[$i][$j] = $column;
				print $j++.": $column  ";
			}
			$i++;
			print "\n";
	    } else {
			my $err = $csv->error_input;
		print "Failed to parse line: $err";
	    }
	}
	close CSV;
}

sub search {
	foreach my $column (@data) {
		if($column->[0] eq $sipid) {
			#process XMPP, user found in data
			if(defined $column->[1]) {
				$user = $column->[1];
				print "XMPP User ".$user." found\n";
			} else {
				exit;
			}
			if(defined $column->[2]) {
				$password = $column->[2];
				print "Password ".$password." found\n";
			}
			if(defined $column->[3]) {
				$rid = $column->[3];
				print "RID ".$rid." found\n";
			}
			if(defined $column->[4]) {
				$sid = $column->[4];
				print "SID ".$sid." found\n";
			}
			if(defined $column->[5]) {
				$pid = $column->[5];
				print "Presence ID ".$pid." found\n";
			}
		}
	}
}

sub write {
	my $csv = Text::CSV_XS->new( {eol => $/} );
	my $fh = new IO::File;
	if ($fh->open("> $file")) {
		foreach my $column (@data) {
			if($column->[0] eq $sipid) {
				print "XMPP User ".$user." found\n";
				$column->[3]=$rid;
				print "RID ".$column->[3]." added\n";
				$column->[4]=$sid;
				print "SID ".$column->[4]." added\n";
				$column->[5]=$pid;
				print "PID ".$column->[5]." added\n";
			}
			$csv->print($fh, $column);
		}
	}
	undef $fh;
}

print "DEBUG: End bosh_connect.pl";

__END__
