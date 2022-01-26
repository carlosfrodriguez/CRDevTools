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

package Console::Command::Dev::ProcessManagement::Delete;

use strict;
use warnings;

use parent qw(Console::BaseCommand);

our @ObjectDependencies = (
    'Dev::Process',
    'Kernel::System::ProcessManagement::DB::Process',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Delete one or more Processes.');
    $Self->AddOption(
        Name        => 'id',
        Description => "Specify one or more Process ids of Processes to be deleted.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/\d+/smx,
        Multiple    => 1,
    );
    $Self->AddOption(
        Name        => 'id-range',
        Description => "Specify a range of Process ids to be deleted. (e.g. 1..10)",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/\d+\.\.\d+/smx,
        Multiple    => 0,
    );
    $Self->AddOption(
        Name        => 'all',
        Description => "Deletes all Processes.",
        Required    => 0,
        HasValue    => 0,
        ValueRegex  => qr/.*/smx,
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

    $Self->Print("<yellow>Deleting Processes...</yellow>\n");

    my $ProcessObject = $Kernel::OM->Get('Kernel::System::ProcessManagement::DB::Process');

    my $DevProcessObject = $Kernel::OM->Get('Dev::Process');

    if ( $Self->GetOption('all') ) {

        $Self->Print("Set to delete all processes!\n");

        my $Success = $DevProcessObject->ProcessRemoveAll();

        if ( !$Success ) {
            $Self->PrintError("Not all Processes where deleted\n");
            return $Self->ExitCodeError();
        }

        $Self->Print("<green>Done.</green>\n");
        return $Self->ExitCodeOk();
    }

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
        my $Item = $ProcessObject->ProcessGet(
            ID     => $ItemID,
            UserID => 1,
        );

        # check if item exists
        if ( !$Item ) {
            $Self->PrintError("The Process with ID $ItemID does not exist!\n");
            $Failed = 1;
            next ITEMID;
        }

        # delete Type
        my $Success = $ProcessObject->ProcessDelete(
            ID     => $ItemID,
            UserID => 1,
        );

        if ( !$Success ) {
            $Self->PrintError("Can't delete Process $ItemID!\n");
            $Failed = 1;
            next ITEMID;
        }

        $Self->Print("  Deleted Process <yellow>$ItemID</yellow>\n");
    }

    my $Result = $DevProcessObject->ProcessDeploy();

    if ( !$Result || !$Result->{Success} ) {
        $Self->PrintError("There was an error synchronizing the Processes.");
        if ( $Result->{Message} ) {
            $Self->PrintError("$Result->{Message}\n");
        }
    }

    if ($Failed) {
        $Self->PrintError("Not all Processes where deleted\n");
        return $Self->ExitCodeError();
    }

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();

}

1;
