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

package Console::Command::Dev::ITSMConfigItem::Definition::Search;

use strict;
use warnings;

use parent qw(Console::BaseCommand);

our @ObjectDependencies = (
    'Dev::ITSMConfigItemDefinition',
    'Kernel::System::GeneralCatalog',
    'Kernel::System::ITSMConfigItem',
    'Kernel::System::Main',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Search ITSM ConfigItem Definitions in the system.');

    $Self->AddOption(
        Name        => 'name',
        Description => "Search ITSM ConfigItem Definitions with specified Signature name e.g. *MySignature*.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Listing ITSM ConfigItem Definitions...</yellow>\n");

    my %SearchOptions;

    my %List;

    $Kernel::OM->Get('Kernel::System::Main')->Require('Kernel::System::ITSMConfigItem::Definition');

    # Signature name search
    if ( $Self->GetOption('name') ) {
        $SearchOptions{Name} = $Self->GetOption('name');

        %List = $Kernel::OM->Get('Dev::ITSMConfigItemDefinition')->DefinitionSearch(
            %SearchOptions,
            Valid => 0,
        );
    }
    else {

        my $ClassList = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemList(
            Class => 'ITSM::ConfigItem::Class',
            Valid => 0,
        );

        for my $ClassID ( sort keys %{$ClassList} ) {

            my $ListPart = $Kernel::OM->Get('Kernel::System::ITSMConfigItem')->DefinitionList(
                ClassID => $ClassID,
                Valid   => 0,
            );

            for my $Item ( @{$ListPart} ) {
                $List{ $Item->{DefinitionID} } = $ClassList->{$ClassID};
            }
        }
    }

    my @ItemIDs = sort { $a <=> $b } keys %List;

    my @Items;

    my $DefinitionObject = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');

    ITEMID:
    for my $ItemID (@ItemIDs) {
        next ITEMID if !$ItemID;

        my $Item = $DefinitionObject->DefinitionGet(
            DefinitionID => $ItemID,
            UserID       => 1,
        );
        next ITEMID if !$Item;

        $Item->{ID} = $Item->{DefinitionID} || '';
        $Item->{Class} //= $List{ $Item->{ID} };

        push @Items, $Item,;
    }

    if ( !@Items ) {
        $Self->Print("No ITSM ConfigItem Definitions found\n");

        $Self->Print("<green>Done.</green>\n");
        return $Self->ExitCodeOk();
    }

    my $FormattedOutput = $Self->TableOutput(
        TableData => {
            Header => [ 'ID', 'Class', ],
            Body   => [ map { [ $_->{ID}, $_->{Class} ] } @Items ],
        },
        Indention => 2,
    );

    $Self->Print("$FormattedOutput");

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
}

1;
