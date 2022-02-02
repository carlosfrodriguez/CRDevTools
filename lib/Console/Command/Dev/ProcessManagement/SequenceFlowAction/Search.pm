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

package Console::Command::Dev::ProcessManagement::SequenceFlowAction::Search;

use strict;
use warnings;

use parent qw(Console::BaseCommand);

our @ObjectDependencies = (
    'Dev::Process',
    'Dev::ProcessManagement::SequenceFlowAction',
    'Kernel::System::ProcessManagement::DB::SequenceFlowAction',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Search Process Management Sequence Flow Actions in the system.');

    $Self->AddOption(
        Name        => 'name',
        Description => "Search Activities with specified sequence flow action name e.g. *MySequenceFlowAction*.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Listing Sequence Flow Actions...</yellow>\n");

    my %SearchOptions;

    my %List;

    # Sequence Flow Action name search.
    if ( $Self->GetOption('name') ) {
        $SearchOptions{UserLogin} = $Self->GetOption('name');
    }

    my $SequenceFlowActionObject = $Kernel::OM->Get('Kernel::System::ProcessManagement::DB::SequenceFlowAction');

    if (%SearchOptions) {

        %List = $Kernel::OM->Get('Dev::ProcessManagement::SequenceFlowAction')->SequenceFlowActionSearch(
            %SearchOptions,
        );
    }
    else {
        %List = %{ $SequenceFlowActionObject->SequenceFlowActionList( UserID => 1 ) };
    }

    my @ItemIDs = sort { $a cmp $b } keys %List;

    my @Items;

    ITEMID:
    for my $ItemID (@ItemIDs) {
        next ITEMID if !$ItemID;

        my $Item = $SequenceFlowActionObject->SequenceFlowActionGet(
            ID     => $ItemID,
            UserID => 1,
        );
        next ITEMID if !$Item;

        push @Items, $Item,;
    }

    if ( !@Items ) {
        $Self->Print("No sequence flow actions found\n");

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
