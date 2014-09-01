#!/usr/bin/perl
# --
# bin/cr.DevTicketDelete.pl - Delete Tikets
# This package is intended to work on Development and Testing Environments
# Copyright (C) 2014 Carlos Rodriguez, https://github.com/carlosfrodriguez
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
# otrs is Copyright (C) 2001-2014 OTRS AG, http://otrs.com/

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
getopt( 'haixnoctfr', \%Opts );

if ( $Opts{h} ) {
    _Help();
}
elsif ( $Opts{a} && $Opts{a} eq 'list' ) {
    _List();
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
elsif ( $Opts{a} && $Opts{a} eq 'search' ) {

    my %SearchOptions;

    # ticket number search
    if ( $Opts{n} ) {
        $SearchOptions{TicketNumber} = $Opts{n};
    }

    # owner ID search
    if ( $Opts{o} ) {

        # search by owner needs to have a valid user, do a user lookup and retreive the UserID
        my $UserID = $CommonObject{UserObject}->UserLookup( UserLogin => $Opts{o} );
        if ( !$UserID ) {
            print "The user $Opts{o} does not exist in the database!\n";
            exit 1;
        }

        $SearchOptions{OwnerIDs} = [$UserID];
    }

    # customer search
    if ( $Opts{c} ) {
        $SearchOptions{CustomerUserLogin} = $Opts{c};
    }

    # title search
    if ( $Opts{t} ) {
        $SearchOptions{Title} = $Opts{t};
    }

    # full text search on From To Cc Subject Body
    if ( $Opts{f} ) {
        for my $TicketElement (qw(From To Cc Subject Body)) {
            $SearchOptions{$TicketElement} = $Opts{f};
        }
    }

    _Search( SearchOptions => \%SearchOptions );

}
else {
    _Help();
    exit 1;
}

# Internal

sub _List {

    # search all tickets
    my @TicketIDs = $CommonObject{TicketObject}->TicketSearch(
        Result  => 'ARRAY',
        UserID  => 1,
        SortBy  => 'Age',
        OrderBy => 'Up',
    );

    _Output( TicketIDs => \@TicketIDs );

    return 1;
}

sub _Search {
    my %Param = @_;

    my %SearchOptions = %{ $Param{SearchOptions} };

    # search all tickets
    my @TicketIDs = $CommonObject{TicketObject}->TicketSearch(
        Result        => 'ARRAY',
        UserID        => 1,
        SortBy        => 'Age',
        OrderBy       => 'Up',
        ContentSearch => 'OR',
        FullTextIndex => 1,
        %SearchOptions,
    );

    _Output( TicketIDs => \@TicketIDs );

    return 1;
}

sub _Output {
    my %Param = @_;

    my @TicketIDs = @{ $Param{TicketIDs} };

    # to store all ticket details
    my @Tickets;

    TICKETID:
    for my $TicketID (@TicketIDs) {

        next TICKETID if !$TicketID;

        # get ticket details
        my %Ticket = $CommonObject{TicketObject}->TicketGet(
            TicketID => $TicketID,
            UserID   => 1,
        );
        next TICKETID if !%Ticket;

        # store ticket details
        push @Tickets, \%Ticket,
    }

    my %ColumnLength = (
        ID       => 7,
        Number   => 20,
        Owner    => 24,
        Customer => 24,
        Title    => 24,
    );

    # print header
    print "\n";
    for my $HeaderName (qw(ID Number Owner Customer Title)) {
        my $HeaderLength = length $HeaderName;
        my $WhiteSpaces;
        if ( $HeaderLength < $ColumnLength{$HeaderName} ) {
            $WhiteSpaces = $ColumnLength{$HeaderName} - $HeaderLength;
        }
        print $HeaderName;
        if ($WhiteSpaces) {
            for ( 0 .. $WhiteSpaces ) {
                print " ";
            }
        }
    }
    print "\n";

    for ( 1 .. 100 ) {
        print '=';
    }
    print "\n";

    # print each ticket row
    for my $Ticket (@Tickets) {

        # prepare ticket information
        $Ticket->{ID}       = $Ticket->{TicketID}       || '';
        $Ticket->{Number}   = $Ticket->{TicketNumber}   || '';
        $Ticket->{Owner}    = $Ticket->{Owner}          || '';
        $Ticket->{Customer} = $Ticket->{CustomerUserID} || '';
        $Ticket->{Title}    = $Ticket->{Title}          || '';

        # print ticket row
        for my $Element (qw(ID Number Owner Customer Title)) {
            my $ElementLength = length $Ticket->{$Element};
            my $WhiteSpaces;
            if ( $ElementLength < $ColumnLength{$Element} ) {
                $WhiteSpaces = $ColumnLength{$Element} - $ElementLength;
            }
            print $Ticket->{$Element};
            if ($WhiteSpaces) {
                for ( 0 .. $WhiteSpaces ) {
                    print " ";
                }
            }
        }
        print "\n";
    }
    print "\n";

    return 1;
}

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
    -a list                       # list all tickets

    -a search -n *1234*           # search tickets with specified ticket number (wild cards are allowed)
    -a search -t *welcome*        # search tickets with specified ticket title (wild cards are allowed)
    -a serach -o root@localhost   # search tickets with specified ticket owner login
    -a search -c carlos           # search tickets with specified ticket customer login
    -a search -f *Text*           # full text search on fields To, From Cs Subject and Body (wild cards are allowed)

    -a delete -i 123              # deletes the ticket with ID 123
    -a delete -r 5..10            # deletes the tickets with IDs 5 to 10
    -a delete -x 1                # deletes all tickets in the system except otrs welcome ticket
    -a delete -x 2                # deletes all tickets in the system including otrs welcome ticket

Copyright (C) 2014 Carlos Rodriguez

EOF

    return 1;
}
