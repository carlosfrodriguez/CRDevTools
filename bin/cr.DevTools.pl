#!/usr/bin/env perl
# --
# Copyright (C) 2001-2020 OTRS AG, http://otrs.com/
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

use strict;
use warnings;

use File::Basename;
use FindBin qw($RealBin);

use lib dirname($RealBin) . '/lib';

# Also use relative path to find this if invoked inside of the OTRS directory.
use lib ".";
use lib "./Kernel/cpan-lib";

## nofilter(TidyAll::Plugin::OTRS::Perl::BinScripts)

use System;

=head1 NAME

cr.DevTools.pl - CR Module Tools Launcher

=head1 SYNOPSIS

 otrs.ModuleTools.pl command [options] [arguments]

=cut

sub Run {
    my $Help = 0;

    my $Action = 'List';
    if ( $ARGV[0] && $ARGV[0] !~ m{^-} ) {
        $Action = shift @ARGV;
    }
    local $Kernel::OM;
    if ( eval 'require Kernel::System::ObjectManager' ) {    ## no critic

        # create object manager
        $Kernel::OM = Kernel::System::ObjectManager->new();
    }

    eval { require Kernel::Config };
    if ($@) {
        die "This console command needs to be run from a framework root directory!";
    }

    my $CommandObject = $Kernel::OM->Get('System')->ObjectInstanceCreate( "Console::Command::$Action", Silent => 1 );
    if ( !$CommandObject ) {
        my $List = System::ObjectInstanceCreate('Console::Command::List');
        $List->PrintError("Could not load $Action.");
        $List->Execute();

        exit 127;    # COMMAND_NOT_FOUND
    }
    exit $CommandObject->Execute(@ARGV);
}

Run();
