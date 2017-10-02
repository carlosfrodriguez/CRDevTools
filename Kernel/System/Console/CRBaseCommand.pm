# Copyright (C) 2016 Carlos Rodriguez, https://github.com/carlosfrodriguez
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --
# DO NOT USE THIS FILE ON PRODUCTION SYSTEMS!
#
# otrs is Copyright (C) 2001-2016 OTRS AG, http://otrs.com/
# --

package Kernel::System::Console::CRBaseCommand;

use strict;
use warnings;

our @ObjectDependencies = ();

=head1 NAME

Kernel::System::Console::BaseCommand - command base class

=head1 DESCRIPTION

Base class for console commands.

=head1 PUBLIC INTERFACE

=head2 OutputTable()

Outputs the item details in a tabular format.

    my $Success = $CommandObject->OutputTable(
    Items =>[
        {
            ID   => 123,
            Name => 'ItemName',
            # ...
        },
        # ...
    ],
    Columns [
        'ID',
        'Name',
        # ...
    ],
    ColumnLength = {
        ID   => 7,
        Name => 20,
        # ...
    };

=cut

sub OutputTable {
    my ( $Self, %Param ) = @_;

    # print header
    my $Header = "\n";
    for my $HeaderName ( @{ $Param{Columns} } ) {
        my $HeaderLength = length $HeaderName;
        my $WhiteSpaces;
        if ( $HeaderLength < $Param{ColumnLength}->{$HeaderName} ) {
            $WhiteSpaces = $Param{ColumnLength}->{$HeaderName} - $HeaderLength;
        }

        $Header .= sprintf '%-*s', $Param{ColumnLength}->{$HeaderName}, "$HeaderName";
    }
    $Header .= "\n";
    $Header .= '=' x 100;
    $Self->Print("$Header\n");

    my $Content;

    # print each item row
    for my $Item ( @{ $Param{Items} } ) {

        my $Row;

        # print item row
        for my $Element ( @{ $Param{Columns} } ) {
            my $ElementLength = length $Item->{$Element};
            my $WhiteSpaces;
            if ( $ElementLength < $Param{ColumnLength}->{$Element} ) {
                $WhiteSpaces = $Param{ColumnLength}->{$Element} - $ElementLength;
            }
            $Row .= sprintf '%-*s', $Param{ColumnLength}->{$Element}, $Item->{$Element};
        }
        $Row .= "\n";
        $Content .= $Row;
    }

    $Self->Print("$Content\n");

    return 1
}

1;
