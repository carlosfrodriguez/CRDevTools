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

package Console::Command::Dev::ITSMConfigItem::Search;

use strict;
use warnings;

use parent qw(Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::Ticket',
    'Kernel::System::ITSMConfigItem',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Search ITSMConfigItem in the system.');

    $Self->AddOption(
        Name        => 'name',
        Description => "Search ITSMConfigItem with specified ITSM config item name e.g. *MyName*.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'number',
        Description => "Search ITSMConfigItem with specified ITSM config item name e.g. 123.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Listing ITSM config items...</yellow>\n");

    my %SearchOptions;

    # CustomerUser name search
    if ( $Self->GetOption('name') ) {
        $SearchOptions{Name} = $Self->GetOption('name');
    }
    if ( $Self->GetOption('number') ) {
        $SearchOptions{Number} = $Self->GetOption('number');
    }

    no warnings 'once';    ## no critic
    my $ITSMConfigItemObject = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');

    my $ItemIDs;

    $ItemIDs = $ITSMConfigItemObject->ConfigItemSearchExtended(
        %SearchOptions,
        Limit => 10_000,
    );

    my @Items;

    ITEM:
    for my $ItemID ( @{ $ItemIDs || [] } ) {

        next ITEM if !$ItemID;

        my $Item = $ITSMConfigItemObject->ConfigItemGet(
            ConfigItemID => $ItemID,
        );
        next ITEM if ref $Item ne 'HASH';

        my $VersionRef = $ITSMConfigItemObject->VersionGet(
            ConfigItemID => $ItemID,
        ) || {};

        # Prepare ITSMConfigItem information.
        $Item->{Name}   = $VersionRef->{Name}   || $Item->{Name}         || '';
        $Item->{Number} = $VersionRef->{Number} || $Item->{Number}       || '';
        $Item->{ID}     = $VersionRef->{ID}     || $Item->{ConfigItemID} || '';

        # Store item details.
        push @Items, $Item,;
    }

    if ( !@Items ) {
        $Self->Print("No ITSMConfigItems found\n");

        $Self->Print("<green>Done.</green>\n");
        return $Self->ExitCodeOk();
    }

    my $FormattedOutput = $Self->TableOutput(
        TableData => {
            Header => [ 'ID', 'Name', 'Number', ],
            Body   => [ map { [ $_->{ID}, $_->{Name}, $_->{Number} ] } @Items ],
        },
        Indention => 2,
    );

    $Self->Print("$FormattedOutput");

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
}

1;
