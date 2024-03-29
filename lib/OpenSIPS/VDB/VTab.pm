#
# $Id: VTab.pm 5886 2009-07-16 10:54:34Z bogdan_iancu $
#
# Perl module for OpenSIPS
#
# Copyright (C) 2006 Collax GmbH
#                    (Bastian Friedrich <bastian.friedrich@collax.com>)
#
# This file is part of opensips, a free SIP server.
#
# opensips is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version
#
# opensips is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#

=head1 OpenSIPS::VDB::VTab

This package handles virtual tables and is used by the OpenSIPS::VDB class to store
information about valid tables. The package is not inteded for end user access.

=cut

package OpenSIPS::VDB::VTab;

use OpenSIPS;

our @ISA = qw ( OpenSIPS::Utils::Debug );

=head2 new()

 Constructs a new VTab object

=cut

sub new {
	my $class = shift;
	return bless { @_ }, $class;
}

=head2 call(op,[args])

Invokes an operation on the table (insert, update, ...) with the
given arguments.

=cut

sub call {
	my $self = shift;
	my $operation = shift;
	my @args = @_;

	if( my $obj = $self->{obj} ) {
		return $obj->$operation(@args);
	} else {
		no strict;
		return &{$self->{func}}($operation, @args);
	}
}

1;
