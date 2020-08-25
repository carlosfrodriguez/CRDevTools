#!/usr/bin/env perl
# --
# Copyright (C) 2020 Carlos Rodriguez, https://github.com/carlosfrodriguez
# --
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --
# DO NOT USE THIS FILE ON PRODUCTION SYSTEMS!
#
# otrs is Copyright (C) 2001-2020 OTRS AG, http://otrs.com/

use strict;
use warnings;

use File::Basename;
use FindBin qw($RealBin);
use lib dirname($RealBin);
use lib dirname($RealBin) . '/Kernel/cpan-lib';
use lib dirname($RealBin) . '/Custom';

use Getopt::Std;
use Kernel::System::ObjectManager;

# create common objects
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Kernel::System::Log' => {
        LogPrefix => 'OTRS-otrs.DevProcessManagement.pl',
    },
);

# get options
my %Opts;
getopt( 'hayfn', \%Opts );

if ( $Opts{h} ) {
    _Help();
}
elsif ( $Opts{a} && $Opts{a} eq 'remove' ) {
    if ( $Opts{y} && $Opts{y} == 1 ) {
        _Remove();
    }
    print "Please confirm action with -y 1\n";
    _Help();
}
elsif ( $Opts{a} && $Opts{a} eq 'import' ) {

    if ( !$Opts{f} || !-e $Opts{f} ) {
        print "Not found: $Opts{f} \n";
        exit 1;
    }

    my $ContentSCALARRef = $Kernel::OM->Get('Kernel::System::Main')->FileRead(
        Location => $Opts{f},
        Mode     => 'utf8',
        Type     => 'Local',
        Result   => 'SCALAR',
    );

    if ( !$ContentSCALARRef ) {
        print "File: $Opts{f} \n";
        exit 1;
    }

    _Import(
        Content => $$ContentSCALARRef,
        UserID  => 1,
    );
}
elsif ( $Opts{a} && $Opts{a} eq 'deploy' ) {
    _Deploy();
}
elsif ( $Opts{a} && $Opts{a} eq 'generate' ) {
    if ( !$Opts{n} || $Opts{n} !~ m{\d+} ) {
        print "Please specify the amount of process tickets to create with -n <number>\n";
        _Help();
    }
    _Generate(
        Number => $Opts{n},
    );
}
elsif ( $Opts{a} && $Opts{a} eq 'delete' ) {
    if ( $Opts{y} && $Opts{y} == 1 ) {
        _Delete();
    }
    print "Please confirm action with -y 1\n";
    _Help();
}
else {
    if ( $Opts{a} ) {
        print "Invalid option $Opts{a}\n";
    }
    else {
        print "Missing option \n";
    }
    _Help();
    exit 1;
}

sub _Remove {
    my %Param = @_;

    my $Success = $Kernel::OM->Get('Kernel::System::CR::Dev::Process')->ProcessRemoveAll();

    if ( !$Success ) {
        print "Fail!\n";
        exit 1;
    }
    print "All process where removed successfully.\n";
    exit 0;
}

sub _Import {
    my %Param = @_;

    my %Result = $Kernel::OM->Get('Kernel::System::CR::Dev::Process')->ProcessImportRaw(%Param);

    if ( !%Result || !$Result{Success} ) {
        print "$Result{Message}\n" || "Unknown error\n";
        exit 1;
    }
    print "$Result{Message}\n";
    exit 0;
}

sub _Deploy {
    my %Param = @_;

    my $Result = $Kernel::OM->Get('Kernel::System::CR::Dev::Process')->ProcessDeploy();

    if ( !$Result || !$Result->{Success} ) {
        print "$Result->{Message}\n" || "Unknown error\n";
        exit 1;
    }
    print "All processes deployed correctly\n";
    exit 0;
}

sub _Generate {
    my %Param = @_;

    for my $Item ( 1 .. $Param{Number} ) {
        my $Result = $Kernel::OM->Get('Kernel::System::CR::Dev::Process')->GenerateProcessTicket();
        if ( !$Result ) {
            print "Fail\n";
            exit 1;
        }
        print
            "Created Ticket $Result->{TicketID} for Process $Result->{ProcessEntityID} and Activity $Result->{ActivityEntityID}\n";
    }
    exit 0;
}

sub _Delete {
    my %Param = @_;

    my $Success = $Kernel::OM->Get('Kernel::System::CR::Dev::Process')->ProcessTicketDeleteAll();

    if ( !$Success ) {
        print "Fail!\n";
        exit 1;
    }
    print "All process tickets where deleted successfully.\n";
    exit 0;
}

sub _Help {
    print <<'EOF';
cr.DevProcessManagement.pl - Command line interface for special Process Management tasks.

Usage: cr.DevProcessManagment.pl
Options:
    -a import -f /samples/process.yml     # imports a process without changing the entitiy IDs
    -a deploy                             # deploy all proceses from DB to runtime
    -a remove   -y 1                      # removes all processes from the DB
    -a delete   -y 1                      # deletes all process tickets from the system
    -a generate -n 123                    # generates 'n' process tickets based in current processes

Copyright (C) 2015 Carlos Rodriguez

EOF

    return 1;
}

1;
