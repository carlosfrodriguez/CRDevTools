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

package Console::Command::Dev::ProcessManagement::SequenceFlow::Search;

use strict;
use warnings;

use parent qw(Console::BaseCommand);

our @ObjectDependencies = (
    'Dev::Process',
    'Dev::ProcessManagement::SequenceFlow',
    'Kernel::System::ProcessManagement::DB::SequenceFlow',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Search Process Management Sequence Flows in the system.');

    $Self->AddOption(
        Name        => 'name',
        Description => "Search Activities with specified sequence flow name e.g. *MySequenceFlow*.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Listing Process Management Sequence Flows...</yellow>\n");

    my %SearchOptions;

    my %List;

    # Process name search
    if ( $Self->GetOption('name') ) {
        $SearchOptions{UserLogin} = $Self->GetOption('name');
    }

    my $SequenceFlowObject = $Kernel::OM->Get('Kernel::System::ProcessManagement::DB::SequenceFlow');

    if (%SearchOptions) {

        %List = $Kernel::OM->Get('Dev::ProcessManagement::SequenceFlow')->SequenceFlowSearch(
            %SearchOptions,
        );
    }
    else {
        %List = %{ $SequenceFlowObject->SequenceFlowList( UserID => 1 ) };
    }

    my @ItemIDs = sort { $a cmp $b } keys %List;

    my @Items;

    ITEM:
    for my $ItemID (@ItemIDs) {

        next ITEM if !$ItemID;

        my $Item = $SequenceFlowObject->SequenceFlowGet(
            ID     => $ItemID,
            UserID => 1,
        );
        next ITEM if !$Item;

        push @Items, $Item,;
    }

    if ( !@Items ) {
        $Self->Print("No sequence flows found\n");

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
