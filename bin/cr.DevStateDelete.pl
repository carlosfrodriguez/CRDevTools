#!/usr/bin/perl
# --
# bin/cr.DevStateDelete.pl - Delete Ticket States
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
use Kernel::System::CR::Dev::State;

# create common objects
local $Kernel::OM = Kernel::System::ObjectManager->new(
    LogObject => {
        LogPrefix => 'OTRS-cr.DevStateDelete.pl',
    },
);

# get options
my %Opts = ();
getopt( 'hairnx', \%Opts );

if ( $Opts{h} ) {
    _Help();
}
elsif ( $Opts{a} && $Opts{a} eq 'list' ) {
    _List();
}
elsif ( $Opts{a} && $Opts{a} eq 'delete' ) {

    my $ExitCode;

    my $DeleteTickets = $Opts{x};

    # check if item id is passed
    if ( $Opts{i} ) {

        # check if ID is numeric valid
        if ( $Opts{i} !~ m{\A\d+\z} ) {
            print "The StateID $Opts{i} is invalid!\n";
            _Help();
            exit 0;
        }
        _Delete(
            ItemID        => $Opts{i},
            DeleteTickets => $DeleteTickets,
        );
    }
    elsif ( $Opts{r} ) {

        # check if ID is numeric valid
        if ( $Opts{r} !~ m{\A(\d+)\.\.(\d+)\z} ) {
            print "The StateID $Opts{r} is invalid!\n";
            _Help();
            exit 0;
        }
        my @ItemIDs = ( $1 .. $2 );
        _Delete(
            ItemID        => \@ItemIDs,
            DeleteTickets => $DeleteTickets,
        );
    }

    else {
        print "Invalid option!\n";
        _Help();
        exit 0;
    }
}
elsif ( $Opts{a} && $Opts{a} eq 'search' ) {

    my %SearchOptions;

    # State name search
    if ( $Opts{n} ) {
        $SearchOptions{Name} = $Opts{n};
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
    my %List = $Kernel::OM->Get('Kernel::System::State')->StateList(
        Valid  => 0,
        UserID => 1,
    );

    _Output( Items => \%List );
    return 1;
}

sub _Search {
    my %Param = @_;

    my %SearchOptions = %{ $Param{SearchOptions} };

    # search all users
    my %List = $Kernel::OM->Get('Kernel::System::CR::Dev::State')->StateSearch(
        %SearchOptions,
        Valid => 0,
    );

    _Output( Items => \%List );
    return 1;
}

sub _Output {
    my %Param = @_;

    my @ItemIDs = sort { $a <=> $b } keys %{ $Param{Items} };

    # to store all item details
    my @Items;

    # get state object
    my $StateObject = $Kernel::OM->Get('Kernel::System::State');

    ITEM:
    for my $ItemID (@ItemIDs) {

        next ITEM if !$ItemID;

        # get item details
        my %Item = $StateObject->StateGet(
            ID => $ItemID,
        );
        next ITEM if !%Item;

        # store item details
        push @Items, \%Item,
    }

    my %ColumnLength = (
        ID   => 7,
        Name => 20,
    );

    # print header
    print "\n";
    for my $HeaderName (qw(ID Name)) {
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

    # print each item row
    for my $Item (@Items) {

        # prepare ticket information
        $Item->{ID}   = $Item->{ID}   || '';
        $Item->{Name} = $Item->{Name} || '';

        # print ticket row
        for my $Element (qw(ID Name)) {
            my $ElementLength = length $Item->{$Element};
            my $WhiteSpaces;
            if ( $ElementLength < $ColumnLength{$Element} ) {
                $WhiteSpaces = $ColumnLength{$Element} - $ElementLength;
            }
            print $Item->{$Element};
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
    if ( !$Param{ItemID} ) {
        print "Need 'StateID' parameter\n";
        _Help();
        exit 1;
    }

    # to store the items to be deleted
    my @ItemsToDelete;

    if ( !ref $Param{ItemID} ) {
        @ItemsToDelete = ( $Param{ItemID} );
    }
    else {
        @ItemsToDelete = @{ $Param{ItemID} }
    }

    # to store exit value
    my $Failed;

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # get state object
    my $StateObject = $Kernel::OM->Get('Kernel::System::State');

    ITEMID:
    for my $ItemID (@ItemsToDelete) {

        next ITEMID if !$ItemID;

        # get item details
        my %Item = $StateObject->StateGet(
            ID => $ItemID,
        );

        # check if item exists
        if ( !%Item ) {
            print "The State with ID $ItemID does not exist!\n";
            $Failed = 1;
            next ITEMID;
        }

        my @TicketIDs = $TicketObject->TicketSearch(
            Result   => 'ARRAY',
            Limit    => 100,
            StateIDs => [$ItemID],
            UserID   => 1,
        );

        if ( $TicketIDs[0] ) {
            if ( $Param{DeleteTickets} ) {
                for my $TicketID (@TicketIDs) {

                    # delete ticket
                    my $Success = $TicketObject->TicketDelete(
                        TicketID => $TicketID,
                        UserID   => 1,
                    );

                    if ($Success) {
                        print "Ticket $TicketID deleted as it was used by State $ItemID\n";
                    }
                    else {
                        print "Can't delete ticket $TicketID\n";
                        $Failed = 1;
                    }
                }
            }
            else {
                print "Could not delete State $ItemID due the following tickets use it:\n";
                for my $TicketID (@TicketIDs) {
                    print "Used by Ticket $TicketID\n";
                    $Failed = 1;
                }
                next ITEMID;
            }
        }

        # delete ticket
        my $Success = $Kernel::OM->Get('Kernel::System::CR::Dev::State')->StateDelete(
            StateID => $ItemID,
            UserID  => 1,
        );

        if ( !$Success ) {
            print "--Can't delete State $ItemID\n";
            $Failed = 1;
        }
        else {
            print "Deleted State $ItemID\n";
        }
    }
    return $Failed;
}

sub _Help {
    print <<'EOF';
cr.DevStateDelete.pl - Command line interface to delete ticket States.

Usage: cr.DevStateDelete.pl
Options:
    -a list                           # list all states

    -a search -n *some name*          # search states with specified name (wild cards are allowed)

    -a delete -i 123                  # deletes the state with ID 123
    -a delete -i 123 -x 1             # deletes the state with ID 123, and associated tickets
    -a delete -r 5..10                # deletes the states with IDs between 5 and 10

Copyright (C) 2015 Carlos Rodriguez

EOF

    return 1;
}
