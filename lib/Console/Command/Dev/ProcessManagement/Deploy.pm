# --
# Copyright (C) 2017 Carlos Rodriguez, https://github.com/carlosfrodriguez
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --
# DO NOT USE THIS FILE ON PRODUCTION SYSTEMS!
#
# otrs is Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --

package Console::Command::Dev::ProcessManagement::Deploy;

use strict;
use warnings;

use parent qw(Console::BaseCommand);

our @ObjectDependencies = (
    'Dev::Process',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Deploy Processes.');

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Deploying Processes...</yellow>\n");

    no warnings 'once';    ## no critic
    my $Result = $Kernel::OM->Get('Dev::Process')->ProcessDeploy();

    if ( !$Result || !$Result->{Success} ) {
        my $Message = "$Result->{Message}\n" || "Unknown error\n";
        $Self->PrintError("$Message\n");
        return $Self->ExitCodeError();
    }

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
}

1;
