# --
# Copyright (C) 2017 Carlos Rodriguez, https://github.com/carlosfrodriguez
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --
# DO NOT USE THIS FILE ON PRODUCTION SYSTEMS!
#
# otrs is Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --

package Console::Command::Dev::DynamicField::Search;

use strict;
use warnings;

use parent qw(Console::BaseCommand);

our @ObjectDependencies = (
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

    if (%SearchOptions) {

        %List = $Kernel::OM->Get('Dev::DynamicField')->DynamicFieldSearch(
            %SearchOptions,
        );
    }
    else {
        %List = %{
            $DynamicFieldObject->DynamicFieldList(
                ResultType => 'HASH',
                UserID     => 1,
                )
        };
    }

    my @ItemIDs = sort { $a <=> $b } keys %List;

    # to store all item details
    my @Items;

    ITEM:
    for my $ItemID (@ItemIDs) {

        next ITEM if !$ItemID;

        # get item details
        my $Item = $DynamicFieldObject->DynamicFieldGet(
            ID     => $ItemID,
            UserID => 1,
        );
        next ITEM if !$Item;

        # store item details
        push @Items, $Item,
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

=head1 TERMS AND CONDITIONS

This software is a component of the CRDevTools project (L<https://github.com/carlosfrodriguez/CRDevTools/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut
