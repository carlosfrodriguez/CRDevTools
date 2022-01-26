# --
# Copyright (C) 2022 Carlos Rodriguez, https://github.com/carlosfrodriguez
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --
# DO NOT USE THIS FILE ON PRODUCTION SYSTEMS!
#
# otrs is Copyright (C) 2001-2022 OTRS AG, http://otrs.com/
# --

package Console::Command::Dev::ProcessManagement::SequenceFlow::Delete;

use strict;
use warnings;

use parent qw(Console::BaseCommand);

our @ObjectDependencies = (
    'Dev::Process',
    'Kernel::System::ProcessManagement::DB::SequenceFlow',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Delete one or more Activities.');
    $Self->AddOption(
        Name        => 'id',
        Description => "Specify one or more SequenceFlow ids of Sequence Flows to be deleted.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/\d+/smx,
        Multiple    => 1,
    );
    $Self->AddOption(
        Name        => 'id-range',
        Description => "Specify a range of SequenceFlow ids to be deleted. (e.g. 1..10)",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/\d+\.\.\d+/smx,
        Multiple    => 0,
    );

    return;
}

sub PreRun {
    my ( $Self, %Param ) = @_;

    my $OptionsCounter = 0;
    for my $Option (qw(id id-range)) {
        if ( $Self->GetOption($Option) ) {
            $OptionsCounter++;
        }
    }

    if ( $OptionsCounter > 1 ) {
        die("Only one option (id or id-range) can be used at a time!\n");
    }

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Deleting Sequence Flows...</yellow>\n");

    my $SequenceFlowObject = $Kernel::OM->Get('Kernel::System::ProcessManagement::DB::SequenceFlow');

    my @ItemsToDelete;
    if ( $Self->GetOption('id') ) {
        @ItemsToDelete = @{ $Self->GetOption('id') };
    }
    elsif ( $Self->GetOption('id-range') ) {
        if ( $Self->GetOption('id-range') =~ m{\A(\d+)\.\.(\d+)\z} ) {
            @ItemsToDelete = ( $1 .. $2 );
        }
    }

    my $Failed;

    ITEMID:
    for my $ItemID (@ItemsToDelete) {

        next ITEMID if !$ItemID;

        # get item details
        my $Item = $SequenceFlowObject->SequenceFlowGet(
            ID     => $ItemID,
            UserID => 1,
        );

        # check if item exists
        if ( !$Item ) {
            $Self->PrintError("The SequenceFlow with ID $ItemID does not exist!\n");
            $Failed = 1;
            next ITEMID;
        }

        # delete Type
        my $Success = $SequenceFlowObject->SequenceFlowDelete(
            ID     => $ItemID,
            UserID => 1,
        );

        if ( !$Success ) {
            $Self->PrintError("Can't delete SequenceFlow $ItemID!\n");
            $Failed = 1;
            next ITEMID;
        }

        $Self->Print("  Deleted SequenceFlow <yellow>$ItemID</yellow>\n");
    }

    my $Result = $Kernel::OM->Get('Dev::Process')->ProcessDeploy();

    if ( !$Result || !$Result->{Success} ) {
        $Self->PrintError("There was an error synchronizing the Processes.");
        if ( $Result->{Message} ) {
            $Self->PrintError("$Result->{Message}\n");
        }
    }

    if ($Failed) {
        $Self->PrintError("Not all Sequence Flows where deleted\n");
        return $Self->ExitCodeError();
    }

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();

}

1;
