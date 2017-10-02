#!/usr/bin/perl
# --
# Copyright (C) 2017 Carlos Rodriguez, https://github.com/carlosfrodriguez
# --
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU AFFERO General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
# or see http://www.gnu.org/licenses/agpl.txt.
# --
# DO NOT USE THIS FILE ON PRODUCTION SYSTEMS!
#
# otrs is Copyright (C) 2001-2017 OTRS AG, http://otrs.com/

use strict;
use warnings;

# use ../ as lib location
use File::Basename;
use FindBin qw($RealBin);
use lib dirname($RealBin);
use lib dirname($RealBin) . "/Kernel/cpan-lib";

use Getopt::Std;

use Kernel::System::ObjectManager;
use Kernel::System::VariableCheck qw(:all);

# create common objects
local $Kernel::OM = Kernel::System::ObjectManager->new(
    LogObject => {
        LogPrefix => 'OTRS-cr.DevGroupDelete.pl',
    },
);

my %Objects = (
    ticket  => 'Ticket',
    article => 'Article',
);

my %Types = (
    text     => 'Text',
    textarea => 'TextArea',
    dropdown => 'Dropdown',
    date     => 'Date',
);

my %DynamicFieldConfigs = (
    Text => {
        DefaultValue => '',
    },
    TextArea => {
        DefaultValue => '',
    },
    Dropdown => {
        DefaultValue   => '',
        Link           => '',
        PossibleNone   => 0,
        PossibleValues => {
            1 => 1,
        },
        TranslatableValues => 0,
        TreeView           => 0,
    },
    Date => {
        DefaultValue  => '',
        Link          => '',
        YearsInFuture => 0,
        YearsInPast   => 0,
        YearsPeriod   => 0,
    },
);

# get options
my %Opts = ();
getopt( 'hatonp', \%Opts );

if ( $Opts{h} ) {
    _Help();
}
elsif ( !$Opts{t} && !$Opts{o} && !$Opts{n} ) {
    _Help();
}
elsif ( !$Objects{ $Opts{o} } ) {
    print "Invalid Object\n";
    _Help();
}
elsif ( !$Types{ $Opts{t} } ) {
    print "Invalid Type\n";
    _Help();
}
else {
    _Add(
        Names  => $Opts{n},
        Type   => $Types{ $Opts{t} },
        Object => $Objects{ $Opts{o} },
    );
}

sub _Add {
    my %Param = @_;

    my @Names = split ',', $Param{Names};

    for my $Name (@Names) {

        my $Config = $DynamicFieldConfigs{ $Param{Type} };

        # TODO FIX
        if ( ( $Opts{p} ) && $Config->{PossibleValues} ) {
            my @PossibleValues = split ',', $Opts{p};
            %{ $Config->{PossibleValues} } = map { $_ => $_ } @PossibleValues;
        }

        my $ID = Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldAdd(
            InternalField => 0,
            Name          => $Name,
            Label         => $Name,
            FieldOrder    => 99999,
            FieldType     => $Param{Type},
            ObjectType    => $Param{Object},
            Config        => $Config,
            Reorder       => 1,
            ValidID       => 1,
            UserID        => 1,
        );

        if ( !$ID ) {
            print "DynamicField $Name was not created\n";
        }
        else {
            print "DynamicField $Name was created with the ID $ID\n";
        }
    }

    return 1;
}

sub _Help {
    print <<'EOF';
cr.DevDynamicFieldAdd.pl - Command line interface to Add Dynamic Fields.

Usage: cr.DevDynamicFieldAdd.pl
Options:
    -t  <type> text                   # text | testarea | dropdown | multiselect | date | datetime

    -o <object> ticket                # ticket | article

    -n <name> myfield                 # myfield1,myfield2

    -p <possible values> myvalue      # myvalue1,myvalue2

Copyright (C) 2015 Carlos Rodriguez

EOF

    return 1;
}
