#!/usr/bin/perl
# --
# bin/cr.DevTicketDelete.pl - Delete Tikets
# This package is intended to work on Development and Testing Environments
# Copyright (C) 2015 Carlos Rodriguez, https://github.com/carlosfrodriguez
# --
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU AFFERO General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301 USA
# or see http://www.gnu.org/licenses/agpl.txt.
# --
# DO NOT USE THIS FILE ON PRODUCTION SYSTEMS!
#
# otrs is Copyright (C) 2001-2015 OTRS AG, http://otrs.com/

use strict;
use warnings;

# use ../ as lib location
use File::Basename;
use FindBin qw($RealBin);
use lib dirname($RealBin);
use lib dirname($RealBin) . "/Kernel/cpan-lib";

use Getopt::Std;

use Kernel::System::ObjectManager;

# create common objects
local $Kernel::OM = Kernel::System::ObjectManager->new(
    LogObject => {
        LogPrefix => 'OTRS-otrs.DevDeleteTicket.pl',
    },
);

# my %CommonObject = $Kernel::OM->ObjectHash(
#     Objects => [
#         qw(
#             ConfigObject EncodeObject LogObject MainObject DBObject TimeObject TicketObject
#             UserObject
#             )
#     ],
# );

my %CommonObject;
$CommonObject{TicketObject} = $Kernel::OM->Get('Kernel::System::Ticket');
$CommonObject{UserObject}   = $Kernel::OM->Get('Kernel::System::User');

# get options
my %Opts = ();
getopt( 'haixr', \%Opts );

if ( $Opts{h} ) {
    _Help();
}
elsif ( $Opts{a} && $Opts{a} eq 'delete' ) {

    my $ExitCode;

    # check if ticket id is passed
    if ( $Opts{i} ) {

        # check if ID is numeric valid
        if ( $Opts{i} !~ m{\d+} ) {
            print "The Ticket ID $Opts{i} is invalid!\n";
            _Help();
            exit 0;
        }
        else {

            # delete ticket by ID
            _Delete( TicketID => $Opts{i} );
        }
    }
    elsif ( $Opts{r} ) {

        # check if ID is numeric valid
        if ( $Opts{r} !~ m{\A(\d+)\.\.(\d+)\z} ) {
            print "The TicketID $Opts{r} is invalid!\n";
            _Help();
            exit 0;
        }
        my @TicketIDs = ( $1 .. $2 );
        _Delete( TicketID => \@TicketIDs );
    }

    # check if delete all tickets
    elsif ( $Opts{x} ) {
        if ( $Opts{x} eq 1 ) {

            # delete all tickets except form otrs welcome ticket
            $ExitCode = _Delete(
                All           => 1,
                ExceptWelcome => 1,
            );
            if ($ExitCode) {
                exit 1;
            }
            exit 0;
        }
        else {

            # delete all tickets
            $ExitCode = _Delete( All => 1 );
            if ($ExitCode) {
                exit 1;
            }
            exit 0;
        }
    }
    else {
        print "Invalid option!\n";
        _Help();
        exit 0;
    }
}

else {
    _Help();
    exit 1;
}

# Internal

sub _Delete {
    my %Param = @_;

    # check needed parameters
    if ( !$Param{TicketID} && !$Param{All} ) {
        print "Need \"TicketID\" or \"All\" parameter\n";
        _Help();
        exit 1;
    }

    # check if both parameters are passed
    if ( !$Param{TicketID} && !$Param{All} ) {
        print "Can't use both \"TicketID\" and \"All\" parameters at the same time";
        _Help();
        exit 1;
    }

    # to store the tickets to be deleted
    my @TicketIDsToDelete;

    # delete one ticket or range
    if ( $Param{TicketID} ) {

        if ( !ref $Param{TicketID} ) {
            @TicketIDsToDelete = ( $Param{TicketID} );
        }
        else {
            @TicketIDsToDelete = @{ $Param{TicketID} }
        }
    }

    # delete all tickets
    if ( $Param{All} ) {

        # search all tickets
        my @TicketIDs = $CommonObject{TicketObject}->TicketSearch(
            Result  => 'ARRAY',
            UserID  => 1,
            SortBy  => 'Age',
            OrderBy => 'Up',
        );
        @TicketIDsToDelete = @TicketIDs;
    }

    # to store exit value
    my $Failed;

    TICKETID:
    for my $TicketID (@TicketIDsToDelete) {

        next TICKETID if !$TicketID;

        next TICKETID if $TicketID eq 1 && $Param{ExceptWelcome};

        # get ticket details
        my %Ticket = $CommonObject{TicketObject}->TicketGet(
            TicketID => $TicketID,
            UserID   => 1,
        );

        # check if ticket exists
        if ( !%Ticket ) {
            print "The ticket with ID $Param{TicketID} does not exist!\n";
            $Failed = 1;
            next TICKETID;
        }

        # delete ticket
        my $Success = $CommonObject{TicketObject}->TicketDelete(
            TicketID => $TicketID,
            UserID   => 1,
        );

        if ( !$Success ) {
            print "--Can't delete ticket $TicketID\n";
            $Failed = 1;
        }
        else {
            print "Deleted ticket $TicketID\n"
        }
    }
    return $Failed;
}

sub _Help {
    print <<'EOF';
otrs.DevDeleteTicket.pl - Command line interface to delete tickets.

Usage: otrs.DevDeleteTicket.pl
Options:
    -a delete -i 123              # deletes the ticket with ID 123
    -a delete -r 5..10            # deletes the tickets with IDs 5 to 10
    -a delete -x 1                # deletes all tickets in the system except otrs welcome ticket
    -a delete -x 2                # deletes all tickets in the system including otrs welcome ticket

Copyright (C) 2015 Carlos Rodriguez

EOF

    return 1;
}
