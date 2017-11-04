#!/usr/bin/perl
# --
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
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
