# --
# Copyright (C) 2020 Carlos Rodriguez, https://github.com/carlosfrodriguez
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --
# DO NOT USE THIS FILE ON PRODUCTION SYSTEMS!
#
# otrs is Copyright (C) 2001-2020 OTRS AG, http://otrs.com/
# --

package Console::Command::Dev::DynamicField::Search;

use strict;
use warnings;

use parent qw(Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::Config',
    'Dev::DynamicField',
    'Kernel::System::DynamicField',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Search DynamicFields in the system.');

    $Self->AddOption(
        Name        => 'name',
        Description => "Search DynamicFields with specified DynamicField name e.g. *MyDynamicField*.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Listing DynamicFields...</yellow>\n");

    my %SearchOptions;

    my %List;

    # DynamicField name search
    if ( $Self->GetOption('name') ) {
        $SearchOptions{Name} = $Self->GetOption('name');
    }

    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');

    my $Version = $Kernel::OM->Get('Kernel::Config')->Get('Version');
    $Version = substr $Version, 0, 1;

    if (%SearchOptions) {

        %List = $Kernel::OM->Get('Dev::DynamicField')->DynamicFieldSearch(
            %SearchOptions,
        );
    }
    else {
        if ( $Version >= 8 ) {
            %List = %{
                $DynamicFieldObject->FieldList(
                    ResultType => 'HASH',
                    UserID     => 1,
                )
            };
        }
        else {
            %List = %{
                $DynamicFieldObject->DynamicFieldList(
                    ResultType => 'HASH',
                    UserID     => 1,
                )
            };
        }
    }

    my @ItemIDs = sort { $a <=> $b } keys %List;

    # to store all item details
    my @Items;

    ITEM:
    for my $ItemID (@ItemIDs) {

        next ITEM if !$ItemID;

        my $Item;

        # Get item details
        if ( $Version >= 8 ) {

            my $FieldObject = $DynamicFieldObject->FieldGet(
                ID => $ItemID,
            );
            next ITEM if !$FieldObject;

            $Item->{ID}     = $FieldObject->ID();
            $Item->{Name}   = $FieldObject->Name();
            $Item->{Label}  = $FieldObject->Label();
            $Item->{Config} = $FieldObject->Config();
        }
        else {
            $Item = $DynamicFieldObject->DynamicFieldGet(
                ID     => $ItemID,
                UserID => 1,
            );
        }
        next ITEM if !$Item;

        # store item details
        push @Items, $Item,;
    }

    if ( !@Items ) {
        $Self->Print("No DynamicFieldS found\n");

        $Self->Print("<green>Done.</green>\n");
        return $Self->ExitCodeOk();
    }

    $Self->OutputTable(
        Items        => \@Items,
        Columns      => [ 'ID', 'Name', ],
        ColumnLength => {
            ID   => 50,
            Name => 50,
        },
    );

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
}

1;
