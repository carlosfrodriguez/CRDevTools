#!/usr/bin/perl
# --
# bin/cr.DevUserDelete.pl - Delete Users Tikets
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
use Kernel::System::CRDevDelete;

# create common objects
local $Kernel::OM = Kernel::System::ObjectManager->new(
    LogObject => {
        LogPrefix => 'OTRS-cr.DevUserDelete.pl',
    },
);
my %CommonObject = $Kernel::OM->ObjectHash(
    Objects => [
        qw(
            ConfigObject EncodeObject LogObject MainObject DBObject TimeObject TicketObject
            UserObject
            )
    ],
);

$CommonObject{CRDevDeleteObject} = Kernel::System::CRDevDelete->new(%CommonObject);

# get options
my %Opts = ();
getopt( 'hairuef', \%Opts );

if ( $Opts{h} ) {
    _Help();
}
elsif ( $Opts{a} && $Opts{a} eq 'list' ) {
    _List();
}
elsif ( $Opts{a} && $Opts{a} eq 'delete' ) {

    my $ExitCode;

    # check if user id is passed
    if ( $Opts{i} ) {

        # check if ID is numeric valid
        if ( $Opts{i} !~ m{\A\d+\z} ) {
            print "The UserID $Opts{i} is invalid!\n";
            _Help();
            exit 0;
        }
        _Delete( UserID => $Opts{i} );
    }
    elsif ( $Opts{r} ) {

        # check if ID is numeric valid
        if ( $Opts{r} !~ m{\A(\d+)\.\.(\d+)\z} ) {
            print "The UserID $Opts{r} is invalid!\n";
            _Help();
            exit 0;
        }
        my @UserIDs = ( $1 .. $2 );
        _Delete( UserID => \@UserIDs );
    }

    else {
        print "Invalid option!\n";
        _Help();
        exit 0;
    }
}
elsif ( $Opts{a} && $Opts{a} eq 'Search' ) {

    my %SearchOptions;

    # user login search
    if ( $Opts{u} ) {
        $SearchOptions{UserLogin} = $Opts{u};
    }

    # email search
    if ( $Opts{e} ) {
        $SearchOptions{Postmaster} = $Opts{e};
    }

    # full text search on login first_name last_name
    if ( $Opts{f} ) {
        $SearchOptions{Search} = $Opts{f};
    }

    _search( SearchOptions => \%SearchOptions );
}
else {
    _Help();
    exit 1;
}

# Internal

sub _List {

    # search all tickets
    my %List = $CommonObject{UserObject}->UserList(
        Type  => 'short',
        Valid => 0,
    );

    _Output( UserIDs => \%List );
    return 1;
}

sub _Search {
    my %Param = @_;

    my %SearchOptions = %{ $Param{SearchOptions} };

    # search all users
    my %List = $CommonObject{UserObject}->UserSearch(
        %SearchOptions,
        Valid => 0,
    );

    _Output( UserIDs => \%List );
    return 1;
}

sub _Output {
    my %Param = @_;

    my @UserIDs = sort { $a <=> $b } keys %{ $Param{UserIDs} };

    # to store all user details
    my @Users;

    USER:
    for my $UserID (@UserIDs) {

        next USER if !$UserID;

        # get user details
        my %User = $CommonObject{UserObject}->GetUserData(
            UserID => $UserID,
        );
        next USER if !%User;

        # store ticket details
        push @Users, \%User,
    }

    my %ColumnLength = (
        ID        => 7,
        Login     => 20,
        Firstname => 24,
        Lastname  => 24,
        Email     => 24,
    );

    # print header
    print "\n";
    for my $HeaderName (qw(ID Login Firstname Lastname Email)) {
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

    # print each user row
    for my $User (@Users) {

        # prepare ticket information
        $User->{ID}        = $User->{UserID}        || '';
        $User->{Login}     = $User->{UserLogin}     || '';
        $User->{Firstname} = $User->{UserFirstname} || '';
        $User->{Lastname}  = $User->{UserLastname}  || '';
        $User->{Email}     = $User->{UserEmail}     || '';

        # print ticket row
        for my $Element (qw(ID Login Firstname Lastname Email)) {
            my $ElementLength = length $User->{$Element};
            my $WhiteSpaces;
            if ( $ElementLength < $ColumnLength{$Element} ) {
                $WhiteSpaces = $ColumnLength{$Element} - $ElementLength;
            }
            print $User->{$Element};
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
    if ( !$Param{UserID} ) {
        print "Need 'UserID' parameter\n";
        _Help();
        exit 1;
    }

    # to store the users to be deleted
    my @UsersToDelete;

    if ( !ref $Param{UserID} ) {
        @UsersToDelete = ( $Param{UserID} );
    }
    else {
        @UsersToDelete = @{ $Param{UserID} }
    }

    # to store exit value
    my $Failed;

    USERID:
    for my $UserID (@UsersToDelete) {

        next USERID if !$UserID;

        # get user details
        my %User = $CommonObject{UserObject}->GetUserData(
            UserID => $UserID,
        );

        # check if ticket exists
        if ( !%User ) {
            print "The user with ID $UserID does not exist!\n";
            $Failed = 1;
            next USERID;
        }

        # delete ticket
        my $Success = $CommonObject{CRDevDeleteObject}->UserDelete(
            UserID => $UserID,
        );

        if ( !$Success ) {
            print "Can't delete user $UserID\n";
            $Failed = 1;
        }
    }
    return $Failed;
}

sub _Help {
    print <<'EOF';
cr.DevUserDelete.pl - Command line interface to delete users.

Usage: cr.DevUserDelete.pl
Options:
    -a list                           # list all users

    -a search -u some user            # search users with specified user login
    -a search -e someone@example.com  # search users with specified email address
    -a search -f *Text*               # full text search on fields login, first_name last_name (wild cards are allowed)

    -a delete -i 123                  # deletes the user with ID 123
    -a delete -r 5..10                # deletes the users with IDs between 5 and 10

Copyright (C) 2014 Carlos Rodriguez

EOF

    return 1;
}
