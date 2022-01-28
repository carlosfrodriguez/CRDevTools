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

package Console::Command::Dev::ChatChannel::Search;

use strict;
use warnings;

use parent qw(Console::BaseCommand);

our @ObjectDependencies = (
    'Dev::ChatChannel',
    'Kernel::System::ChatChannel',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->{ItemName}       = 'Chat Channel';
    $Self->{ItemNamePlural} = 'Chat Channels';

    $Self->Description("Search Chat Channels in the system.");

    $Self->AddOption(
        Name        => 'name',
        Description => "Search $Self->{ItemNamePlural} with specified $Self->{ItemName} name e.g. *MyChatChannel*.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Listing $Self->{ItemNamePlural} ...</yellow>\n");

    my %SearchOptions;

    if ( $Self->GetOption('name') ) {
        $SearchOptions{Name} = $Self->GetOption('name');
    }

    my $ChatChannelObject = $Kernel::OM->Get('Kernel::System::ChatChannel');

    my %List;
    if (%SearchOptions) {

        %List = $Kernel::OM->Get('Dev::ChatChannel')->ChatChannelSearch(
            %SearchOptions,
        );
    }
    else {

        my @AllChatChannels = $ChatChannelObject->ChatChannelsGet(
            Valid          => 0,
            IncludeDefault => 0,
        );

        %List = map { $_->{ChatChannelID} => $_->{Name} } @AllChatChannels;
    }

    my @ItemIDs = sort { $a <=> $b } keys %List;

    my @Items;

    ITEM:
    for my $ItemID (@ItemIDs) {

        next ITEM if !$ItemID;

        my %Item = $ChatChannelObject->ChatChannelGet(
            ChatChannelID => $ItemID,
            UserID        => 1,
        );
        next ITEM if !%Item;

        push @Items, \%Item,;
    }

    if ( !@Items ) {
        $Self->Print("No $Self->{ItemNamePlural} found\n");

        $Self->Print("<green>Done.</green>\n");
        return $Self->ExitCodeOk();
    }

    my $FormattedOutput = $Self->TableOutput(
        TableData => {
            Header => [ 'ID', 'Name', ],
            Body   => [ map { [ $_->{ChatChannelID}, $_->{Name}, ] } @Items ],
        },
        Indention => 2,
    );

    $Self->Print("$FormattedOutput");

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
}

1;
