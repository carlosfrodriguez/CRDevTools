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

package Console::Command::Dev::ProcessManagement::ActivityDialog::Search;

use strict;
use warnings;

use parent qw(Console::BaseCommand);

our @ObjectDependencies = (
    'Dev::Process',
    'Dev::ProcessManagement::ActivityDialog',
    'Kernel::System::ProcessManagement::DB::ActivityDialog',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Search Process Management Activity Dialogs in the system.');

    $Self->AddOption(
        Name        => 'name',
        Description => "Search activity diaglogs with specified activity dialog name e.g. *MyActivityDialog*.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Listing Process Management Activity Dialogs...</yellow>\n");

    my %SearchOptions;

    my %List;

    # Activity Dialog name search.
    if ( $Self->GetOption('name') ) {
        $SearchOptions{UserLogin} = $Self->GetOption('name');
    }

    my $ActivityDialogObject = $Kernel::OM->Get('Kernel::System::ProcessManagement::DB::ActivityDialog');

    if (%SearchOptions) {

        %List = $Kernel::OM->Get('Dev::ProcessManagement::ActivityDialog')->ActivityDialogSearch(
            %SearchOptions,
        );
    }
    else {
        %List = %{ $ActivityDialogObject->ActivityDialogList( UserID => 1 ) };
    }

    my @ItemIDs = sort { $a cmp $b } keys %List;

    my @Items;

    ITEMID:
    for my $ItemID (@ItemIDs) {
        next ITEMID if !$ItemID;

        my $Item = $ActivityDialogObject->ActivityDialogGet(
            ID     => $ItemID,
            UserID => 1,
        );
        next ITEMID if !$Item;

        push @Items, $Item,;
    }

    if ( !@Items ) {
        $Self->Print("No Activity Dialogs found\n");

        $Self->Print("<green>Done.</green>\n");
        return $Self->ExitCodeOk();
    }

    my $FormattedOutput = $Self->TableOutput(
        TableData => {
            Header => [ 'ID', 'EntityID', 'Name', ],
            Body   => [ map { [ $_->{ID}, $_->{EntityID}, $_->{Name}, ] } @Items ],
        },
        Indention => 2,
    );

    $Self->Print("$FormattedOutput");

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
}

1;
